# G4 剧情目标栏完成与切换呈现

## 基线与本批边界

- 冻结 H5：分支 `2026-10-15`，提交 `b276064942ae09c0227ec28d4cfda1d5ff006455`。
- 继续现有 G0–G6，不重开 G0。本批是 `manifest-c787bbd6.json` 审计后的独立生产增量，不能借用 c787 的 Web 结果验收。
- 只改目标栏呈现与 Mission 的窄接线，没有修改 MissionRules、关卡数据、任务推进、复活倒数、对白或音效顺序；没有新增资源、生成素材、提交或上传。

## 具体原版行为与已修缺口

源文件 `shared/ui/storyHud.js:64–81`、`shared/css/storyHud.css:47–57`、`three/src/battle/storyMission.js:141–148,601–612`：

1. 第一个目标直接设置标题/提示，并播放 420ms 的 `opacity 0→1`、`translateX(-18px)→0`、`brightness(2.2)→1`。缓动是原 `cubic-bezier(.16,1,.3,1)`。
2. 已有目标时，编号立即更新；旧标题/提示先进入绿色完成态，650ms 后换成新内容，再播放相同的 420ms 进入动画。
3. 完成态标题与菱形边框为原 `#3ddc84`，菱形填色按原 background `.2s` 过渡；完成光晕为原 14px / 0.7 alpha，正常橙色 `#ff6a13`、10px / 0.5 alpha。标题为原 23px、1.2 行高、1px 字距。
4. `retitle()` 是立即替换当前可见标题，不能提前换提示、重新播放进入动画或合并掉原版快速连续目标的定时切换。
5. 最后完成仅设完成态、清地图标记，保留最后目标和最后有效编号；不是因为逻辑步骤越界就把目标栏删掉。原结算等待至少 4 秒且等待通讯结束，保持原规则不动。

此前 `MissionHud` 逐帧直接读取 `rules:StepSpec()`，造成目标瞬间替换、没有完成色与动画、末步骤后目标栏立刻消失。

本批新增 `scripts/ui/MissionObjective.lua`，持有真实毫秒时间、可见标题/提示、原始顺序的待切换队列、填色过渡和进入动画。`Mission.New/Events/Update/Dispose` 只同步已有目标/完成/动态标题事件及释放。`MissionHud` 根据呈现状态决定目标栏是否绘制，任务地图标记和其他 HUD 保持原逻辑。Boss 在渲染帧内临时改标题也立即接入，未改动的旧标题不会在迟到的切换后重新覆盖新内容。

## 可逐条验收的离线结果

运行：

```powershell
& 'C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' tools/migration/verify-story-objective.py
```

`docs/migration/evidence/story-objective-offline.json`：**934 PASS**。

- 执行冻结的完整 `StoryHud` 类里的真实方法与原 `touchCopy`，不是另写伪 JS 目标状态机。CSS/WAAPI 的源参数经独立高精度插值，与真实生产 Lua 对照。
- 10 源场景、93 操作时点：首目标、下一目标、原触屏提示、等待期 retitle、连续 retitle、快速多个原定时器、末目标保留、末目标赶在旧定时器前完成、死亡倒数和未开始状态。
- 明确覆盖 0/1/199/200/419/420/649/650/651/850/1069/1070ms 边界。共享既有 Lua 缓动 16 次二分的误差容差为 0.002 逻辑像素/数值，原值未修改。
- 实际生产 `Draw` 的颜色、10/14px 光晕、tracking/line-height、标题提示、alpha/transform 和 save/restore 用绘制适配器检查。
- 实际 Mission 目标事件、动态标题、死亡期真实时间、最终 `StepSpec=nil` 的保留、Boss 帧内标题更新、迟到切换后不被未变旧 Boss 标题覆盖、Dispose/晚到调用/新实例隔离。
- 实际 `MissionHud.Render` 在逻辑步骤为空时仍绘目标栏，Boss cinematic 时仍隐藏目标栏。

本批最终 Mission SHA 下既有回归：输入/进度 **296 PASS**；死亡期间选择/片尾 **171 PASS**；护送目标 **128 PASS**；结算对白 **1392 PASS**。

## 冻结 SHA

| 文件 | SHA256 |
|---|---|
| `scripts/ui/MissionObjective.lua` | `fcc94c9e8d8feb07ec495865eebc9efe1f49d5a45489864704dd112e27865632` |
| `scripts/ui/MissionHud.lua` | `ab2a95d5f6a199316d0e8b2a7f7ae751f4a077b66813484b20206c9a2bb40961` |
| `scripts/story/Mission.lua` | `a4f01f0d3e223fd7947f2cb4e25be92e38e4fa0969a37931a489f9e472432ff2` |
| `scripts/story/MissionRules.lua`（未改） | `d559056af4e3fd955d0f6b8dcac4af5f0abc2897f5cc86316bde85d11db532eb` |

## 仍需同包运行验收

- 主线程统一包后，实际 Web 进剧情并看首目标、至少一次自然切换与最终完成画面，确认无 Lua 绑定错误。
- NanoVG box gradient / 文本颜色模拟原 CSS blur / brightness，离线数值与调用不能证明原生像素级光晕一致，需要真实截图对照。
- 本批不是目标栏其余排版/所有字体/整段自然剧情/音频连续性或真机性能通过声明；没有启动 GPU 测试。
