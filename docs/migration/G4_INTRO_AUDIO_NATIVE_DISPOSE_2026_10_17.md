# G4 real Native IntroAudio disposal follow-up

Date: 2026-10-17. The root agent executed native-1. This follow-up inspected its saved evidence and prepared native-2; it launched no Runtime, browser, or audio device.

## Observed failure

Evidence remains unchanged at `.tmp/intro-sfx-native-20261017/native-1.*`. The probe completed43 checks successfully before failing check44, `scene Dispose unregisters every retained native SoundSource`, at1178ms. The real audio subsystem had0 sources before construction,17 before disposal, and17 after disposal plus100ms. All13 overlapping SFX progressed; gain envelope, source reuse, stale token rejection, native fadingOut protection, mute and real focus suspension/resume passed. This is source/mixer feedback, not PCM output or whole-opening acceptance.

The production owner retained Lua references to its components after calling only Scene:Dispose. The real run demonstrates that scene disposal alone did not unregister those sources while those handles remained retained. It does not establish an engine-wide leak, allocation owner for the unrelated Web OOM, or a frame-time benefit.

The old offline Scene adapter automatically marked every component disposed. That assumption masked the missing explicit source lifecycle. It now requires components to be explicitly stopped, detached and disposed first; removing production release calls is a negative control that fails.

## Minimal production change

`scripts/audio/IntroAudio.lua:Dispose()` now performs StopImmediate, Component:Remove, then Component:Dispose for every retained voice, SFX and music slot before disposing its dedicated Scene. All three APIs are declared in the actual component/audio bindings. No playback parameters, envelope timing, source concurrency, bus behavior, or other audio owner changed. Idempotence continues to use the existing active guard. Explicit real-engine disposal remains pending native-2.

Current IntroAudio SHA-256: `2d3083b8001db764a9d9ce2953512accbc4845af899c1f528b325b70c859556b`.

## Independent fixture resource failure

native-1 stderr also contained exactly5 errors: missing Techniques/NoTexture.xml, Techniques/DiffUnlit.xml, Strings/Bootstrap.json, Textures/spinner.png and Fonts/Anonymous Pro.ttf. All are bootstrap/renderer defaults; their files exist in the same copied Runtime's CoreData/Data directories, which the previous default resource path did not include. They are not SoundSource API errors. The launcher now supplies `-p ResCache;Res;CoreData;Data` alongside the same resource prefix. CLI acceptance and absence of resource errors must be checked in native-2; no error is silently ignored.

## Ready for root-owned hardware slot

New isolated frozen fixture: `.tmp/intro-sfx-native-20261017-dispose2/`. Existing native-1 and package935 remain unchanged. Identity includes real production modules, real audio resources and the unchanged probe SHA-256 `be8f2975eed0351ef300c15e1856ea144765d194aec4f86710143cd45f7db89f`.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/migration/run-intro-sfx-native.ps1 -Fixture .tmp/intro-sfx-native-20261017-dispose2 -Label native-2
```

Same beta40 Runtime SHA-256 `f6a2ae8893bebb66b0dce1f6687a6ba0cd98454a20069541b5557cbf5f79772c`. Internal25-second and external30-second deadlines remain. The launcher closes only its own process and rejects any native ERROR. Only the root agent may launch while it owns hardware.

## Offline checks

All six real-source Lua54 suites pass: SFX concurrency651, envelope1603, transitions569, tail545, television lowpass221, voice clock539, total4128 checks. Missing source reservation and missing explicit disposal negative controls are rejected. Node preparer syntax and PowerShell launcher parsing pass. Updated evidence contains current production hashes. These are controlled API adapters and source comparisons; they do not replace native-2 or establish performance improvement.

## Native-2 observed; native-3 resource preparation

Root executed native-2 and its process is CLOSED. The real audio probe passed all46 checks, including registered sources17 before production Dispose and0 after it. This verifies the narrow production source-lifecycle fix on Native. The launcher's acceptance still failed because the same5 bootstrap resources were missing. Its saved log proves this Runtime entry retained ResourcePaths=ResCache;Res despite the supplied -p argument. The earlier -p proposal therefore did not resolve resource lookup; those errors remain recorded and are not waived.

The native-3 preparer exposes the existing same-version Data and CoreData through separate fixture-owned Res junctions and uses the already demonstrated -pp option with a semicolon prefix list. The semicolon prefix-list format is explicitly shown by the same Runtime package's `project-tools/projects/test-aggregation/assets/Groups/SurfaceInstance/README.md`. Search order is Runtime resources, then Data, then CoreData; engine files and earlier evidence are unchanged. Prefixes and resolved junction targets are recorded in identity.json and checked before launch. Offline resolution using the actual default ResCache;Res names finds all5 resources; Node and PowerShell syntax checks pass. No Runtime was started by this follow-up.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/migration/run-intro-sfx-native.ps1 -Fixture .tmp/intro-sfx-native-20261017-res3 -Label native-3
```

Native-3 is READY_NOT_RUN until root executes it. It uses the same unchanged production/probe hashes as native-2. Root must verify logged resource roots and zero native ERROR before accepting the fixture. This does not change the earlier performance and audible-output evidence boundaries.

## Native-3 failure and executable-adjacent native-4 preparation

Root executed native-3; its Lua source tests passed and its process is CLOSED, but the same5 resource errors remained. Its stdout registered only the original executable's ResCache and Res; neither supplied fixture prefix appeared. The saved arguments show the semicolon -pp value was passed. This proves the additional roots were not adopted; it does not distinguish argument parsing from application override or sandbox initialization. Earlier statements treating -pp as demonstrated effective were too strong because its first value already equaled the executable's own directory. No further CLI flag assumption is used.

The complete next fixture is `.tmp/intro-sfx-native-20261017-visible4b`. Its own `runtime/UrhoXRuntime.exe`, DLLs and build metadata are exact hash-checked copies from the prior isolated Runtime. Its adjacent `runtime/Res` is a junction to the unchanged same-version original Res. The5 missing original CoreData/Data resources are copied verbatim into its adjacent `runtime/ResCache` using their exact resource names. The launcher supplies neither -p nor -pp. Thus the files sit directly inside the default roots actually observed in all3 logs. Runtime files,5 resource hashes and junction target are frozen in the new identity and verified before launch. PS parsing, Node syntax and all12 copied-file hashes pass without launching hardware. The original Runtime and native1-3 evidence remain unchanged.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/migration/run-intro-sfx-native.ps1 -Fixture .tmp/intro-sfx-native-20261017-visible4b -Label native-4
```

The incomplete `visible4` directory came from an offline preparation failure caused by a UTF-8 BOM in the old copy identity; it was preserved and never launched. The BOM reader is corrected. Only `visible4b` is a complete prepared fixture. Native-4 remains READY_NOT_RUN until root executes it. Zero native ERROR is still required and is not waived.

## Native-4 observed and native-5 font dependency preparation

Root executed native-4; the process is CLOSED, all46 real source checks passed and disposal again returned registered sources17 to0. The5 original resource errors disappeared. One additional transitive resource request became visible: `Fonts/Default.xml`.

The new complete fixture `.tmp/intro-sfx-native-20261017-font5` preserves the same executable-adjacent setup and adds exact installed `Fonts/Default.xml`, `Fonts/Anonymous Pro.xml` and `Fonts/Twemoji.Mozilla.ttf` to its own ResCache. Both XML files were parsed using PowerShell's XML parser; each contains only a fallback named `Fonts/Twemoji.Mozilla.ttf`. That resource is present locally at the corresponding path,1474284bytes. No material, font or gameplay content was invented or replaced. The identity freezes all15 executable/bootstrap-file hashes, which pass offline verification. Production/probe hashes remain unchanged; no production file was modified for this preparation.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/migration/run-intro-sfx-native.ps1 -Fixture .tmp/intro-sfx-native-20261017-font5 -Label native-5
```

Native-5 is READY_NOT_RUN; root owns the next hardware slot. All4 prior runs remain unmodified. Actual zero-error acceptance is still pending the next real run.

## Final observed state: Native-5 accepted

Root executed native-5; independent read-only verification of its saved evidence passes. Result PASS,46/46 checks,1174ms probe time, zero native ERROR in stdout/stderr; stderr is empty. The real Runtime Lua log also contains the final INTRO_SFX_NATIVE_RESULT PASS. Registered sources were0 at baseline,17 before production Dispose and0 after it. All13 simultaneous native SFX sources advanced their playback positions. The native fadingOut flag was observed and the occupied source was protected. The real gain envelope, stopped-slot reuse, stale callback rejection, mute, focus pause/resume and rejection of playback after disposal passed.

The recorded process status is CLOSED and PID67144 no longer exists. Root observed exit0 at execution; the archived process.json itself contains null exitCode, so the independent audit does not claim to recover an OS exit code from that file. All5 original run archives remain unchanged, including unsuccessful fixture runs. Earlier READY_NOT_RUN paragraphs describe the preparation state at that point in the sequence; this final section is the accepted current state.

| Run | Lua checks | Native ERROR | Source count after Dispose | Acceptance |
| --- | --- | --- | --- | --- |
| native-1 |43/44 |5 |17 |FAIL |
| native-2 |46/46 |5 |0 |FAIL bootstrap resources |
| native-3 |46/46 |5 |0 |FAIL bootstrap resources |
| native-4 |46/46 |1 |0 |FAIL default font config |
| native-5 |46/46 |0 |0 |PASS narrow Native audio fixture |

Independent verification tool: `node tools/migration/verify-intro-sfx-native-result.cjs`. Output: `docs/migration/evidence/intro-sfx-native-final-verification.json`. It verifies all frozen and current production module/resource hashes, probe, copied Runtime/bootstrap hashes, the original Res junction target, actual source observations, all46 checks, absence of native ERROR, final Runtime Lua record and PID absence. It launches no hardware and does not modify original run evidence.

The same tool verified all547 current scripts against the frozen current package `.tmp/outgame-cached-1792189057538`, manifest-f881ebb0.json, fingerprint `edd3f28a061ee32b61743001e4a9561621032cbf6c9e70fed0a770eaee2b20f7`. Its IntroAudio bytes exactly match production and the successful Native fixture (SHA-256 `2d3083b8001db764a9d9ce2953512accbc4845af899c1f528b325b70c859556b`). This verifies package source identity; it does not itself test the ordinary4546 browser surface.

Final acceptance remains deliberately narrow: actual Native source/mixer progression and lifecycle passed. No mixed PCM recording/listening, compressor equivalence, complete rendered opening, Web frame-time benefit, Web OOM allocation attribution or Snapdragon845 sustained performance is established by this fixture. Preserving authored SFX overlap can add mixer work; this correctness change is not reported as a FPS improvement.
