# Scoped repair glyph checkpoint

Source: `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`.

Actual Windows Chrome CDP resolved the source U+271A repair span to Segoe UI Symbol. The isolated original EndlessHud/EndlessLoot screenshot and CDP evidence is `evidence/source-endless-repair-font-2026-10-15T17-36-47.021Z/report.json`; this is not natural gameplay acceptance.

EndlessWidgets now uses only `vox-repair-symbol` for this glyph, retaining44px/x+20/y+12. SourceFonts selects installed Windows `seguisym.ttf` when available, never copying Microsoft font bytes. Other platforms or a missing local font use `Fonts/VoxRepairSymbols-Regular.ttf`:5284bytes, exactly U+271A plus.notdef, licensed Noto Sans Symbols2, renamed family. Original Noto outline and metrics are retained. Its OFL and provenance files record upstream GoogleFonts commit `8b0a1d0f5983c89bc2b93f1b5fb55f9e252744b5`, URLs and hashes. `tools/migration/import-repair-symbol.py` reproduces the resource conversion; no whole font is retained in assets.

SourceDraw loads the scoped font once per context, directly selects it and adds no fallback. Number mapping remains Barlow. `tools/migration/verify-repair-symbol.py`97checks PASS covers actual Widgets/SourceDraw/SourceFonts calls across six platform/presence cases, exact coordinates/size, laziness, cmap/contours and the actual old HEAD Widget using glyph-missing vox-title. `evidence/repair-symbol-offline.json` contains three production Lua and three resource SHA256. Diff whitespace check PASS.

Frozen production: EndlessWidgets `48ef26035b79fd120d590218045779d1cfc25261d0ee845906430e5669059034`; SourceFonts `9a724bfe9357f75bfe395d4a5de840ade32d7bdceec89a89ea2db0e20207d331`; SourceDraw `c74ea69e5e2e6784600edeac4b8da777e7c718ac3234fd8882940be73af52a59`; subset `b1642e28784a4ad313e8d850c0574007c74b1ce7ab247a500bb0836ae9447bae`.

No GPU/native/build/browser was started for target verification by this agent. Web/mobile Noto is an explicit substitute, not a claim of pixel1:1 with Windows H5. Rendered target and mobile acceptance remain OPEN for the parent's unified build.
