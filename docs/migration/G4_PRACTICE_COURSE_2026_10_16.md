# 训练节足练习按钮缺失反馈

固定源：10/15 `b276064942ae09c0227ec28d4cfda1d5ff006455`。本轮仅修改生产 `scripts/ui/DriveHud.lua` 两个节足练习按钮的共用回调。未修改 HangarApp、Mission、IntroComic、SceneLoader、GameAmbience、TrialSession、probe 或共享注册器；无 GPU、构建、提交或上传。

## 缺口与最小修复

原 `three/src/drive/testDrive.js` 构造 DriveHud 时的 `onLegCourse`：检查 active、查找指定传送点、`_spawn(spot)`，随后给出 `info / 6000ms` 操作提示，并调用 `resumeInput()`。当前迁移按钮只执行 `session:GoTo`，点击后没有原提示，也没有主动恢复驾驶输入。

已补：成功 GoTo 后显示原文「节足山坡/节足抓墙：W 前进 / 贴墙自动抓附，空格蹬开，长按收腿」，强度/时长 `info / 6000`，然后调用既有 `Resume()`。已释放 session 或缺失传送目标不提示、不恢复。保留原按钮、坐标、GoTo/Reset/鼠标捕获实现。

最终生产 SHA256：`scripts/ui/DriveHud.lua` = `92afa1f41c934b6476663ae0a838954440f6ebc46a778564549f0bd367cd99dc`。

## 实际验证

命令：`C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe tools/migration/check-practice-course.py`。

**12 场景、40 检查、5 负控 PASS**。SHA 固定并执行原 JS 真正的 onLegCourse 回调；执行实际 Lua `DriveHud.Create` 所创建的两个 onClick，以及从当前 `TrialSession` 提取的真实 `GoTo` 方法。覆盖活动/释放、两有效课程/缺失名、存在/缺失传送点，比较传送→原文/类别/时长→Resume顺序。

五个负控是实际冻结 `manifest-49c15ba7` 的旧 DriveHud、删除 Resume、错误3200ms时长、释放后仍运行、缺失目标仍恢复。均被行为检查拒绝。UI 构造在两个课程按钮创建后受控结束，物理传送、toast设备和Resume捕获是边缘适配器；没有用文本扫描代替回调执行。

受影响历史报告按最终生产实跑：`verify-match-banner-offline.py` **1499 PASS**；`verify-match-hud-detail-offline.py` **19904 PASS**。旧两报告保留于 `.tmp/practice-course-before/`。`git diff --check` PASS。新证据 `evidence/practice-course-offline.json`，交 root 统一登记；本路未修改注册器。

## 新包真实短验

用合法含节足移动件的现有车进入训练/试车场（map `trial`）。按 Esc 释放鼠标，使右上练习按钮可点击；点击「练习：山坡」，应传到「节足山坡」、显示原提示约6秒并自动重新捕获鼠标。持 W 应实际移动，证明不需额外点击画面。再次 Esc，点击「练习：抓墙 / 跳跃」，应传到「节足抓墙」、显示同一原提示并恢复捕获；W 靠墙、空格蹬开/长按收腿走既有行为。最终 T 正常回厅，检查错误和释放。

专用工具 `tools/migration/check-practice-course-web.cjs` 已准备，使用公开工坊安装「蝎型战车」，T 进入训练并严格断言 map `trial`，对两个课程分别执行 Esc、真实按钮点击、目标 XZ、实际浏览器 pointer lock、无补点画面的 W 位移，最后 T 回厅并观察释放。必须设置 `VOX_QA_PORT` 和 `VOX_EXPECT_MANIFEST` 后由 root 独占运行。本路仅执行 `node --check`，没有启动浏览器。

共享 probe 无 toast 字段，因此工具保存每次点击后立即的提示截图，并明确返回 `FUNCTIONAL_PASS_VISUAL_PENDING` 或 `FAIL`；精确渲染文案与截图仍需实际视觉复核，不把 CPU 文案/时长验证冒充画面通过。工具不签贴墙/蹬墙、自然训练长程、移动端或性能；剧情/自由入口也没有被这一个训练回调修复覆盖。
