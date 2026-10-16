# Opening schedule and cue recovery

Frozen source: branch `2026-10-15`, commit `b276064942ae09c0227ec28d4cfda1d5ff006455`, snapshot `.tmp/outgame-source-2026-10-15T12-35-57-243Z`.

Production file: `scripts/intro/IntroSession.lua`, SHA-256 `cef992d723e4f3b9b5ad8ea1550993c4422b431f6fa4fd7abc3bfaeb4721bfd2`.

## Recovered behavior

- Decision waits for both hold completion and `vo_n06 + .1`, rather than cutting a held narration after roughly 2.5 seconds. Current 5.04-second recording produces 5.142 seconds before the next shot; unattended progression is approximately 7.867 seconds.
- Missile camera/firing task lasts 5.2 seconds concurrently with narration. Longer narration may continue after firing stops. `OpeningHost` consumes `missileFiring` in the parent integration.
- Both galaxy and payslip wipes expose the next shot at 349.6 ms, matching the real source wipe's `760 * .46` covered promise. `wipeAt` uses monotonic session time; the UI owns the complete 760 ms drawing.
- Galaxy counter blips, payslip stamp/lock blips/laser/shred, familiar panel whooshes, NO cue volumes and music stop point, reachable `playSortie` alarm/music/tv-cut/brief-confirm/countdown cues are restored.
- Sortie alarm stops with .6-second fade at decision, or .2-second fade on earlier advertisement exit. Comms alarm fades over 1.5 seconds at contract. Handles retain audio playback tokens so an old reference cannot stop a reused sound slot.
- Contract entrance whoosh and delayed stamp impact, gate scan confirm and zero-based source pitch progression, and n16/n17 narration tails match source scheduling.

## Verification

Run with bundled Python:

```powershell
& 'C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' tools/migration/verify-intro-timing.py
& 'C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' tools/migration/check-opening-prefetch.py
```

Results: 3,953 timing/cue checks PASS; 58 prefetch checks PASS. Evidence is in `docs/migration/evidence/intro-timing-offline.json` and `opening-prefetch-offline.json`.

`source-intro-timing.mjs` validates frozen hashes and executes actual Intro familiar/galaxy/payslip/decide/montage/recruit/NO acts, IntroStory contract/gate acts, the real wipe helper, and reachable playSortie through countdown. DOM, audio, input and physics are adapters. Awaited animation completion and setTimeout use a 240 Hz virtual clock. The Lua fixture executes actual `IntroSession.Ad`, `Run`, and `Update`, including held/unattended input, short/long voices, skip, contract and gate branches.

`intro-timing-offline-before.json` records an intermediate failing state after the first wait fixes; it is not the pristine pre-edit baseline. No listening, GPU rendering, live physics, natural full playback, mobile behavior or user visual acceptance is established by this fixture.

## Confirmed Remaining Runtime Differences

These are parent-owned runtime concerns, outside this production freeze:

- Source `playSortie` runs the battlefield during its 2.2-second establishing shot and briefing. Target `IntroBattle.BeforeStep` only steps enemy drivers when `stage > 0`, while `StartSortie` sets stage 1 after the countdown, so the brief has stationary enemy AI.
- Source places and retargets the easy enemy to `[66, ground + 1.5, -130]` only at player handoff after countdown. Target `IntroBattle.New` places it there immediately and assigns multiplier 8, before briefing begins.
- Source `endPlay` restores all enemy multipliers to 1, clears their player targets, respawns destroyed enemies, and swaps the player back to the source hero blueprint at `[150, ground + 1.5, -214]`. Target `EndSortie` currently pauses the existing session; easy multiplier 8, default red multiplier 2, current actors and the player vehicle remain. This can affect later live montage shots and requires explicit runtime parity work.

