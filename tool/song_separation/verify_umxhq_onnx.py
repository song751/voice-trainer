#!/usr/bin/env python3
"""Development-only PyTorch versus ONNX Runtime UMX-HQ core smoke."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys
import time

import numpy as np

EXPECTED_MODEL_MD5 = "d918985fad0fedf6d9ce89e279aa7218"


class VerificationFailure(Exception):
    def __init__(self, reason: str, operation: str, detail: str) -> None:
        super().__init__(detail)
        self.reason = reason
        self.operation = operation
        self.detail = detail


def emit(kind: str, **fields: object) -> None:
    print(json.dumps({"kind": kind, **fields}, sort_keys=True), flush=True)


def digest(path: Path, algorithm: str = "sha256") -> str:
    value = hashlib.new(algorithm)
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(chunk)
    return value.hexdigest()


def deterministic_magnitude(frames: int) -> np.ndarray:
    indices = np.arange(2 * 2049 * frames, dtype=np.float32)
    values = 0.75 + 0.2 * np.sin(indices * np.float32(0.013))
    return values.reshape(1, 2, 2049, frames).astype("<f4")


def compare(expected: np.ndarray, actual: np.ndarray) -> dict[str, float]:
    if expected.shape != actual.shape:
        raise VerificationFailure(
            "contract_mismatch", "compare_outputs", f"shape {actual.shape} != {expected.shape}"
        )
    if not np.isfinite(actual).all():
        raise VerificationFailure("numerical_mismatch", "compare_outputs", "non-finite output")
    delta = actual.astype(np.float64) - expected.astype(np.float64)
    return {
        "max_abs": float(np.max(np.abs(delta))),
        "rmse": float(np.sqrt(np.mean(np.square(delta)))),
    }


def peak_rss_bytes() -> int | None:
    try:
        import psutil

        return int(psutil.Process().memory_info().rss)
    except (ImportError, OSError):
        return None


def run(arguments: argparse.Namespace) -> None:
    if not arguments.acknowledge_rights:
        raise VerificationFailure(
            "rights_acknowledgement_required",
            "validate_rights",
            "explicit rights acknowledgement is required",
        )
    for role, path in (("model", arguments.model), ("onnx", arguments.onnx)):
        if not path.is_file():
            raise VerificationFailure(f"{role}_not_found", "validate_input", f"{role} file is missing")
    if digest(arguments.model, "md5") != EXPECTED_MODEL_MD5:
        raise VerificationFailure(
            "model_hash_mismatch", "validate_model", "checkpoint is not official UMX-HQ vocals"
        )
    if not arguments.frames or any(frames <= 0 for frames in arguments.frames):
        raise VerificationFailure(
            "contract_mismatch", "validate_frames", "frames must contain positive integers"
        )
    try:
        import onnx
        import onnxruntime as ort
        import openunmix
        import torch
    except ImportError as error:
        raise VerificationFailure("backend_unavailable", "load_backend", str(error)) from error

    onnx_model = onnx.load(str(arguments.onnx), load_external_data=False)
    onnx.checker.check_model(onnx_model)
    operators = sorted({node.op_type for node in onnx_model.graph.node})
    model = openunmix.umxhq(targets=["vocals"], pretrained=False, device="cpu").target_models[
        "vocals"
    ]
    state = torch.load(arguments.model, map_location="cpu", weights_only=True)
    model.load_state_dict(state, strict=False)
    model.eval()

    options = ort.SessionOptions()
    options.intra_op_num_threads = 1
    options.inter_op_num_threads = 1
    options.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL
    session_started = time.perf_counter()
    session = ort.InferenceSession(
        str(arguments.onnx), sess_options=options, providers=["CPUExecutionProvider"]
    )
    session_seconds = time.perf_counter() - session_started
    cases: list[dict[str, object]] = []
    arguments.output_dir.mkdir(parents=True, exist_ok=True)
    for frames in arguments.frames:
        value = deterministic_magnitude(frames)
        with torch.inference_mode():
            expected = model(torch.from_numpy(value.copy())).cpu().numpy()
        started = time.perf_counter()
        actual = session.run(["estimated_magnitude"], {"magnitude": value})[0]
        inference_seconds = time.perf_counter() - started
        errors = compare(expected, actual)
        if errors["max_abs"] > arguments.max_abs_tolerance:
            raise VerificationFailure(
                "numerical_mismatch",
                "compare_outputs",
                f"ORT max_abs {errors['max_abs']:.9g} exceeds tolerance",
            )
        input_path = arguments.output_dir / f"input-{frames}.f32"
        expected_path = arguments.output_dir / f"pytorch-expected-{frames}.f32"
        value.astype("<f4").tofile(input_path)
        expected.astype("<f4").tofile(expected_path)
        cases.append(
            {
                "frames": frames,
                "shape": list(expected.shape),
                "inference_seconds": round(inference_seconds, 6),
                "errors": errors,
                "input_sha256": digest(input_path),
                "expected_sha256": digest(expected_path),
                "actual_sha256": hashlib.sha256(actual.astype("<f4").tobytes()).hexdigest(),
            }
        )
    emit(
        "report",
        status="completed",
        backend=f"onnxruntime_{ort.__version__}_cpu",
        onnx_version=onnx.__version__,
        onnx_sha256=digest(arguments.onnx),
        onnx_byte_length=arguments.onnx.stat().st_size,
        operators=operators,
        session_seconds=round(session_seconds, 6),
        process_rss_bytes=peak_rss_bytes(),
        max_abs_tolerance=arguments.max_abs_tolerance,
        cases=cases,
    )


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--acknowledge-rights", action="store_true")
    parser.add_argument("--model", required=True, type=Path)
    parser.add_argument("--onnx", required=True, type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--max-abs-tolerance", type=float, default=1e-4)
    parser.add_argument("--frames", nargs="+", type=int, default=[32, 47])
    return parser.parse_args()


def main() -> int:
    try:
        run(parse_arguments())
        return 0
    except VerificationFailure as failure:
        emit("failure", reason=failure.reason, operation=failure.operation, detail=failure.detail)
        return 2
    except Exception as error:
        emit("failure", reason="backend_failure", operation="verify_onnx", detail=type(error).__name__)
        return 3


if __name__ == "__main__":
    raise SystemExit(main())
