# October 15 Development Checkpoint Evidence

Source baseline: `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`.

These are selected original generated reports, not rewritten passing summaries. Functional and performance outcomes are separate. All uncurated historical evidence remains locally ignored or on its historical branch.

- `combat-web-report.json`: actual two-match public-input desktop Web run, 2026-10-15 14:31:21-14:36:29 UTC. Manifest `d7af571f`, 467 Lua files, fingerprint `99ac8e3ba04b01496c10f33175ce2bed8bbe724ea971f331cd2ec74ec2b3a04d`. Runtime errors 0; scope 8/8; lifecycle 4/4. Performance FAIL. Original report label `MEASURED` is not a performance pass.
- `*.cpuprofile`: original profiles for boot, both match loads, both live battles and both returns. Import into Chrome DevTools for attribution.
- `match-live.png`, `repeat1-match-live.png`, `repeat1-returned.png`: inspected first/second battle HUD, crater minimap and returned lobby. Not full visual acceptance.
- `weapons-before-splash-fix.json`: retained failed source comparison before the beam event fix.
- `weapons-after-splash-fix.json`: actual native source comparison, 3729 functional assertions passed. Startup/fixture spikes keep overall performance FAIL.
- `inventory-detail-offline.json`: 331 parts / 5867 source and render-command assertions; not full Web page visual acceptance.
- `match-map-bake-offline.json`: bake input validation; does not establish live performance.
- `shell-native-result.json`, `shell-native.json`, `shell-independent-review.json`: actual native material ownership, full saved-material and render review. 413 functional assertions and 22 released leases; overall frame-spike criterion FAIL.

The report package identity's `targetCommit` is the pre-consolidation parent `ad72080`; the complete per-script hashes identify the tested changes. No production Lua/assets changed between this run and the consolidation commit. Rebuild through UrhoX / TapTap Maker from the current source to obtain a new manifest. Cached workstation build directories and engine installations are deliberately excluded from Git.

## Post-d6fc Source Increment

- `mouse-delta-offline.json`: source event golden versus production Lua, 8757 assertions. Native/OS/Web delivery and visible camera acceptance remain pending. `scope-input-report.json` retains the separate 5030-assertion scope/chase/FOV regression.
- `space-owner-guard-offline.json`: 85132 Lua ownership/update/order checks; no actual Bullet or Web performance measurement.
- `scatter-culling-offline.json`: 11215 stub/transform checks only. Actual native comparison is rejected for production due to changed distance behavior; no final engine validator report was emitted. See `../../SCATTER_CULLING_EXPERIMENT_2026_10_15.md`.
- `inventory-web/report.json` and four `*-bottom.png` screenshots (two pairs): d7af actual PC/20:9 public-input comparison, 22 checks and no runtime errors. The inspected source/target PC and 20:9 pairs expose wrapping and layout-scale differences; visual parity is not accepted. These screenshots do not include the later mouse/Space changes.

Raw unselected evidence remains locally ignored. These additions preserve results without including SDKs, source-golden fixtures, transient packages or user saves.
