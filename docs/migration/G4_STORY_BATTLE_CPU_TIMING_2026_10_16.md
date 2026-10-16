# Story battle CPU timing QA observer

Date: 2026-10-16. Scope: QA probe and natural runner only. No production Lua,
assets, gameplay, package, browser session, or GPU run was changed or started.

## Activation and report

- Detailed timing defaults off. Existing outer app/audio/loading timing is unchanged.
- Only `VOX_STORY_BATTLE_TIMING=1` makes the natural runner deliver an actual
  CDP F15 keydown/keyup after natural mission entry. Other values send no F15.
- The runner waits for actual `performance.battleTiming.enabled == true`.
  Its report records the request, acknowledgement, and screenshot-stage snapshots
  of the probe state and `battle.*` counters. The runtime log also retains normal
  compact state dumps with these counters.
- F15 toggles detailed timing. Enabling begins a new epoch and resets only
  `battle.*` statistics. Disabling restores original instance properties,
  including inherited methods. It preserves any later external replacement.
- Trial, method, unit, vehicle, control and view replacements rebind on the next
  QA update. Removing or disposing the trial restores its detailed wrappers.

## Actual targets

- Trial `Tick`, optional `RenderViews`, `PostUpdate`.
- World and physics Space `Step`.
- Story Mission `BeforeStep`, `AfterStep`, `Update`.
- Boss `BeforeStep`, `StepAllies`, `Projectiles`, `Update`, and BossView `Update`.
- Up to five distinct units: player, boss, three allies, then available initial
  world slots. Each samples `Flush`, vehicle `Step`, and mech control `Step`.
- Player DriveView `Update`; its VehicleView methods when present.
- CombatView `Update` and every actual combat vehicle DriveView `Update`, plus
  VehicleView `Update`, `UpdateIdle`, `UpdateWeaponEffects` when present. Combat
  vehicle labels aggregate those view instances; they are not per-part labels.

The current production Trial has no separate `RenderViews`; its view work is
inside `Tick`. VehicleView has no `Update`; DriveView owns that method. Missing
methods are reported explicitly rather than represented as zero-time calls.
No blueprint parts, visual parts, or 2227-part boss inventory are enumerated.

## Measurement boundary

These are inclusive wall milliseconds around CPU-side Lua calls using the
existing `Time:GetSystemTime` helper, with timer resolution and wrapper overhead.
Nested times must not be summed. Slow nested calls accumulate counters without
printing per-call logs; existing outer slow-call logs retain their behavior.
The wrappers preserve the existing four-return convention, including nil and
false. No changes are made to commands, mission state, health, physics or clocks.

This is diagnostic instrumentation, not an uninstrumented benchmark, GPU timing,
rendered acceptance, mobile evidence or proof of the S5 slow-frame cause. The
previous bb6e natural run predates this observer and cannot validate it. A live
run must serve the new QA probe identity while retaining its frozen production
manifest identity.

## Frozen inputs

- `tools/migration/probe-outgame-web.lua` SHA-256:
  `c3a62969d469ee8df4c785e67384b99b70f36e5c8e4b9c7125afd09a05d43b28`
- `tools/migration/check-story-natural-web.cjs` SHA-256:
  `4f7743ea3da8afb3a5efa36eff7c862b63f961b066a3198902682d82d0892e51`

## CPU regression verification

Actual executions on these inputs:

| Fixture | Checks | Result |
| --- | ---: | --- |
| `check-update-timing.py` | 17 | PASS |
| `check-story-probe-compact.py` | 25 | PASS |
| `check-battle-object-probe.py` | 29 | PASS |
| `check-intro-qa-tools.py` | 71 | PASS |
| `check-story-natural-object-samples.cjs` | 23 | PASS |
| `check-story-road-route.cjs` | 41 | PASS |
| `check-story-navigation.cjs` | 65 | PASS |
| `check-story-route-controls.cjs` | 36 | PASS |
| `check-story-natural-input.cjs` | 40 | PASS |
| `check-battle-update-timing.py`: actual probe header/full HandleUpdate | 72 | PASS |
| `check-battle-update-timing.py`: actual runner import/F15 dispatch | 32 | PASS |

Full probe Lua syntax, Node syntax and scoped `git diff --check` passed. The
dedicated fixture rejects all 12 mutations covering default enablement, first
frame binding, noisy nested logging, lost return slots, repeated wrapping,
external replacement clobbering, unit bound expansion, parts traversal,
non-explicit environment activation, wrong Chrome key code, false acknowledgement
and mutable acknowledgement capture. Hostile parts tables throw if indexed,
counted or enumerated. The fixture executes twelve actual view adapters while
verifying only five units receive sampled unit/control wrappers.

The independent fixture and its report were executed again by the owning agent:

- `tools/migration/check-battle-update-timing.py` SHA-256:
  `31f889aa9cccadfba1a01ff5251b9fc08c02cee3d8c760aa725d17a01528bdcb`
- `docs/migration/evidence/battle-update-timing-offline.json` SHA-256:
  `674c0b2eabb58610df80bcaf37ad0d64a61e1b53ecef8a1371ba3c0ed4a9e908`

These are controlled CPU fixture counters, not measurements from S4 or S5.
