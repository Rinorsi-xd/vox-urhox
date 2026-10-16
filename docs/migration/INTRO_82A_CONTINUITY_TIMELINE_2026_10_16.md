# 82a opening continuity timeline

Date: 2026-10-16. Read-only production investigation of immutable `.tmp/outgame-cached-1792102529909`, `manifest-82a41dd6.json`, fingerprint `ef3e9d7be054d3734a7e0401515e7fa440af1f67dd3811a1e59c06f7da7719fa`. Later IntroSession/Page/HangarApp edits are not validated by this run.

Evidence prefix: `evidence/intro-natural-web-1600x900-manifest-82a41dd6-early-retirement`; use its `.json`, `.log`, `-audio-timeline.json`, and generated `-analysis.json`. Re-ran `analyze-intro-continuity.cjs` against these existing files; no GPU test or production change. Times below are UTC+08 on 2026-10-16, obtained from recorded browser timeOrigin/timezone.

## Actual result

65 functional checks PASS, zero observed game errors, shutdown CLOSED, continuity FAIL. Actual player movement, shooting and destruction, full later sequence, landscape resizes, signature, original 700ms fade, audio tail and tutorial handoff were reached. Audio callback maximum 733.640ms with 10 candidates; RAF maximum 683.835ms with three intervals above 250ms. The audio processor's measured maximum mixer execution was 1.910ms. Callback starvation and audible waveform damage are distinct claims; this report does not replace listening or waveform review.

| Boundary | Observed time / cost | Supported implication |
| --- | --- | --- |
| Opening media group, 70 resources | 06:18:14.488 complete | Historical 82a starts map prefetch only after this group |
| Map/actor group, 525 resources | 06:18:46.428 complete | Separate from native scene construction and warmup |
| First warmup / restored | 06:19:04.068 / 06:19:33.224 | Seven phases, 413 frames, 392 batches retained |
| Logo to idyll audio interval | 06:19:37.003-37.345, 341.065ms | Overlaps 263ms task; Glass VS/FS completion logs at 37.124/37.248 correlate, not a CPU attribution |
| Contract to stamp interval | 06:22:22.396-22.806, 409.150ms | Overlaps 339ms task; new openingContract maximum 326ms, inclusive Page maximum 328ms |
| Exclusive crater retirement | Complete 06:21:36.800, 37 slices / 202ms total / 25ms maximum | Finished well before exit; retained model/array/resource totals still require real release verification |
| Begin exit fade | 06:22:38.363-38.364, host 0ms / request 1ms | Hall restoration starts under the original fade |
| CompleteFinish | 06:22:39.063-39.139, 76ms inclusive | hostDispose 66ms, Dispose 68ms, restoreHud 8ms overlap; do not sum them |
| Tutorial group, 25 resources | 06:22:39.592 complete | Completion precedes longest remaining task |
| Longest audio interval | 06:22:39.629-40.363, 733.640ms | Begins about 490ms after CompleteFinish returns |
| Longest overlapping task | 06:22:39.664-40.345, 681ms | Begins about 525ms after CompleteFinish returns; no shader completion in the interval |
| One-resource group completion | 06:22:40.342 | Correlates with end of longest task; resource identity/stack not established by group summary |
| Audio-tail disposal | 06:22:40.347, 0ms measured | Does not account for the earlier 681ms task |
| Hall music ready | 06:22:40.633, circuit track 4,014,959 bytes | Ready log follows the longest task; cannot prove a synchronous decoder duration |

## Next attribution boundary

The longest task must not be assigned to the synchronous CompleteFinish call: that measured call already returned. The smallest useful attribution target is the tutorial group completion to the first actual tutorial UI/native-resource creation and the one-resource completion callback. Existing F8 opening method counters end with the opening instance, so the worst gate interval has no enclosing method timing window. A bounded timer around those exact handoff operations in the unified-run owner can resolve the remaining cost; these logs do not establish GC, image decode or music decode as the unique cause.

The contract maximum is a separate, directly observed method hotspot. The nearest F8 delta spans 48 calls and multiple frames; 326ms is a recorded single-call maximum but its internal sub-operation remains unresolved here. Parent/child wrapper costs overlap and include instrumentation overhead. This run had an OOM abort hook and F8 method wrappers, but no FS scan or CDP CPU profile; it is not an uninstrumented baseline and is not directly comparable with the earlier sampled 9b run as a speedup measurement.
