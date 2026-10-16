# Salvage Lobby Loading

Source: frozen H5 branch `2026-10-15`, commit `b276064942ae09c0227ec28d4cfda1d5ff006455`.
`shared/ui/shell.js:281` enters the depot through `_load`; actual deployment
is a separate route at `shell.js:433`.

## Missing Route

GarageHud.SetLobby previously used only HomeVehicleSwitch. The warehouse then
started in the regular home update after the switch, with no preparation page.
Downloads completing did not mean models, material instances or shaders were ready.

## Integrated Route

`app.LobbyLoading` opens the existing persistent LoadingFlow overlay with the
source depot artwork, ice-blue accent, hook, title, subtitle, tips and six rows.
The first work and every subsequent row wait for two presented page frames.
Save loads the separate inventory/vehicle context after dependency downloads;
warehouse construction retains four batches per update and defers activation;
icons use existing offline thumbnails with bounded upload preparation; light
activates the authored warehouse; shaders render existing SceneWarmup batches;
thumbs wait for the existing saved-vehicle preview service. Existing baked light
data and offline icons replace H5 runtime generation rather than rerunning those
Three.js algorithms. Thumbnail readback remains optional on unsupported backends.

After actual preparation, rendered-frame and ready gates reveal the salvage
page. The checklist is not a timer pretending to load. Editing returns and
salvage tabs do not enter this controller; deployment remains its original route.
Cancellation stops this observer, restores warm-up masks, disposes its warehouse
and restores the arena inventory context. Errors remain visible with Back.

## Verification Boundary

`check-lobby-loading.py` executes actual controller/LoadingFlow with controlled
engine, download, warehouse and storage adapters. It checks presented-frame
gates, row sequence, asynchronous thumbnail wait, reentry, cancellation and save
failure. It does not establish Web appearance, real account recovery or frame
times. Actual Web results are recorded separately after packaging.

Shared LoadingFlow default steps, native boot and battle routes retain existing
behavior; only maps explicitly carrying loadingSteps use the custom checklist.
SceneWarmup is initiated once in the shader row, not repeated at Finish.
