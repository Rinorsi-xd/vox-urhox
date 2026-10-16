# 本轮统一报告 CPU 复核

生产、共享 probe、注册器未修改；无 GPU、构建、提交或上传。

首扫 `node tools/migration/audit-report-freshness.cjs .tmp/g5-current-report-freshness-before.json`：10 份报告、11 个输入关联陈旧，涉及 HangarApp、IntroComic、probe 和注册器。

旧十报告及 transition-probe 额外报告已保留在 `.tmp/cpu-freshness-2026-10-16-before/`。三份旧测试首次真实重跑失败也保存在该目录的 `failed-reruns.json`：intro-runtime / intro-gc-fence 在实际 HangarApp.Stop、web-map-transition 在实际 HangarApp.Update 访问缺失的夹具 `ambience`。只给三份 CPU 夹具增加显式无设备环境音适配器，未改生产或削减原断言。

以下命令均使用 `C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe` 实际执行：

| Python 参数 | 实际结果 |
| --- | --- |
| `tools/migration/check-intro-qa-tools.py` | PASS，50 检查，最终 probe 与注册器哈希 |
| `tools/migration/audit-transition-probe.py` | PASS，47 检查，7 场景，包含5个真实HandleUpdate检查 |
| `tools/migration/check-intro-gate-offline.py` | PASS，920 检查 / 88 场景 |
| `tools/migration/check-combat-result-production.py` | PASS，13005 检查 |
| `tools/migration/check-match-actions.py` | PASS，103 检查 |
| `tools/migration/check-ui-sounds.py` | PASS，200 检查 |
| `tools/migration/check-build-sounds.py` | PASS，124 检查 |
| `tools/migration/check-intro-runtime.py` | 夹具补齐后 PASS，446 检查，历史负控保留 |
| `tools/migration/verify-intro-audio-tail.py` | PASS，402 检查 |
| `tools/migration/check-intro-gc-fence.py` | 夹具补齐后 PASS，22命名场景，历史不安全负控保留 |
| `tools/migration/check-web-map-transition.py` | 夹具补齐后 PASS，124 检查；日志中的 download/activation/finish failures 属原故障注入断言 |

root 最后登记 `story-dead-player-park` 和 `ambience-audio` 后，再次实际执行 intro-qa-tools（50 PASS）及 `node tools/migration/audit-report-freshness.cjs .tmp/g5-current-report-freshness-after.json`：**FRESH / 94 份报告 / 499 输入关联 / 漂移0 / 剩余陈旧项0**。这是当前工作区输入关联检查，未执行或覆盖旧冻结包的统一包审计。

最终 QA probe：`d82996c9a89be40cc5a8d98098c61ea6757a6ba929021434edfe9609e83d9f0a`；QA 注册器输入：`bf69ce6303586e8b35c3866e000031d4baa3570075eb9d01272fd9178bb1b20b`。三夹具 `git diff --check` PASS。

这些 CPU 报告没有新增 GPU/Web/听感、加载连续性、自然全关/搜撤、平台账号或移动设备性能验收。后续任何生产或已登记工具变更仍需重查其关联报告。
