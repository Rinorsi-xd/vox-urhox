# G4 安装进度：死亡保留与未关闭的剧情帧时钟

基线为冻结 H5 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`，按 `outgame-baseline.json` 校验实际源文件 SHA256 后执行。仅修改 `scripts/story/MissionRules.lua` 死亡分支，删除一行 `install - dt * .8`；存活时松开 G、离开范围或移动过快的回退规则不变。没有修改 TrialSession、物理时钟、输入或 HUD。

## 已修复及实测

H5 `StoryMission.afterStep` 记录死亡并清除 holdG，`update` 的死亡分支在更新复活提示后直接返回，`_respawn` 也不会清除安装进度。迁移版之前在每个死亡固定步继续扣进度，导致 50% 安装进度在死亡三秒后归零。HUD 保留快照只能掩盖死亡期间的变化，复活后依然跳零。

新增 `story-install-death-source.mjs` 实际执行冻结 `TestDrive.update` 的无载具死亡路径和 `StoryMission.afterStep/update/_respawn`；`verify-story-install-death.py` 对照生产 `TrialSession.Tick`、`Mission.AfterStep/Events`、`MissionRules.Step`。物理、原生绘制/音频、摆放和下一任务表现有适配器；不是自然驾驶或画面验收。

9 组输入采用 0 / 1.2 / 2.39 秒安装进度，60 / 30 / 2 Hz，每组连续自然复活两次，再松开 G 一帧并重新按住。43 项窄范围检查 PASS：所有帧率的死亡 Step 均保持进入该 Step 前的进度；60 Hz 三组完整链与原版一致，死亡数恰好为 2、安装完成一次。1.2 秒进度在松键后变为 1.1866667 秒，重新按住需 73 帧；旧版需 145 帧。2.39 秒对应 2 帧，旧版同样需 145 帧。

负控来自固定 Git 对象 `48ef15f2c9c95c400f91ee6e34309399d02b3733:scripts/story/MissionRules.lua`，SHA256 `c2a3a29e4a6dc6065a66b80e5834a941d6db19c7c35082a71eeac4574bf8c5bc`；六组非零进度均实际检出差异，不使用移动 HEAD。

生产 `MissionRules.lua` SHA256：`64f6eb5a08f76513fbdc715ad56a813a8aa2cd6b2aa2bf64b8ed8ee88db54283`。

证据：`evidence/story-install-death-offline.json`。其中 `clockObservationNotAccepted` 显式保留未通过的其他帧率完整链，不能把报告整体 PASS 理解成全帧率复活链一致。

## 实际复跑关联检查

先归档八份旧报告到 `evidence/history/mission-before-install-death-2026-10-16/`，再运行工具生成当前生产哈希，未手改报告签名。

| 检查 | 检查数 | 结果 |
| --- | ---: | --- |
| story-install-death | 43 | PASS，仅上述范围 |
| story-objective | 934 | PASS |
| story-death-order | 2572 | PASS |
| story-car-size | 10535 | PASS |
| story-choice-presentation | 803 | PASS |
| story-choice-epilogue | 171 | PASS |
| story-mission-timers | 131 | PASS |
| story-event-order | 18 | PASS |
| story-zone-progress | 3186 | PASS |
| story-feedback | 771 | PASS |
| story-touch-prompt | 129 | PASS |

复跑入口：`C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe tools/migration/verify-story-install-death.py`。

## 未关闭项及下一批设计

1. **剧情时间受物理追帧上限影响。** H5 的 `testDrive.js:1038–1060` 在死亡无载具分支限制物理 accumulator，却把原始帧 dt 传给 `modeController.update`；迁移版 `TrialSession.lua:291–319` 限制每帧最多推进 .1 秒，再由 AfterStep 推进任务时间。2 Hz 实际执行中 H5 3 秒复活，迁移版 15.5 秒；60 Hz 也有一次固定步的首次死亡记录偏移（3.0 与 3.0167 秒）。本次未修，不能声称复活计时一致。
2. **复活后同一帧继续运行存活步骤。** 30 Hz 一帧两个固定步，复活可能在第一个发生，第二个立即执行存活松键回退；H5 该画面帧直接 return，下一画面帧才回退。双死亡后 1.2 秒安装进度重新按住需 75 帧，H5 仍是 73 帧。2 Hz 每帧多个步骤，差异更大（81 帧）。本次未修，不把这些完整链纳入通过项。

建议下一批把剧情的帧时间推进从物理 AfterStep 分离，保留物理 60 Hz 和 .1 秒追帧上限。按 H5 顺序：物理 AfterStep 首先记录损毁和敌人移除，画面帧末仅一次剧情 update；即使该帧复活也 return。使用原游戏缩放后的 dt（包括 KillImpact），不要把所有剧情改成真实墙钟；原本独立 setTimeout 的选项/失败重试仍由现有 MissionTimers 处理。先枚举 boot、死亡、完成、hold/escort 的死亡继续推进、capture/安装死亡暂停、暂停与失焦、失败重试、Boss 和事件只分发一次，再实现，防止双 Step 或重复刷兵。

后续检查需直接运行原 H5 完整帧链，对照 60 / 30 / 20 / 2 Hz、单帧 .5 秒停顿、hitstop、暂停恢复及复活当帧，不靠放开物理追帧硬补。性能/帧率提升未测量。

本次无 GPU、浏览器、引擎运行、构建、提交或推送。修复不在正在验收的 f9 固定包内，需后续统一包实际验收；未签自然 S1/S4、真机或 G4 整体完成。
