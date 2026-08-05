# Feature BLOB v1

状态：Phase 0 accepted。所有多字节字段均为 little-endian。

## Layout

| Offset | Size | Type | Value |
|---:|---:|---|---|
| 0 | 4 | ASCII | `VTFS` |
| 4 | 2 | u16 | version = 1 |
| 6 | 2 | u16 | flags = 0 |
| 8 | 4 | u32 | frame count |
| 12 | 4 | u32 | sample period, microseconds |
| 16 | 4 | u32 | Float32 payload bytes; must equal `frameCount * 4` |
| 20 | 4 | u32 | validity bytes; must equal `ceil(frameCount / 8)` |
| 24 | 4 | u32 | header bytes = 32 |
| 28 | 4 | u32 | reserved = 0 |
| 32 | N×4 | Float32 | one column of feature values |
| 32+N×4 | ceil(N/8) | bitset | validity, frame `i` uses bit `i % 8` of byte `i ~/ 8` |

Bit 1 means valid. Invalid values keep their Float32 bits for deterministic round-trip but consumers must ignore them. Extra high bits in the final validity byte are reserved and writers set them to zero.

## Database row

`feature_series` stores `run_id`, semantic `kind`, frame count, codec version, the BLOB, and SHA-256. A feature kind is one column/BLOB; future multi-column formats require a new version or explicit kind contract. BLOB length/header consistency, version and checksum are validated before decode.

24,000 frames at 20 Hz encode as 96,000 Float32 bytes + 3,000 validity bytes + 32 header bytes = 99,032 bytes. Audio bytes are forbidden in this table.

## Migration rules

- Readers must reject unknown versions; they must not guess layouts.
- A new writer format increments the version and keeps an explicit v1 decoder until the database migration has been verified.
- Float comparisons are insufficient for codec tests: round-trip tests compare underlying bytes, including signed zero and NaN payload behavior where applicable.
