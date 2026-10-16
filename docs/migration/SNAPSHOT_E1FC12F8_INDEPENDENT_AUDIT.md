# e1fc12f8 独立审查

继续现有 G0-G6，仅只读生产审查、离线工具重跑及发布字节审计。没有新增生产改动，没有启动浏览器、GPU 或原生引擎，没有提交或上传。

## 固定身份

- 源：`2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`。
- 快照：`.tmp/outgame-cached-1792085173431`，manifest：`manifest-e1fc12f8.json`，7469 文件。
- 指纹：`ceead2388adb4f8d0a2c5eee2b3bbf38fdb57ac1325610150e6d5640794c1e6e`。
- 482 份 Lua 当前源码、快照、identity、manifest 和实际发布 payload 的 SHA 全相同；24 份报告、98 条文件 SHA 零漂移。
- TrialSession：`a869b6a78f71b322a36c78b7674f46cc8a8cf0493ca5b822abf4dc2e71b6decb`。

证据：`evidence/unified-snapshot-manifest-e1fc12f8-audit.json`。

## 渲染前事件同步

`TrialSession.ConsumeWorldEvents` 提取原固定步内的完整消费顺序，仍先音频、修复光壳和 HUD，再由 CombatView 消费并清空 viewEvents/debris，随后消费和清空 world.fx。固定步末尾行为保留；当本帧没有固定步但有排队事件时，先同步玩家，再执行同一消费逻辑，确保 DriveView.Update 不读取已销毁 Vehicle 的 suspension。

独立执行 G4 `verify-trial-event-boundary.py`：24 项通过，其中 1 项用实际 e266 TrialSession 重现 `Vehicle.lua:207 suspension=nil`，23 项执行新 Tick、真实 PlayerViewSync.Update、CombatView、DriveView.Update 和 Vehicle.Dispose/WheelPose。原生对象、音频、向量及几何为严格替身。

| 边界 | 检查结论 |
| --- | --- |
| 零固定步 | 敌车 kill/remove 先释放旧视图；surviving rebuild 先绑定最终存活车辆，再取 WheelPose。没有补跑物理或改变 fixedSteps。 |
| 玩家 | actual PlayerViewSync 对 alive+vehicle 才 Rebuild/Bind；死亡只隐藏玩家视图，不绑定退役 body。 |
| 幂等 | 两步物理中的单个命中只送入一次 hitFlash；三步物理仍各消费一次原批次；队列已清时不执行空尾消费。 |
| 仅碎片/特效 | debris-only、fx-only 零步帧也消费一次。 |
| 暂停输入 | pointer-unlocked 的 neutral Tick 同样同步生命周期，不恢复移动/开火输入。 |
| 提前返回 | endless editing/over、battle over、story finished、salvage finished 保留原提前返回：不消费、不渲染，不因该修复推进世界。编辑完成后的正常 rest 路径再消费新 Spawn。 |

本范围内未发现新的生产缺陷。F2 外部伤害确实复现调度窗口，不证明自然射击每次会触发旧失败。旧 e266 Web FAIL 不会被离线回归改为 PASS。

## 实际重跑旧报告

TrialSession 的 SHA 变化使三份纳入报告过期。已运行原工具，未只修改 hash：`check-combat-result-production.py` 13005 项、`check-match-actions.py` 103 项、`verify-story-input-progress.py` 296 项均通过。G5 已重跑出生呈现 497 项和退出生命周期 22 项；独立统一审计确认两份新报告与本包 SHA 相符。

命中光壳、旧跨基线伤害全等价夹具失败及其原因，见 `SNAPSHOT_971B2F95_INDEPENDENT_AUDIT.md`；本次没有改动那些生产文件。不能拿旧完整伤害等价通过替代当前基线。

## 修复补给符号只读发现

- 冻结源 `three/src/battle/endlessLoot.js:65` 使用 `<span style="font-size:44px">✚</span>`，继承 `EndlessHud` 的 VoxIndustrial/system-ui。
- 目标 `scripts/ui/EndlessWidgets.lua:10` 使用 44px `vox-title`。`SourceDraw.Begin` 的 title/body 都加载 `VoxIndustrial-Bold.otf`，故 title→body 不能补这个缺字。
- fontTools 实际检查：目标 8 个字体以及源 6 个 WOFF2 的 cmap 均无 U+271A，包含 MiSans、Industrial、Barlow、ChakraPetch、SmileySans。不能用换到这些现有字体修复。
- 本机 `C:/Windows/Fonts/seguisym.ttf` 与 `NotoSansSC-VF.ttf` 均含 `uni271A`；`segoeui.ttf`、`seguiemj.ttf`、`arial.ttf` 均不含。
- 最小建议：仅此修复符号指定含 U+271A 的符号字体，保留源 44px 和现有布局。跨平台分发可从允许分发的 OFL Noto Sans SC 取符号子集，不应复制 Windows 专有字体到游戏。
- 尚未获取源实际补给 span 的 Chromium platform-font 结果，故不能声称源实际用了 Noto 或 Segoe。GPU 测试释放后应对该 span 做 CDP 字形字体确认，再决定精确轮廓。此次没有修改字体、资源或生产 UI。

## 保留的待验

此审计不签 e1fc 实际 Web 渲染、自然整局、语音连续性、修复十字可见性、墙体遮挡与手机性能。旧 OOM、冷加载冻结、竞技严重帧时、G1 物理手感与 G2 字形/断行差异仍保留；后续同包 Web 结果单独记录。
