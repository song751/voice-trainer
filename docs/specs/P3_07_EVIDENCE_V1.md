# P3-07 Windows evidence contract v1

`P3_07_EVIDENCE_V1` is the machine-readable, privacy-safe contract for every
P3-07 scenario. It records evidence; it does not decide that Phase 3 is closed.
Each report contains the Git `commit`, ISO `captured_on` date and `build_mode`,
then one or more scenario objects.

Every scenario requires a known `scenario_id`, `evidence_kind`
(`real_device`, `capture_only`, or `synthetic`), a coarse `device_category`,
requested/effective PCM16LE format, processing flags, duration/sample/drop and
discontinuity counters, pipeline/UI-build/UI-raster P50/P95 milliseconds, memory samples,
result and uncovered reasons. Unknown measurements are `null`; their scenario
result must remain `pending` and name why. `pending`, `synthetic`, and
`capture_only` never satisfy a real-device requirement.

Reports must not contain PCM, recording bytes, device IDs, user notes, user
names or absolute paths. Device categories are only `built_in`, `usb`, `none`
and `pending`. The validator rejects known private-data fields and Windows,
Unix or UNC absolute paths.

Commands:

```powershell
dart run tool/p3_07_evidence_runner.dart validate tool/p3_07_fixtures/partial_capture.json
dart run tool/p3_07_evidence_runner.dart create evidence.json e80e028 2026-08-07 release
dart run tool/p3_07_evidence_runner.dart merge evidence.json scenario.json merged.json
```

The runner rejects unknown/duplicate scenarios, missing fields, invalid units,
P95 lower than P50, private-data leaks and a pending result without an uncovered
reason. A nonzero exit always means the supplied evidence is not valid.
