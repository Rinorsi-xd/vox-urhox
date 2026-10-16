# G1 track wheel rotation freeze

Production scope: `scripts/render/PartRig.lua`, one sign correction in `SetTrack` plus an explanatory comment.

Frozen SHA-256: `44c9e2f7bca4a5cac91357288fe517bbb444145c1b87f48812d13523ed3506f3`.

The frozen H5 source commit is `b276064942ae09c0227ec28d4cfda1d5ff006455`.
Its `CarVisual._tracks` computes wheel/ring rotation as `s/r`, and belt offset as `-s`.
The Lua caller already passes belt offset into `SetTrack`. The X coordinate reflection requires source Y rotations to reverse, so the native wheel angle must be `distance/r`, not `-distance/r`.

## Focused source comparison

Run: bundled Python `tools/migration/verify-track-spin.py`.
Evidence: `docs/migration/evidence/track-spin-offline.json`.

The verifier executes the actual frozen source `_tracks`, `setTrackOffset`, and path evaluator with Three.js matrices/quaternions. It executes the actual Lua `PartRig.Build`, `SetTrack`, and `SetWheel` with limited native-value adapters. For retained tracks it executes the actual `DriveView:Bind` function and its actual track update statement; unrelated actuator/effect setup is stubbed.

The 56 cases cover the four authored track rigs, both mounting signs, neutral/forward/reverse/wrapped travel, multiple wheel/ring radii, and 16 surviving-rig rebinds. It compares all pad and wheel/ring matrices after the X reflection, including 672 off-axis spoke endpoint transforms.

| Comparison | Previous 5554 | Fixed |
| --- | ---: | ---: |
| Wheel/ring matrices checked | 336 | 336 |
| Mismatching wheel/ring matrices | 288 | 0 |
| Pad matrices checked | 2982 | 2982 |
| Mismatching pad matrices | 0 | 0 |
| Actual Bind rebinds | 16 | 16 |

Maximum fixed wheel matrix error: `1.34e-15`; maximum pad matrix error: `8.00e-15`.
All pad outputs are exactly equal between previous and fixed Lua. `SetWheel` and subsequent functions are text-identical, with three ordinary-wheel pose outputs also exactly equal.

## Boundary

This is an offline transform parity result. It does not certify native rendering, visible wheel motion, browser performance, or user visual acceptance. Parent owns the unified package and runtime acceptance. No physics coefficients, collision shapes, vehicle inputs, assets, or other production files were changed for this correction. No build, upload, commit, browser, or native GPU session was started by this task.
