#!/usr/bin/env python3
"""Development-only UMX-HQ oracle. Never imported by production code."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import sys
import time
import wave

EXPECTED_MODEL_MD5 = "d918985fad0fedf6d9ce89e279aa7218"


class OracleFailure(Exception):
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


def check_cancel(cancel_file: Path | None) -> None:
    if cancel_file is not None and cancel_file.exists():
        raise OracleFailure("cancelled", "run_job", "cancel marker detected")


def read_pcm16_stereo(path: Path):
    import numpy as np

    try:
        with wave.open(str(path), "rb") as reader:
            contract = {
                "channels": reader.getnchannels(),
                "sample_rate_hz": reader.getframerate(),
                "sample_width_bytes": reader.getsampwidth(),
                "frame_count": reader.getnframes(),
                "compression": reader.getcomptype(),
            }
            if contract != {
                "channels": 2,
                "sample_rate_hz": 44_100,
                "sample_width_bytes": 2,
                "frame_count": contract["frame_count"],
                "compression": "NONE",
            }:
                raise OracleFailure(
                    "unsupported_format",
                    "read_input",
                    "UMX-HQ oracle requires uncompressed 44.1 kHz stereo PCM16 WAV",
                )
            raw = reader.readframes(contract["frame_count"])
    except (EOFError, wave.Error) as error:
        raise OracleFailure("unsupported_format", "read_input", str(error)) from error
    audio = np.frombuffer(raw, dtype="<i2").reshape(-1, 2).T.astype("float32") / 32768.0
    return audio, contract


def write_pcm16_stereo(path: Path, audio) -> None:
    import numpy as np

    partial = path.with_suffix(path.suffix + ".partial")
    pcm = (np.clip(audio, -1.0, 1.0).T * 32767.0).round().astype("<i2")
    with wave.open(str(partial), "wb") as writer:
        writer.setnchannels(2)
        writer.setsampwidth(2)
        writer.setframerate(44_100)
        writer.writeframes(pcm.tobytes())
    os.replace(partial, path)


def export_core_onnx(model, output: Path) -> None:
    try:
        import onnx  # noqa: F401 - verifies the development-only exporter dependency
        import torch
    except ImportError as error:
        raise OracleFailure(
            "export_dependency_missing", "export_onnx", "install the development-only onnx package"
        ) from error
    output.parent.mkdir(parents=True, exist_ok=True)
    partial = output.with_suffix(output.suffix + ".partial")
    example = torch.zeros((1, 2, 2049, 32), dtype=torch.float32)
    try:
        torch.onnx.export(
            model,
            example,
            partial,
            dynamo=False,
            opset_version=17,
            input_names=["magnitude"],
            output_names=["estimated_magnitude"],
            dynamic_axes={"magnitude": {3: "frames"}, "estimated_magnitude": {3: "frames"}},
        )
        os.replace(partial, output)
    except Exception as error:
        partial.unlink(missing_ok=True)
        raise OracleFailure("export_failed", "export_onnx", type(error).__name__) from error


def peak_rss_bytes() -> int | None:
    if sys.platform != "win32":
        try:
            import resource

            multiplier = 1 if sys.platform == "darwin" else 1024
            return int(resource.getrusage(resource.RUSAGE_SELF).ru_maxrss * multiplier)
        except (ImportError, OSError):
            return None
    try:
        import ctypes
        from ctypes import wintypes

        class Counters(ctypes.Structure):
            _fields_ = [
                ("cb", wintypes.DWORD),
                ("PageFaultCount", wintypes.DWORD),
                ("PeakWorkingSetSize", ctypes.c_size_t),
                ("WorkingSetSize", ctypes.c_size_t),
                ("QuotaPeakPagedPoolUsage", ctypes.c_size_t),
                ("QuotaPagedPoolUsage", ctypes.c_size_t),
                ("QuotaPeakNonPagedPoolUsage", ctypes.c_size_t),
                ("QuotaNonPagedPoolUsage", ctypes.c_size_t),
                ("PagefileUsage", ctypes.c_size_t),
                ("PeakPagefileUsage", ctypes.c_size_t),
            ]

        counters = Counters()
        counters.cb = ctypes.sizeof(counters)
        get_process = ctypes.windll.kernel32.GetCurrentProcess
        get_process.restype = wintypes.HANDLE
        get_memory = ctypes.windll.psapi.GetProcessMemoryInfo
        get_memory.argtypes = [wintypes.HANDLE, ctypes.c_void_p, wintypes.DWORD]
        get_memory.restype = wintypes.BOOL
        if get_memory(get_process(), ctypes.byref(counters), counters.cb):
            return int(counters.PeakWorkingSetSize)
    except (AttributeError, OSError):
        pass
    return None


def run(arguments: argparse.Namespace) -> None:
    if not arguments.acknowledge_rights:
        raise OracleFailure(
            "rights_acknowledgement_required",
            "validate_rights",
            "explicit rights acknowledgement is required",
        )
    for role, path in (("input", arguments.input), ("model", arguments.model)):
        if not path.is_file():
            raise OracleFailure(f"{role}_not_found", "validate_input", f"{role} file is missing")
    emit("progress", stage="validating", completed_units=0, total_units=5)
    check_cancel(arguments.cancel_file)
    model_md5 = digest(arguments.model, "md5")
    if model_md5 != EXPECTED_MODEL_MD5:
        raise OracleFailure(
            "model_hash_mismatch", "validate_model", "model MD5 does not match official UMX-HQ vocals"
        )
    model_sha256 = digest(arguments.model)
    audio, contract = read_pcm16_stereo(arguments.input)
    emit("progress", stage="loading_backend", completed_units=1, total_units=5)
    check_cancel(arguments.cancel_file)
    try:
        import openunmix
        import torch
    except ImportError as error:
        raise OracleFailure("backend_unavailable", "load_backend", str(error)) from error
    separator = openunmix.umxhq(
        targets=["vocals"], residual=True, niter=0, device="cpu", pretrained=False
    )
    state = torch.load(arguments.model, map_location="cpu", weights_only=True)
    separator.target_models["vocals"].load_state_dict(state, strict=False)
    separator.eval()
    if arguments.export_onnx is not None:
        emit("progress", stage="exporting_core", completed_units=2, total_units=5)
        export_core_onnx(separator.target_models["vocals"], arguments.export_onnx)
    tensor = torch.from_numpy(audio).unsqueeze(0)
    emit("progress", stage="inference", completed_units=2, total_units=5)
    check_cancel(arguments.cancel_file)
    started = time.perf_counter()
    with torch.inference_mode():
        estimates = separator(tensor).cpu().numpy()[0]
    inference_seconds = time.perf_counter() - started
    check_cancel(arguments.cancel_file)
    if estimates.shape[0] != 2 or estimates.shape[1] != 2:
        raise OracleFailure("contract_mismatch", "inference", f"unexpected output shape {estimates.shape}")
    output_frames = min(contract["frame_count"], estimates.shape[2])
    arguments.output_dir.mkdir(parents=True, exist_ok=True)
    vocals_path = arguments.output_dir / "vocals.wav"
    accompaniment_path = arguments.output_dir / "accompaniment.wav"
    emit("progress", stage="writing", completed_units=3, total_units=5)
    write_pcm16_stereo(vocals_path, estimates[0, :, :output_frames])
    write_pcm16_stereo(accompaniment_path, estimates[1, :, :output_frames])
    check_cancel(arguments.cancel_file)
    emit("progress", stage="completed", completed_units=5, total_units=5)
    emit(
        "report",
        status="completed",
        backend="openunmix_1.3.0_torch_cpu_development_oracle",
        model_md5=model_md5,
        model_sha256=model_sha256,
        input_sha256=digest(arguments.input),
        input_frames=contract["frame_count"],
        output_frames=output_frames,
        inference_seconds=round(inference_seconds, 6),
        peak_rss_bytes=peak_rss_bytes(),
        outputs={
            "vocals": {"sha256": digest(vocals_path), "byte_length": vocals_path.stat().st_size},
            "accompaniment": {
                "sha256": digest(accompaniment_path),
                "byte_length": accompaniment_path.stat().st_size,
            },
        },
    )


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--acknowledge-rights", action="store_true")
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--model", required=True, type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--cancel-file", type=Path)
    parser.add_argument("--export-onnx", type=Path)
    return parser.parse_args()


def main() -> int:
    try:
        run(parse_arguments())
        return 0
    except OracleFailure as failure:
        emit("failure", reason=failure.reason, operation=failure.operation, detail=failure.detail)
        return 2
    except Exception as error:  # Keep unexpected backend errors typed and machine-readable.
        emit("failure", reason="backend_failure", operation="run_oracle", detail=type(error).__name__)
        return 3


if __name__ == "__main__":
    raise SystemExit(main())
