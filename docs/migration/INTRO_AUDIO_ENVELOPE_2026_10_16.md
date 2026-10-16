# 开篇原音频包络与触发审计

接续 `CURRENT_EXECUTION.md` 的 10/16 开场反馈修复，不重开 G0。冻结源 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`，本项不负责 IntroSession、OpeningHost 或 IntroBattle。

## 已修复

`scripts/audio/IntroAudio.lua` SHA256 `7586339dc88c22a6663233961fffc5cdb1435544dafc6b11b1a0e8a46a8b8f82`。

冻结 `three/src/intro/introAudio.js` 的 speech duck 是线性自动化：说话时音乐由 .55 在 .15 秒内到 .24，结束或停止语音后在 .6 秒内恢复 .55。旧 Lua 即刻切换，已补原包络。重入语音从当前包络值继续；单帧跨过语音结束时，从实际 voiceUntil 开始恢复；失焦暂停保留时钟和包络。

原 SFX 的 20 个响度常数、归一化到 -12 dB 且最大 2 倍、主音量 .9、相对 rate、全局 .65 默认音效总线仍保留，没有用统一降音量代替原音效平衡。

补 `StopSfx(source,fade,token)` 原线性渐出，默认 .05 秒，音量归零后保留源 `src.stop(now+fade+.02)` 的 .02 秒尾部排程。重复 stop 从当前包络值继续，全局音量变化不抹掉淡出；新的 Sfx 重用槽时清旧排程。Sfx 保持第一返回值原 SoundSource，新增第二返回值 token，调用方可传第三参数防止旧句柄误停重用后的声音。

## 已执行验证

`tools/migration/verify-intro-audio-envelope.py` 执行冻结实际 `introAudio.js` 和当前实际 `IntroAudio.lua` / `AudioLevels.lua`。WebAudio 图和 AudioParam 排程由适配器记录；不是抄常量后的静态字符串检查。

`evidence/intro-audio-envelope-offline.json` 记录 1529 项 PASS：14 个语音开始、攻击中点、结束、恢复中点、停止与重入包络样本；全部 20 种 SFX、4 种全局音量、3 种相对音量、3 种 rate，共 720 种参数组合的增益和绝对频率；5 类原 stop 参数、重复 stop 的 6 样本、渐出期间滑杆、旧 token 和槽重用、失焦和释放检查。`source-intro-audio.cjs` 的 node 语法检查通过。

`check-audio-levels.lua` 的旧即刻 .24 假设已更新为实际 .15 秒攻击和 .6 秒恢复断言；新 native 测试尚未执行，不能复用旧 PASS。

## 触发所有权与仍未完成项

- IntroSession 的原 cue、工资条/银河 beep 与门动画由 g1 负责；首次驾驶、伤害与射击反馈由 root 负责。此报告不把参数对照当作全部触发正确。
- 出击实际可达入口是 `introSortie.js` 的 `playSortie`：alarm vol .32，metal vol .8 / fade .05 / offset 6。初审引用的 `intro.js` 旧 actInvasion .45/.95 已撤回，未在本音频模块实施，禁止迁入废案。
- 源 DynamicsCompressor 为 threshold -14、knee 8、ratio 4、attack .004、release .2；当前 Lua 尚未接入等效原生处理，API 能力未确认。
- 源 tv_cut 有 1800 Hz、Q .5 低通；当前 Lua 尚无等效低通。不能以音量替代或标成已完成。
- 原 stop 淡出接口已补并交给 g1 接线，仍有多处旧 StopImmediate；heartbeat 随长按改变 rate 的触发需由场景所有者逐项核可达流程。不能因接口通过即签所有可达调用完成。
- 新包必须实际播放完整开篇并测试回厅音乐盒、语音连续性、主线程长帧、峰值和听感。适配器不验证原生解码、混音压缩/低通、实际声压、GPU、Web 或手机性能。

本项未启动 GPU、服务、构建、提交或上传。14f 的功能与连续性失败仍为旧包证据，不随本项离线通过改签。
