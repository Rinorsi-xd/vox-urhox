# EffectBatch equivalence review

Date: 2026-10-17. Independent offline review; no Native/browser process started by this reviewer and no production file edited.

## Candidate scope

Compared `.tmp/perf-effects-20261017-a/EffectBatch-before.lua` with `EffectBatch-candidate.lua`. The diff adds two per-batch corner arrays and changes `Quad` to convert four distinct positions and UVs once, then submit the same six corners in order `1,2,3,3,2,4`. `Begin`, `Segment`, `Disc`, `Finish` and `Dispose` are identical. Limit rejection, HDR alpha calculation, normal and tangent creation, shader clock update and material order are unchanged in source. No candidate logic regression was found by this source review.

This conclusion is a source review, not a performance measurement or rendered acceptance.

## Probe coverage and corrections

`perf-effects-native.lua` records every submitted position, normal, color, UV and tangent component, geometry begin/commit calls, batch counts and visibility. Each batch has a separate ordered cumulative digest. The frame trace combines these in a fixed key order. Thus it proves per-batch submission order; it does not prove actual cross-batch `pairs` traversal order across independent Lua processes. The candidate does not modify that traversal.

The state digest covers the eight transient effect lists, chip logical position/velocity/rotation/lifetime/sequence, missile booms/log and light state. Random tail and ground sampling counts are also compared. It is not a serialization of every native object or every field (for example chip model color/scale and material parameters are not included). The actual native-copy test separately returns all thirteen per-vertex values, including packed color.

The original first baseline equivalence run had no native-copy output and used an older probe than its candidate. Its three scenarios nevertheless matched exactly under deep comparison for state/geometry digests, counts, batch totals/peaks, ground calls and RNG tail. That first pair alone cannot certify native buffer copying.

The Effects owner added final direct batch boundary cases for Glow/Streak, limits 0/1, alpha -1/0/0.7/1/2, nil/value parameters, and empty/nonempty/empty visibility. The native test now also asserts tangent y/z and compares all thirteen stored values between baseline and candidate. Final equivalence runs are required with the same final probe.

The comparator was strengthened after this review to require identical Runtime hash and identical non-target Lua hashes (including probe and CombatEffects), fixed seed and exact scenario names/count. It also verifies baseline/candidate source hashes follow ABBA order. Timing comparisons reject method wrappers. These guards must remain enabled; a source or probe mismatch is a failed comparison, not a reason to omit identity checks.

## Acceptance Boundary

Final Native equivalence and ABBA timing evidence are owned by the Effects test line and were still running when this review note was created. This review does not certify full-combat FPS, scene rendering, shader quality, Web behavior, OOM recovery, or Snapdragon 845/TapTap sustained performance.
