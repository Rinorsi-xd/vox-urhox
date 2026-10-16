# 剧情安装、夺点与损毁反馈

基线：H5 `2026-10-15` / `b276064942ae09c0227ec28d4cfda1d5ff006455`，使用 `outgame-baseline.json` 中冻结文件及 SHA256。范围仅为 `MissionHud` 中三组反馈，不改玩法、物理、灯光、全局字体或主题。当前 8b / 4453 不可变优化验收包不包含本次新增 HUD，后续合包需单独验收。

## 已修复

- 安装提示恢复原文的闲置、进行中、车速过快三分支及副标题；使用 84 px SVG 对应的圆环，半径 `34 × 84 / 80 = 35.7`，线宽 `5 × 84 / 80 = 5.25`。阻挡变红，标题 `#ffb0b4`，正常强调色 `#ff6a13`。
- 夺点原先被迁成横向进度条，现与原版共用圆环。自动夺点隐藏键帽；有海盗时显示数量；反扑阶段隐藏提示；清理涂鸦恢复按住 G / 交互的原文及副标题。冻结源 DOM 的键帽字面值始终是 G，即使触屏也没有改字符；触屏的实际情境交互入口沿用既有 `TouchDriveControls`。
- 损毁恢复 `ceil` 整数秒与“从上一个检查点重新空投”原文、260 × 3 px 复活进度条、13/46/15 px 字号和原版颜色，补回红色边缘暗纹、阶梯闪烁与淡入淡出。所有绘制仍由现有 UI Panel 持有 VG 帧与横屏缩放。
- 提示淡入淡出 200 ms、损毁 300 ms，使用原 CSS ease；补齐 CSS 的反向过渡缩时。提示淡入半程收起时，Chrome 实测反向时长 160.480678 ms；损毁对应为 240.721017 ms，固定 200/300 ms 的实现不能通过该检查。
- 真正的 `StoryMission.update` 死亡分支只更新 dead/marker/pips 后返回，并不清除 prompt。新表现层会保持死亡前的提示快照；不会因现有 `MissionRules` 死亡时衰减 install 而改掉源保留的文字与进度。本次没有更改该玩法规则。

生产冻结 SHA256：

| 文件 | SHA256 |
| --- | --- |
| `scripts/ui/MissionHud.lua` | `8b42e0515f478a202d246e73153a3dce7d8ad786819f2a897031404ee8ec8ef6` |
| `scripts/ui/MissionPrompt.lua` | `ed2c26066794f1514a8ba83c26812256d574279a41d255e66e2a0e5a3b4a3026` |

## 已验证

`verify-story-feedback.py` 实际运行校验 SHA 的冻结 `StoryHud.prompt/dead`、`StoryMission.update`、`KINDS.capture.update`，对照生产 `CaptureRules`、提示状态及真正的 `MissionHud.Render`。60 个源场景、9 个死亡边界、2 条死亡连续帧、实际 CSS 采样对照，共 771 项检查 PASS。

六个负控均检出：固定提交 `48ef15f2` 的实际旧 HUD 173 处差异，夺点错显键帽 16 处，安装固定文案 24 处，小数死亡倒计时 16 处，漏掉 CSS 反向缩时 12 处，死亡期间重新读取衰减安装进度 16 处。旧 HUD 来自固定 git 对象，不依赖移动 HEAD 或临时包路径。

`check-story-feedback-css.cjs` 使用 Chrome 155 独立原 CSS / 原 DOM 小页，启动参数禁用 GPU、WebGL 和软件光栅器，无游戏与 canvas。实际采样 SVG 尺寸、原 G 键帽、闪烁与淡入淡出。闪烁四个平台确为 `1 / .625 / .25 / .625`；Chrome 在恰好 600 ms 的浮点边界仍得到 .25，而 601 ms 得到 .625，因此离线对比在阶梯边界明确保留 1 ms 容差。

关联 `verify-story-objective.py` 已实际复跑 934 项 PASS，`verify-story-touch-prompt.py` 129 项 PASS。并非直接修改旧报告的签名。新证据注册名为 `story-feedback`。

复跑命令：

```powershell
node tools/migration/check-story-feedback-css.cjs
C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe tools/migration/verify-story-feedback.py
```

证据：`evidence/story-feedback-css.json`、`evidence/story-feedback-offline.json`。后者关联生产、工具、CSS 实测报告及冻结源 SHA256。

## 待同包验收

1. 第一关实际开到安装点：PC / 20:9 横屏触屏分别确认闲置、按住、松开回退、车速过快和离圈淡出。
2. 第四关实际夺点、反扑、清理：确认夺点无 G、海盗数量正确、清理有交互、完成后正常消失。
3. 实际损毁后确认整数倒计时、红色边缘纹理、复活条、闪烁与复活后淡出；存活时不得出现损毁遮罩。

离线测试的原生 UI / VG、相关对象均有适配器。独立 Chrome CSS 实测不是引擎画面验收；VG 光晕是当前引擎内的近似绘制，字体光栅、原生模糊、边缘纹理和完整视觉仍需截图对照。没有启动引擎或游戏浏览器，没有签自然 S1/S4、移动真机、持续性能或全部 G4 完成；未提交、未推送。

后续窄修已移除 MissionRules 死亡期间的安装衰减，原 HUD 快照仍保留；详细实际 H5 连续死亡/复活对照、43 项窄范围检查，以及尚未修复的 30 Hz 复活同帧回退和低帧率剧情时钟，见 `G4_INSTALL_DEATH_PROGRESS_2026_10_16.md`。本反馈报告的 HUD 生产哈希不变，771 项离线检查已在该窄修后实际复跑；不借此签收全帧率玩法一致。
