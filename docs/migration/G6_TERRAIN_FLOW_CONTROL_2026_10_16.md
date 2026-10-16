# Terrain Flow Control

User request on 2026-10-16: add the engine's fragment-shader flow-control
define to the crater terrain material. The supplied engine feedback identifies
flattened terrain branches as excess GPU work. That attribution is external
feedback, not a new local GPU measurement.

`assets/Crater/material-1.xml` now contains, before its SurfaceShader reference:

```xml
<shader psdefines="FLOW_CONTROL" />
```

`tools/migration/compile-crater.py` emits the same element for `kind=terrain`.
The terrain shader body, texture bindings, mipmaps, addressing and material
parameters are unchanged. No new asset or texture is generated for this fix.

Validation: the actual material parses as XML with this exact shader attribute;
the exporter passes Python AST parsing. Runtime shader compilation, rendered
appearance and GPU performance need the next immutable build. The currently
running `manifest-279727d3` S4 test predates this change and cannot accept it.
The minimap's material-input provenance must also be validated against this
new material rather than rewriting its old capture signature.

## Integrated acceptance candidate

`manifest-8b6203a3.json` includes this material and exporter update, together
with linear filtering and the frozen CPU optimizations. Ordinary preview is
port 4453; actual HTTP payload identity passed. Native minimap recapture
`.tmp/match-map-bake-2026-10-16T08-50-01-885Z` loaded the terrain pixel shader
with `FLOW_CONTROL` in its defines, passed six functional assertions and
published newly rendered pixels signed against all 1147 current inputs.
The exact material comparison confirms that the shader define is its only
semantic change. The capture's complete validation remains FAIL on long frames
(maximum 2094.46 ms), and overlapped other GPU work; it is not an isolated
performance measurement. Web compilation and gameplay use the new candidate's
own evidence, not the previous 2797 run.

The new Web short run is now closed PASS: public S4 entry, actual three-enemy
spawn, 12.123 seconds of observation, normal return and released terrain arrays;
zero runtime errors. The Web runtime log contains successful terrain PS
compilation with `FLOW_CONTROL`. Both entry and spawn-window screenshots were
inspected. Evidence is
`evidence/story-natural-s4-manifest-8b6203a3-2026-10-16T08-52-36-826Z/`.
This narrow check does not establish full-mission or memory stability.
