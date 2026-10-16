# d966b4f2 独立包审计

沿用既有 G0-G6。本报告仅签包身份、发布字节与证据新鲜度。独立审计未启动 GPU、浏览器或原生运行，不以本报告关闭视觉、自然整局或性能项。

## 唯一包身份

- H5：`2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`。
- 快照：`.tmp/outgame-cached-1792082498209`。
- manifest：`manifest-d966b4f2.json`，7466 文件。
- 脚本指纹：`a826acb9a277fbfde7c6cb12c966b8e46b7b2ba97262be6852c5737cb702110f`。
- targetCommit 字段：`9541dc59ef2f281cafa5126762a57550189e04dc`。存在未提交增量，实际包以逐文件 SHA 和脚本指纹识别。

## 实际检查

执行 `node tools/migration/audit-unified-snapshot.cjs .tmp/outgame-cached-1792082498209`，结果 **PASS**。

| 检查 | 结果 |
| --- | --- |
| Lua 全集 | 当前源码、快照、identity、manifest 各 479 项一致。 |
| 实际发布内容 | 479 个实际发布 Lua payload 逐 SHA 匹配快照和 identity，479/479 PASS；均具有 blocking 标记。不是只检查 manifest 文件名或大小。 |
| 离线报告新鲜度 | 13 份既有报告中的 63 条生产 SHA 与最终快照一致，0 漂移。该项没有重新执行这些报告所覆盖的全部行为。 |
| 交易与结果资源 | Outgame、SalvageRules、ResultVoices 配置身份及包内引用一致；12 条结果录音的派生 OGG 身份一致。 |
| 故事输入接线 | 输入模块存在于 identity/manifest，Mission 中目标/驾驶接线与委派静态检查通过。 |
| 涂装增量 | `controls/LiveryControls.lua` 的实际包 SHA 为 `4d0114c4a25d7e37f67190383286601784c0940b468199cc41f22bd3972b5847`，对应新增背景双指手势。 |

## 涂装专项

实际冻结源 JS 与实际生产 Lua 的离线黄金对照为 **8195/8195 PASS**，旧实现真实行为 FAIL 保存在 `evidence/livery-touch-before.json`。本次专项报告为 `LIVERY_TOUCH_GESTURES_2026_10_16.md`。

真实 Web 专项由 root 在 QA 4337 串行执行，启动任务 34721。当前报告编写时仍待结果；不将工具语法通过或离线替身检查当成浏览器签收。专项工具启动前验证 QA identity、manifest 及上述 LiveryControls SHA。

## 保留的失败与验收边界

旧 b932b9cd 的真实取消黑屏/恢复死锁 FAIL 原始证据继续保留；41e 包上的修复和实际取消/战斗结果属于该包自己的证据。d966 包的独立字节审计不能替代同包运行。

旧进图 OOM、严重性能与冷加载失败不因本次未复现或包审计通过而关闭。真实账号、编辑器、完整视觉、自然整局、实际音频连续性和手机持续性能仍由其专项验收证据判定。OGG 文件正确不能证明解码播放连续。

## 证据

- `evidence/unified-snapshot-manifest-d966b4f2-audit.json`
- `evidence/livery-touch-offline.json`
- `evidence/livery-touch-before.json`
- `LIVERY_TOUCH_GESTURES_2026_10_16.md`
- `SNAPSHOT_41E4025E_INDEPENDENT_AUDIT.md`
- `SNAPSHOT_B932B9CD_INDEPENDENT_AUDIT.md`
