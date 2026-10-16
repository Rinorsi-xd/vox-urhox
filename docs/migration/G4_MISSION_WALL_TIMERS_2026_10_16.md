# G4 后半剧情：选项与任务重试的真实时间

## 基线与生产改动

对照固定 H5 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`，实际执行其 `storyMission.js` 的 `fail / ask / _beats` 和 `storyKinds.js` 的 hold、escort 重试回调。没有更新基线，没有修改开屏宿主或字幕。

原版失败后使用 `setTimeout(...,3000)`，选项使用默认 14 秒的真实时间倒计时，beat 的提问等待 300 毫秒。迁移版把这些期限绑定到 `MissionRules.time`，只在物理模拟 Step 时处理；暂停或失焦后模拟停止，失败重试和自动选项会一起冻结。

本次恢复原定时语义：

- `scripts/story/MissionRules.lua` 增加可注入时钟，选项、延迟提问与失败重试通过 `Now()` 判定；失败演出恢复 banner → 对白 → alert 的原顺序。
- `scripts/story/Mission.lua` 生产使用 `Time:GetSystemTime()`，完成构造后安装独立监听；任务销毁时立即释放。
- `scripts/story/MissionTimers.lua` 用独立 Node 的 ScriptObject 订阅全局 Update，只推进原本的墙钟回调与产生的事件，不推进战斗模拟。离场、销毁后停止并释放 Node。

生产 SHA256：

| 文件 | SHA256 |
| --- | --- |
| Mission.lua | `7d5417d63be3ff81b1284d5affd3ed5d5aa72aa5cf7c3070270183589ed2551b` |
| MissionRules.lua | `62313d779f4cff028116ebfdb585f7d9c752d2f5b50b4f92fd6095f9029f0de5` |
| MissionTimers.lua | `9cc821ae4cf6c588ab841dceda87799e5e5ebfb4eb6975e82c07185942ba5a6d` |

## 实际验证

新增 `verify-story-mission-timers.py` 和 `story-mission-timers-source.mjs`，运行冻结 H5 真正的回调，与实际 Lua Rules、MissionTimers、Mission.Events 比较。只替换 Node、UI、音频适配器；模拟时钟保持不动。

7 个案例、131 项检查通过：hold/escort 在 2999/3000ms 的重试、重复失败、离场取消、默认选项超时、手动选择不重复、beat 的 300ms 提问与后续超时。销毁调用两次仍释放任务引用和监听 Node。

负控确实检出错误：49c15 旧 Rules 在 6 个案例失败；只从模拟 Step 处理在 5 个案例失败；2.9 秒重试在 2 个案例失败；200ms 提问在 1 个案例失败。负控对比已规范化不存在的 flag，避免 nil/null 差异假阳性。

报告 `evidence/story-mission-timers-offline.json` 已注册到统一快照审计的 currentBatchReports。

受 Mission/MissionRules 整文件哈希影响的旧报告已先保存到 `evidence/history/mission-before-wall-timers-2026-10-16/`，再实际重跑：

| 报告 | 检查数 | 结果 |
| --- | ---: | --- |
| story-result-quote | 1392 | PASS |
| story-input-progress | 260 | PASS |
| story-choice-epilogue | 171 | PASS |
| story-objective | 934 | PASS |
| story-choice-presentation | 803 | PASS |
| story-death-order | 2572 | PASS |
| story-convoy-targets | 128 | PASS |
| story-mission-timers | 131 | PASS |
| 合计 | 6391 | PASS |

工作区 freshness 检查 `.tmp/mission-wall-timers-freshness.json` 中，上述所有已注册剧情报告没有输入漂移；全工作区仍有其他并行改动产生的 23 条漂移。本结果不宣称整个包已完成统一审计。注册器改变后，root 需要在最终冻结时重跑 intro-qa-tools。

## 尚未验收

- 本轮没有 GPU、浏览器或原生监听运行，没有构建、提交或上传。Node/ScriptObject 监听方式沿用已原生验证的 Boss 延迟方案，但不能替代本次新任务监听的实际运行证据。
- 没有签自然全五关、网页失焦、听感、画面 1:1、加载时长或播放连续性通过。
- 本轮只覆盖不重叠的选项。原版重叠定时器的特殊行为不在当前单 choice 模型或本报告验收范围内。
- 旧 check-convoy / check-siege 原生夹具用 185 个模拟帧期待 3 秒重试；若运行这些夹具，应为夹具显式注入时钟或真实等待 3 秒，不能据此把生产恢复为模拟时间。

复跑入口：`C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe tools/migration/verify-story-mission-timers.py`。

## 后续原生小测准备（尚未运行）

已准备 `check-story-mission-timers-native.lua` 与 `verify-story-mission-timers-native.ps1`，供 root 分配独占 GPU 窗口后执行：

`powershell -NoProfile -ExecutionPolicy Bypass -File tools/migration/verify-story-mission-timers-native.ps1 -ExclusiveNativeWindow`

夹具使用实际 Node、ScriptObject、全局 Update 和 `Time:GetSystemTime()`，从不调用 Rules.Step。20 项严格断言包含 300ms 延迟提问、真实超时与手动选择、3 秒 hold/escort 重试和事件分发、离场与销毁抑制；Dispose 后继续等待 400ms 的实际帧，检查旧监听不再回调。原生结果必须恰好 20/20、零错误、退出码 0、同时有 started/completed 标记，输入哈希运行前后相同。

目前只运行了 CPU 验证：PowerShell gate 的 1 正向、7 负向及 2 个真实子进程退出码控制通过；`check-story-mission-timers-native-offline.py` 的适配器调度回放 20 项通过，缺监听、遗留销毁订阅、漏掉观察阶段三种负控均能检出。这些不证明真实引擎监听已经通过；本子任务未运行原生或 GPU。

本报告原生产哈希对应墙钟修复刚完成时；其后 PARK 修复的最终 Mission 哈希与实际重跑证据见 `G4_DEAD_PLAYER_PARK_2026_10_16.md`，不借本报告历史哈希给新生产签收。

## root 已实际执行原生小测

2026-10-16 root 执行 session73986，进程退出 0。证据目录 `evidence/story-mission-timers-native-2026-10-16T02-25-33-471Z/` 中 validator 为 PASS / PASSED，20/20 断言通过，运行错误 0；manifest 记录 timedOut=false、changedDuringRun=[]。before/after 的最终 Mission 哈希均为 `cefa9c78ac98989a6ebbcb2139ce2a17edce61a362d9028faf876df6b5008cc1`。

因此本次真实 Node/ScriptObject 墙钟监听、定时事件分发和 Dispose 后续帧验证已通过。它仍不是浏览器失焦、自然完整任务、全剧情演出、听感或性能验收。
