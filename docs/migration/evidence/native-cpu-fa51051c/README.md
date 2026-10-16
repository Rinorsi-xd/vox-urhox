# Native CPU evidence, requested fa51051c baseline

See `../../NATIVE_CPU_FA51051C_2026_10_16.md` for results and limitations.

`none.json.gz`, `coarse.json.gz`, `respawn-coverage.json.gz` are lossless gzip archives of the complete raw JSON. `archive-manifest.json` records compressed sizes/SHA256 and original sizes/SHA256; original hashes also appear in integrity.json. Prototype/fine runs are intentionally excluded.

Extract without external packages, from this directory:

```powershell
node -e 'const fs=require("node:fs"),z=require("node:zlib");for(const n of ["none","coarse","respawn-coverage"])fs.writeFileSync(n+".json",z.gunzipSync(fs.readFileSync(n+".json.gz")));'
node summarize.cjs none.json coarse.json
```

Extraction writes the three original files locally. Compare their SHA256 with archive-manifest.json before interpretation. `summary.json` was calculated only from corrected none/coarse, not the forced-death coverage run.

For reruns, export the production Lua files from `git show fa51051c:<path>` into an isolated source directory, preserving scripts/ hierarchy, and provide that snapshot to the runner. Also provide its .project configuration. **Do not copy current production scripts**: five subsequent files differ and were not measured. `frozen-scripts.json` is the authoritative 534-file SHA256 list; the runner refuses mismatching source, including any mismatch between a proposed Git export and the actual measured snapshot. Assets remain those of this project; runtime is pinned in run.ps1.

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File docs/migration/evidence/native-cpu-fa51051c/run.ps1 -SnapshotRoot .tmp/fa51051c-isolated -Mode none
pwsh -NoProfile -ExecutionPolicy Bypass -File docs/migration/evidence/native-cpu-fa51051c/run.ps1 -SnapshotRoot .tmp/fa51051c-isolated -Mode coarse
pwsh -NoProfile -ExecutionPolicy Bypass -File docs/migration/evidence/native-cpu-fa51051c/run.ps1 -SnapshotRoot .tmp/fa51051c-isolated -Mode coarse -Coverage
```

Rerun JSON/stdout/stderr are written under `.tmp/native-cpu-fa51051c-review/`. No production source changes, GPU measurements or mobile acceptance are performed. `original-run.ps1` records the temporary runner used for measurements; `run.ps1` is the review runner with explicit source/hash checks. `verify-integrity.cjs` records the original temporary snapshot workflow; it expects the original .tmp layout, not this archive directory. No 534-file source snapshot is included in the evidence archive.
