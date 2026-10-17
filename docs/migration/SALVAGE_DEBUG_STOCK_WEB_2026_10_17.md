# Salvage debug departure stock gate

Status: PASS / CLOSED. Frozen `manifest-b2b281a1.json`, fingerprint
`8b05d6b5cd5cdbde5745d58bb8dc28c0ee61dc1becbb3e43ab0c4270b1e752eb`.

Actual Web evidence: `evidence/salvage-stock-1792182503540/result.json` and its
`ordinary.log`, `debug.log`, `ordinary-shortage.png`, `ordinary-result.png`,
`debug-shortage.png`, `debug-result.png`. Both independent browser contexts passed
eight checks. Runner exited 0; browser closed; dedicated QA 4520 stopped and
verified ECONNREFUSED. Ordinary 4519 remains 200 with this exact manifest.

HTTP byte audit before the final run passed:
`evidence/http-snapshot-manifest-b2b281a1-4519-4520-audit.json`.

## Controlled shortage and real input

The explicit `--qa --qa-salvage-stock` suffix detaches the session's stash data,
empties only the copied items, and intercepts only that instance's Save. It does
not grant stock or change `debugEnabled`. A real 77-part installed loadout then
has eight missing item kinds. Both runs retain 8,000 credits.

| Actual URL argument | Observed debug | Normal Shortfall | DeploymentShortfall | Real input result |
| --- | --- | --- | --- | --- |
| `-vox-debug=0` | false | 8 kinds | 8 kinds | Disabled mouse click and Enter remain in the hall |
| `-vox-debug=1` | true | 8 kinds | 0 kinds | Enabled mouse click loads salvage and enters the transport/drop opening |

`GetArguments()` and the final browser URLs are recorded for both runs. The
debug result has `loadingFlow.phase=closed`; its screenshot shows the transport
opening. This does not claim landed driving or a completed raid.

Actual saved inventory remained identical before and after both routes. Strict
mode made zero stash Save calls; debug BeginRun made one intercepted Save with
unchanged empty copied stock and credits. F18 restored the original stash data
and Save function in each context before closing it.

## Earlier failures retained

- `salvage-stock-1792182197359`: test OOM regex incorrectly matched PreviewRoom.
  Corrected to a whole-word OOM check; this was not a game memory failure.
- `salvage-stock-1792182238214`: a URL with no debug parameter still enabled
  debug because `preview-outgame.html` explicitly adds `-vox-debug=1` on local
  hosts. The final strict run uses explicit `-vox-debug=0`; no production debug
  initialization or QA mutation of debugEnabled was added.
- `salvage-stock-1792182405782`: Lua cjson encodes an empty table as `{}`; the JS
  test wrongly used array.length. Both empty-stock checks now use Object.keys.

No result above is an earned-stock economy, natural raid, performance, mobile,
or Snapdragon 845 acceptance. The final debug run's loading page reported about
50.5 s downloading and 24.0 s preparing textures; passing the stock gate does not
mean those loading times are optimized.
