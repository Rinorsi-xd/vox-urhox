# 剧情移动端交互入口

基线为 H5 `2026-10-15`，提交 `b276064942ae09c0227ec28d4cfda1d5ff006455`，使用已冻结的 `outgame-baseline.json`，没有追随工作区未冻结修改。

## 已修复

原版 `shared/ui/storyHud.js:169` 将未阻挡且 `key!==false` 的提示传给 `TouchControls._tickDrive`，再由其显示交互按钮。迁移版 `scripts/ui/TouchDriveControls.lua` 原先只考虑打捞提示与翻正，剧情虽然显示“按住安装 / 清理涂鸦”，却没有可按的移动端入口。Mission.AfterStep 已经消费 `controls.held.interact`，因此只需接回情境按钮。

当前安装点内且速度不超过 2.5 m/s 时显示交互；清理涂鸦阶段在范围内显示交互；自动占点阶段仍不显示交互。保留换货优先级、打捞提示和翻正后备入口。长按开始与松开仍使用原有 Hold 分支。

生产文件 SHA256：`scripts/ui/TouchDriveControls.lua` = `e14a04e57bc19a753b7ed34155ab04e888228fbcf180c7300883ed11d80c0ec5`。

## 已验证

`story-touch-prompt-source.mjs` 实际执行冻结 H5 的完整 StoryHud、StoryMission、capture kind 与 TouchControls 方法；`verify-story-touch-prompt.py` 实际执行生产 Lua adapter。16 个源场景、129 项检查通过，覆盖范围内外、速度阻挡、占点/清理、死亡/结束、打捞/换货、翻正优先级、菜单与阻挡隐藏、长按松开及离开范围后松开。

负控有效：49c15 旧包 14 处差异、把 scrub 错写为 cap 为 10 处、移除安装速度限制为 9 处、移除换货优先级为 4 处。证据位于 `evidence/story-touch-prompt-offline.json`，包含生产、工具、冻结源 SHA256。

复跑命令：`C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe tools/migration/verify-story-touch-prompt.py`。

## 待自然验收

由 root 同包执行 20:9 横屏触屏：剧情第一关到安装点，停稳后长按交互满 2.4 秒，离开范围/松开不能继续增长；第四关占点应自动推进而不出现交互，反扑结束进入清理阶段，长按交互满 1.6 秒完成；打捞换货与倒翻按钮不能回归。

本任务不占用 GPU、未构建、未启动原生/Web、未提交上传。DOM/UI/物理使用适配器，死亡/结束清除源 prompt 由夹具显式控制；129 项逻辑检查不能替代实际触屏命中、画面或性能验收。共享审计注册由 root 处理。

## 另外两处审计发现（尚未修改）

- 通讯音量驱动表现缺失：H5 `three/src/intro/introStory.js:276` 读取 `audio.level()`，以幅度驱动声波条，并在音量低于 0.09 时闭嘴。当前 `ui/IntroPage.lua:252` 声波仅随正弦跳动，`ui/CommsPortrait.lua:64` 嘴型按 0.09 秒固定翻转。语音中的停顿不能与原版一致。此为表现差异，尚未听感/像素验收。
- 电视切换音的专用低通缺失：H5 `introStory.js:215` 以 `lowpass:1800` 播放 tv_cut，`introAudio.js:90` 使用低通 Q=0.5；当前 `intro/IntroSession.lua:208` 与 `audio/IntroAudio.lua:68` 未实现该选项。若采用离线派生音频，只应替换这一用途，不能改变另一个 vol=.8 的 tv_cut 入口。
