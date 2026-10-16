# Independent audit: manifest-989c7ba6

Result: **PASS for content identity, emitted payloads, evidence freshness, HTTP identity and scoped delta**. This audit does not close natural runtime, GPU, audio continuity, memory or visual acceptance.

## Package And Evidence

- Immutable snapshot: `.tmp/outgame-cached-1792105799832`.
- Manifest: `manifest-989c7ba6.json`, 7512 entries.
- Script fingerprint: `2253d618d9e28b4650dff8c70a4be8e58639f515814eed10540bba7ed0379df8`.
- Frozen H5 source commit remains `b276064942ae09c0227ec28d4cfda1d5ff006455`.
- All 514 workspace/snapshot/identity/manifest Lua files match. All 514 actual emitted Lua payloads match SHA256, size and blocking status.
- Final registry includes `intro-promo-fx` and `intro-comic-motion`. All 78 reports and 424 associations have zero drift: 405 packaged production, 18 evidence-tool and 1 API-reference associations. Current opening and historical regression scopes both pass.
- Actual resource payload audits pass: 46 resources, 11 font/license resources, 12 voices, 7 UI sounds and 7 radio sounds. These checks establish bytes and headers, not decoded playback.

Commands actually executed independently:

```text
node tools/migration/audit-unified-snapshot.cjs .tmp/outgame-cached-1792105799832
node tools/migration/audit-snapshot-http.cjs .tmp/outgame-cached-1792105799832 4389 4390
node tools/migration/audit-snapshot-delta.cjs .tmp/outgame-cached-1792104742555 .tmp/outgame-cached-1792105799832
```

The unified audit was rerun after the final comic-motion registry addition and root's QA-tool report refresh. No packaged file or production source was edited during this audit.

## Actual HTTP

| Check | Ordinary | QA |
| --- | --- | --- |
| Port / PID | 4389 / 63524 | 4390 / 30372 |
| Package | manifest-989c7ba6 | manifest-989c7ba6 |
| Lua identities | all 514 match | all 514 match |
| Main bytes | 2625 | 84444 |
| Main contract | exact packed main | exact packed main + newline + current probe |
| Experimental profiles | all disabled | all disabled |

Ordinary raw manifest equals disk, SHA `9dc33853efdc63f373fce54d5b105c3741332162945594c4ec7cef609497f62d`. QA manifest's only structural change is the injected main size. Current probe SHA is `c5e612d75b43d0a4abfac71d813587aca5138a2979f9d6bf116bae988306636c`. Both HTTP identity rereads remain stable.

## Delta From 6cf48957

Exactly eight authored Lua content changes; no asset content changes or engine source identity changes. Metadata churn is reported separately: 1449 metadata changes and eight normalized manifest changes.

| Production file | New SHA256 |
| --- | --- |
| scripts/app/OpeningHost.lua | d26bd0f28b9c8c436b7f75266ce06d5c30bfb5d160ae1af8e7b36044601cf3f5 |
| scripts/intro/IntroWarmup.lua | efdcef9602b3a0b5e1a0bda94d6cf8404e55f98aa0730a835319ad920adf656b |
| scripts/ui/IntroComic.lua | a38a37480ba9b7064a78d1219bf1b5c37322311b48ca8ae77be76d9af3ab59ed |
| scripts/ui/IntroPayslip.lua | 4a3bd7ba925c4a72baae49c467d40b605ffb6c7b343906941e2ff9230cc1838b |
| scripts/ui/IntroPromo.lua | 8526965f2307f3bd6b907950357ef81603fd2e0577f69919608d7bcab88f896d |
| scripts/intro/IntroSceneCapture.lua (new) | 3a6dd3c981af22ae5bae49a9d89b20301cd13ce51beb99a9777c815eea1e3749 |
| scripts/ui/IntroComicMotion.lua (new) | 1e496cd133148a8457969f5bd763068077de21d623e9591b7f339b82c76bdcb1 |
| scripts/ui/IntroPromoFx.lua (new) | 6d195118dc818ae4004d023638927000379d5c6afd0b390ed471aeb142dc03ea |

## Saved Evidence

| File | SHA256 |
| --- | --- |
| evidence/unified-snapshot-manifest-989c7ba6-audit.json | 419c374ce6cdd45782ff481b3d6d808428145a3ac0354f880a4715243e1818f3 |
| evidence/http-snapshot-manifest-989c7ba6-audit.json | b2f2b6fe4db8f1782bd21bac8fc18ad76e4b3afa8be84d750b236617ca48f0ef |
| evidence/snapshot-manifest-989c7ba6-delta.json | 5a1c69950790217a55f67942763017bf091a0aa64476b4afda01a8eb925fcc38 |

The previous 6cf independent report and unified/HTTP/delta evidence were rehashed and retain their recorded SHA values (`6622364f...`, `23e95fd2...`, `ace04f02...`, `e089d340...`). This audit did not overwrite prior package evidence. No browser, GPU, build or native runtime was started by this auditor; root owns the separate natural run.
