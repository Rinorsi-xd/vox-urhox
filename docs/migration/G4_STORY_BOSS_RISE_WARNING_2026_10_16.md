# S5 首领连续跪地的起身预警

## 确定缺项与修复

对标固定 H5 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`。原 `three/src/battle/storyBoss.js` 的 `FoxBoss.onHit` 在跪地伤害达到本次 18% 上限、首领仍存活时，先清 `_riseWarned` 再进入 `rise`。迁移版 `BossRules.Hit` 遗漏这个复位。

可复现顺序：跪地到 6.5 秒显示“它要站起来了” → 8 秒前打满伤害上限、强制起身 → 20 秒护甲期结束再打破另一节点 → 下一次跪地到 6.5 秒。旧迁移版的预警标志仍为 true，因此第二次不发起身预警；H5 会再次提示。

生产仅修改 `scripts/story/BossRules.lua` 强制起身分支一行，加入 `self.riseWarned=false`。不改伤害、计时、护甲、剧情或成功条件。保留同文件此前已有修改。

## 实际验证

`tools/migration/story-boss-rise-warning-source.mjs` 校验冻结源 SHA 后执行完整原 `FoxBoss.onHit/update`，并加载原第五关台词。Python/Lupa 执行实际 Lua `BossRules.Hit/Step`。共 **1333 检查 / 30 序列 / 222 帧 PASS**：覆盖预警前后、伤害低于/等于/超过上限、下一次节点击破和跪地、自然起身及致死血量边界。

真实旧生产负控读取 `.tmp/outgame-cached-1792123715225/scripts/story/BossRules.lua`，SHA256 `0e18085ace561ad7bf217c8d45a639fcb1343e76f5cef19811d4d0163261d9fb`，13 个序列出现差异，包含下一次预警缺失。没有通过临时删代码冒充旧版本。

运行命令：

```powershell
C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe tools/migration/verify-story-boss-rise-warning.py
```

结果为 `docs/migration/evidence/story-boss-rise-warning-offline.json`。7 份关联报告均通过真实重跑刷新，共 3983 检查：`story-boss-barks`、`story-boss-combat-flow`、`story-boss-defeat`、`story-boss-kneel-dialogue`、`story-boss-exposed`、`story-boss-exposed-production`、`story-boss-exposed-staged`，均为 `*-offline.json`；最后一份明确保留独立旧 staged target，只更新本次运行实际观察的 production hashes，不称其为新生产验收。

| 输入 | SHA256 |
| --- | --- |
| `scripts/story/BossRules.lua` | `9fde0fb155b11abad1bde5e736bbd3bdb9b5f94046c4cb53a10b81e843bc8847` |
| `tools/migration/story-boss-rise-warning-source.mjs` | `e5bc80c79c108b7d702085a850454e9cecd59030dd407454bb9e83a73ab742e0` |
| `tools/migration/verify-story-boss-rise-warning.py` | `59e719e81c22717ba314c95a917245c900d512d7cba083b948b7ce5f94b5ad29` |

## 验收边界

这些是实际源逻辑 CPU 对照，原 HUD/音频/车辆接口由替身承接。没有启动 GPU、浏览器、构建或上传；不能签自然 S5 胜利、完整片尾、可见预警样式、可闻音频或持续性能。既有 S5 入口/返厅通过证据继续只代表入口/返厅。
