# 原版音频上下文、模式音乐与样本总线

## 本批范围

接续原 G0-G6，源为 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`。本批在北京时间 2026-10-16 04:59 后开始，不属于已失败的 `manifest-8581d52a.json`，不以旧包签新代码。没有启动 GPU、服务、构建、提交或上传；统一实际 Web 验收由 root 执行。

## 根因与修改

- `HangarApp` 以前把所有局内状态选成 `training`。新增 `audio.GameMusicState` 直译冻结 `gameMusic.musicState`，把试车映射为 training、打捞局内为 salvage、竞技/剧情/无尽/陨坑为 drive-combat；打捞局外仍是 hangar。
- 恢复匹配 .4、briefing .25、反馈 .45、菜单 .5、射击 .63、通讯 .5 的优先关系。`MusicPlayer.Update` 增加可选 context，保留旧调用、曲序、共享 RNG、两槽准备/取消和 2.4 秒渐变；上下文暂停与用户暂停独立，音乐盒覆盖上下文暂停与 duck。
- 原版开场整个序列及竞技 briefing 都压低 driving/weapons/damage/ambience 总线，迁移版只看 `voice.card`，所以开场漏压。现在 `AudioLevels.MixContext` 统一以 .12 秒指数包络趋向 .3，反馈占用时趋向 .65，其他时间恢复 1。
- 原版 feedback/ui 总线不受该压低。命中、击毁确认、修复、得分与 UI 不再错误跟着全部变小；energy_online 也按原 feedback 分类。BattleFlow、击毁/目标/失败 cue、通讯对应原 battle-flow cue 注册实际音长 + .15 秒反馈窗口。
- 原 uiSound 的 sampleMaster 是 `sfx * .65 / .6`。此前 Lua 缺少该系数。本批只给显式登记的原 uiSound 样本总线补系数，IntroAudio 独立图、语音、打捞离线合成音不套入。
- 删除样本声压提前 clamp(1)，保留原 cue trim 和 strength 的限制。FeedbackSounds 的 game_over 原先仍用已被原 battle-flow 覆盖的 recovery B，现引用项目已有 battle-flow A 与原 gain，不生成替代音色。

## 验证

- `tools/migration/verify-game-audio-context.py`：**851 PASS**。执行实际冻结 JS `gameMusic.musicState` 的 96 组合、实际 `uiSound.mixContext` 的 6 总线包络及 sampleMaster、实际 Lua Weapon/Driving/Feedback/Flow/StoryRadio 播放共 58 cue、8 loop 的上下文进出；检查实际 MusicPlayer 上下文暂停/用户暂停/音乐盒与隐藏状态。
- `verify-music-preparation.py`：**554 PASS**，包括原 12 曲 shuffle/共享随机数/取消/后台准备/两槽渐变。
- `verify-intro-audio-envelope.py`：**1529 PASS**。IntroAudio 文件仍为 `7586339dc88c22a6663233961fffc5cdb1435544dafc6b11b1a0e8a46a8b8f82`，未修改。
- `check-ui-sounds.py`：**200 PASS**，实际 Widget 路由、7 原 WAV、gain/gap/音量即时变化；旧错误 master 断言已改成冻结源 sampleMaster。
- `check-intro-sortie-feedback.py`：**28 PASS**，实际开场驾驶输入/伤害/HUD 反馈路由回归。
- `git diff --check` 范围检查通过。`check-driving-audio.lua` 原 native fixture 改用共享上下文验证，但本批没有运行 native，不能写成 native PASS。

精确源 SHA 与本批脚本 SHA 见 `evidence/game-audio-context-offline.json`，其他证据分别为 music-preparation / intro-audio-envelope / ui-sounds / intro-sortie-feedback-offline JSON。

## 实际 Web 可观察与未关闭项

只读接口 `require('audio.AudioLevels').ContextSnapshot()` 返回 `target/gain/feedbackActive/sampleMaster/buses`，每总线含 source 数和独立 gain；MusicPlayer 可观察 `group/duck/duckLevel/contextPaused`。生产无 QA 入口。下一统一包实际 opening 应看到 target=.3 且 gain 趋近 .3；发生实际命中时 feedback bus gain=1。

仍 OPEN：文档暴露的 Lua API 没有原 compressor、matching 低通/回声、tv_cut 低通或音频时钟 AudioParam 调度；Lua 包络会受主线程卡顿影响。原所有样本共享 10 one-shot/20 loop，当前多个模块仍独立池；武器 loop 的速率/声像包络和尾音调度仍有差异；原播放器同 pool destination 变更换曲语义尚未接入。原恢复空间 HRTF/随距离低通也未等价实现。本批不扩这些行为。

以上离线适配器没有测原生 gain headroom、耳听输出、回调连续性、GPU、网页流畅度或手机真机。实际开场、听感与性能验收必须以新统一构建结果为准。
