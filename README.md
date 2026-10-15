# VoxelCraft / UrhoX

UrhoX Lua migration of the Three.js game. Active source baseline: `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`. Imported content includes 331 catalog parts and 19 public vehicle prefabs. Migration and performance acceptance remain incomplete.

Start with [the engine-team performance handoff](docs/migration/ENGINE_TEAM_HANDOFF_2026_10_15.md) for the exact tested build, reproduction steps, measured failures and bundled evidence.

## Run

Open this directory as an UrhoX / TapTap Maker project and run `scripts/main.lua`. The installed editor supplies the engine SDK, runtime, reference libraries and engine resources. This repository does not bundle those installations or the original H5 repository.

With the matching native runtime installed at `.cli/UrhoXRuntime.exe`:

```powershell
.\preview-hangar.ps1 -Quality desktop
```

Use public menus: hangar -> `出战` -> `歼灭战` -> `开始匹配`. Click the playfield to capture the mouse; W/S and A/D drive, left mouse fires and right mouse aims. Esc first releases the pointer; use the settings or exit button afterward.

PC and landscape mobile layouts, including 20:9, are in scope. Desktop touch emulation does not establish real-phone performance or thermal acceptance.

## Scene Editing

- `assets/Scenes/OrbitalHangar.xml`: hangar.
- `assets/Scenes/Crater.xml`: crater battlefield.
- `assets/Scenes/TrialTrack.xml`: practice track.
- `assets/Scenes/EnginePit.xml`: story engine pit.

Runtime vehicles, UI and sessions are initialized by `scripts/main.lua`; opening a scene alone does not run the complete game.

## Structure

- `scripts/app`: application, loading and session lifetimes.
- `scripts/construction`, `drive`, `combat`, `story`, `endless`, `salvage`: gameplay.
- `scripts/controls`, `render`, `audio`, `ui`: input and presentation.
- `assets`: runtime scenes, models, textures, sounds and data.
- `tools/migration`: import tools and focused checks. Some require the separate H5 source snapshot and workstation dependency paths.
- `docs/migration/CURRENT_EXECUTION.md`: development checkpoint. Historical package results do not validate newer builds.

Loading has resource gates, coroutine checkpoints, shader warm-up and explicit release paths. The battlefield remains resident as a whole; geographic streaming and sustained target-device performance have not been accepted.
