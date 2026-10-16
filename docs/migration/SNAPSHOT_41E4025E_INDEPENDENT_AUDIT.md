# 41e4025e 独立包审计

继续既有 G0-G6。本批只独立审查、重跑离线工具、补强审查工具与整理证据；未修改生产代码、未运行 GPU/browser/native、未提交或推送。

## 唯一包身份

- H5：`2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`。
- 快照：`.tmp/outgame-cached-1792081852213`。
- manifest：`manifest-41e4025e.json`，7466 文件。
- 脚本指纹：`6aa95b260594bd840d6aa3a5ded4680c3679d0f449d977e5229ed6026964988a`。
- targetCommit 字段 `9541dc59ef2f281cafa5126762a57550189e04dc`，包含未提交增量，以逐 SHA 与指纹识别本包。

## 实际检查

| 检查 | 结果与边界 |
| --- | --- |
| 全 Lua 身份 | 源码、快照、identity、manifest 各 479 项一致；全部 479 个实际发布 payload 逐 SHA 匹配，均 blocking。审查工具已直接核对发布字节。 |
| 漂移重跑 | 初审 5 条文件 SHA 漂移来自 HangarApp/TrialSession。实际运行原 CombatResult 13005、MatchActions 103、StoryInputProgress 296、G5EditTouch 92 项均通过；最终 13 份报告的 63 条 SHA 为 0 漂移。没有手动改预期 hash 代替执行。 |
| Root 修复 | `HangarApp ee1177c4…ef496` 确实在包内。实际引擎 UI.SetRoot/UI.Render、LoadingPage、晚到/重复 BuildHud.Dispose 和 DriveHud/GarageHud root 安装审查 13 项通过；主切场 122 项通过。完整 HUD/原生绘图使用替身。 |
| 无尽出生呈现 | 新 SpawnPresentation 和 EndlessSession/TrialSession 接线已入包。独立运行冻结 H5 的 rise/update 228 情形与生产 Lua，共 497 项通过，含实际构造/重生/改装返回、Update/PostUpdate 和节点显隐恢复。物理/渲染节点为替身，不签视觉与性能。 |
| 预载与下载 | 459 个启动资源及 payload 完整；Crater 保持按需。Track 253 / Crater 540 个冷入场下载依赖可解析。 |
| 原始纹理字节 | 13 个 CPU PNG.bin 与 RGBA16F LTC 发布字节一致；12 个离线地形原 PNG 与 sidecar 不重复发布。 |
| 小地图烘焙 | 原工具重新检查 1147 输入通过，像素 SHA `120e033ecfe616a38040bcaecd317eff9ab2fe4225b50c86f5e6d1968a069b16`。 |
| 既有资源 | 两份交易 JSON、结果语音 registry、12 条源录音及派生 OGG 身份与包清单一致；身份不能证明真实解码与播放连续。 |

以上签收范围是包身份、离线行为与发布依赖。`CombatResult` 对 HangarApp/TrialSession 仅记录接线文件 SHA，不表示完整两模块已执行。其他实际行为边界以各 evidence 的 boundary 为准。

## 不得覆盖的失败

旧 b932b9cd 真实取消黑屏/恢复死锁 FAIL 原样保留；本包包含修复，但尚需同包实际取消与恢复、非空加载页检查。旧第三次进图 OOM、严重帧率与冷加载 FAIL 也未关闭。不能把本报告当成浏览器、自然整局、全视觉、真实账号、编辑器或手机持续性能通过。

## 证据

- `evidence/unified-snapshot-manifest-41e4025e-audit.json`
- `evidence/loading-root-lifecycle-offline.json`
- `evidence/web-map-transition-offline.json`
- `evidence/endless-spawn-offline.json`
- `evidence/combat-result-production-offline.json`
- `evidence/match-actions-offline.json`
- `evidence/story-input-progress-offline.json`
- `evidence/g5-edit-touch-offline.json`
- 旧失败：`evidence/map-cancel-manifest-b932b9cd-2026-10-15T16-25-26-606Z/`
