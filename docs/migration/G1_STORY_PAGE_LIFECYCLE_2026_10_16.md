# Story page same-frame departure regression

Source identity remains `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`. This is the continuation of the observed 749 drive-first tutorial route failure, not a reopening of G0. Root owns production StoryPage changes and new-package browser validation; this agent changed only the test and this report. No browser, GPU, native runtime or build was launched.

## Root cause reproduced independently

`GarageHud.Update` calls Rebuild before StoryPage.Key. Esc changes tabs through SetTab, which calls StoryPage.Leave and releases storyHolo/storyVoice/storyBrief. The old story root remains mounted until the next Update rebuild. An actual engine render traversal in that interval reaches `StoryPage.Render`, whose line179 reads `self.owner.storyHolo.ready`, now nil. Checking only Labels' existing nil guard or root direct rendering would miss the full-tree lifetime contract.

Negative control: actual old749 StoryPage SHA256 `fb25e4bbc4d58b71098b035cf1b362a681f790d1981d20a4020f1494aa3e291a`. The test executes its public Create/Key, the extracted actual current GarageHud.SetTab function and the unmodified engine `renderWidgetTree`, while deliberately leaving `s.page` mounted until the next update. It reproduces `scripts/ui/StoryPage.lua:179: attempt to index a nil value (field 'storyHolo')`, after tab becomes battle.

## Current repair acceptance

The root's repair hides/nils `s.storyPage` before releasing its render dependencies, and records the newly created page at Create completion. Independent CPU regression `tools/migration/verify-story-page-lifecycle-offline.py` passed48 checks across Esc, actual back-button callback and external Leave. It verifies:

- Old root stays mounted during the simulated same-frame interval but is invisible.
- Engine traversal skips both the retired root and every descendant.
- Holo, voice and gate are released exactly once across repeated Leave.
- Cancelled and forced stale face-gate completion cannot revive readiness or the old root, including after a new page exists.
- New root/new resources render after return; current gate can still finish, voice button and holo Update remain connected.

The shared environment also reran the existing workshop-shop source oracle/regression,448PASS, and refreshed its evidence. No acceptance thresholds were loosened.

Frozen inspected identities:

- `scripts/ui/StoryPage.lua`: `b6c7bf5dbcf5444d6526952f6bae699cad24385c0a9eb1b09449f5040cb93166`
- `scripts/ui/GarageHud.lua`: `ceee133b1fd5a246a6009f91e4359cf9019c3437eab949af86aa149e21b8afb5`
- Engine renderWidgetTree extracted body: `f888501059ff0ebbb027f41b28c15546e57b281158da0e8d08ba59ca18060a27`
- Test: `f66a4e6db54e52ec36d0e7098646b24f8d7ad6c135073c16d62c88a05517b589`

Evidence: `docs/migration/evidence/story-page-lifecycle-offline.json`. Native widget layout/draw/resource APIs use doubles, while production page logic, SetTab and engine traversal remain actual code. This proves the CPU lifecycle contract and the original failure mechanism, not actual hologram rendering, the entire public drive route, visual parity or performance. Root must run the new unified package through the real failing route before closing its browser acceptance row.
