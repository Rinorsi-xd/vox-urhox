# 通讯配音真实完成时钟

> 最新增量在82a不可变候选之后：Session已合入n17空字幕、真实后停提示生命周期和首帧raw下载并行；生产冻结 SHA 见下表。82a已结束：65功能PASS、连续性FAIL；它不包含这些新增，不能借它签收。

接续 CURRENT_EXECUTION，不重开 G0。冻结 H5 为 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`。本修复在不可变 `manifest-9b1ad62f` 之后，不能借 e9/9b 自然 Web 结果签修复通过。仅修改 IntroAudio / IntroSession 两个生产模块，未构建、运行 GPU、启动服务、提交或上传。

## 只读实际证据

来源：`evidence/intro-natural-web-1600x900-manifest-e9f25319.json` 与 `evidence/intro-natural-web-1600x900-manifest-9b1ad62f-profile.json` 的 samples。以下 at 为采样的 Unix 毫秒。

| 样本 | at | v12 lineAge / duration | native voice | audio.time / voiceUntil |
| --- | --- | --- | --- | --- |
| e9 | 1792101201618 | 7.651310 / 7.700450 | playing=false，resource为空 | 210.616253 / 210.665393 |
| 9b | 1792101955712 | 7.310955 / 7.700450 | playing=false，resource为空 | 211.468376 / 211.857871 |
| 9b 后续 | 1792101955762 | 7.361742 / 7.700450 | playing=false，resource为空 | 211.519163 / 211.857871 |

两个包均出现声音源已结束、对白还在等帧计时的状态；9b 至少跨50ms的两个样本。此时 voiceUntil 尚在未来，排除本模块达到估算期限后 StopImmediate 造成这一样本。v12 首末样本的墙钟减 dt 累积差约 e9 388ms / 9b 395ms；这不是精确 onended 时间或可直接等同的额外停顿。没有专门的 onended 探针，采样间隔也不恒定。

前七句通讯 v01/v02/v03/v04/v07/v08/v09 的各自墙钟减 dt 差约 -3..1ms，未观察到提前结束；不能概括成每句都拖长。9b 本轮最终为59功能检查后 OOM，不能拿局部样本签整个自然运行通过。

证据 SHA256：

- e9 JSON：`8f380e891ddc10b8d5f89d66f57c497fca39b3770d4f4913ac7a7d7cb238371a`
- 9b profile JSON：`27aff0c3d648da12c5d0d43af3d6eb87ade6f05ad98c4826a0355927385bd537`

## 源规则与最小修复

原 `introStory.js:306-328` 的 Vivi 先等待打字任务（至少600ms，否则为音长的92%），再等待 `audio.voice()` 的 Promise；`introAudio.js:135-150` 在真实 WebAudio onended 才 resolve。第一次点击补全文字，第二次点击 StopVoice 并立即推进，不再等待停止尾段。默认之后等900ms，v09/v12 的 wait=false 不等这段。原 `intro.js:333-346` 的 Say 本来使用动画 wait(duration+tail)，不应全局改成墙钟或音源等待。

当前实现：

- Voice 保留首返回音长，加第二返回独立递增 token；IsVoicePlaying 查询对应代次，旧槽复用不会让前一句等到下一句。
- `.emmylua/SoundSource.d.lua:114-124` 明确 IsPlaying 在 fade-in 时为真、fade-out 时为假，因此完成查询和空槽选择都考虑 native fadingOut；Dispose 后先退出，不再访问已释放音源。
- 自然配音不再按估算 untilAt 强制停止。实际音源结束后清自然 duck 成员；停止淡出立即退出 duck 成员，旧尾段结束不会解除新一句的 duck。voiceUntil 留作估算展示，不能充当完成信号。
- Vivi 保留原打字阶段，再等对应真实音源，保留两次点击与原900ms后停；缺少/未准备/零长资源不进入音源等待，仍按原文本长度完成打字。失焦保持既有暂停，恢复后观察源状态。
- waitingAdvance仅在打字与真实音源均结束、wait不为false的900ms等待阶段为真；开始/Mark/Dispose/等待结束清理，当前lineVoiceToken同步清理。v09/v12不进入该提示阶段。源nx类在函数返回后可能仍存在直至下一句，测试比较实际等待阶段，不把返回后的孤立DOM残留当作仍在等待。
- Choose成功时记录choiceAt原动画时间，新选择开始清理；重复选择不重启该时钟。供g2实现原240/280/320ms退出动画，仍保留原260ms进入下一句。
- Say/Wait、字幕、字体、UI绘制、全局时钟、音量常量没有改动。80ms停止渐出和20ms停止尾段仍为既有控制包络。

## 验证

`tools/migration/verify-intro-voice-clock.py`：最新 **330 PASS**，报告 `evidence/intro-voice-clock-offline.json`。冻结实际 IntroStory.vivi 与 IntroAudio.voice 经 vm.SourceTextModule 执行；实际 Lua Session.Vivi/Advance/Update/Say 与 IntroAudio 经 Lua5.4 执行。原生播放状态、焦点和音源结束为独立受控适配器。最初253项属于82a前批；追加实际源nx显示阶段、当前token/Mark/Dispose/选择时间后为330项。

- 对照八条源路线：音源早完、音源晚完、打字阶段已完音频、两次点击、缺资源、缺资源点击补字、900ms停顿、点击略过停顿。
- 另验 native fade-out、槽代次复用、新旧语音与 duck、立即取消/Dispose、失焦恢复、零长资源、Say仍等原动画时间。
- 两个9b历史负对照（旧 Session + 新 Audio；旧 Session + 旧 Audio）均在 `natural-before-duration` 失败，证明可识别原问题，没有删断言放行。
- 同批实际重跑：包络1529、独立尾段402、声音交互358，全部 PASS。包络适配器在源 action=end 时显式报告原生自然完成，不再依赖被删除的帧时间硬停。
- 交接 finish 首次在并行 OpeningHost 提前退休修改期间失败于 one-pause/queued-world预期；root修复重复Pause、保持finishPaused语义后实际重跑53 PASS；新增退休生命周期14项使runtime总437 PASS，sortie28 PASS。本agent未修改或放宽这些断言；最终结果由root提供，原失败仍保留在执行记录。

## 最终 SHA256

| 文件 | SHA256 |
| --- | --- |
| scripts/audio/IntroAudio.lua | `75520300312e3f69e5024b686cc57e97539b18abd19dab01a921deae6f681ee3` |
| scripts/intro/IntroSession.lua | `c897536f3dd67695313dcb9a29b795a4a0f257a2e31bb91c92c6ba341019514d` |
| tools/migration/source-intro-audio.cjs | `8ce0557f115cd21f72ba5b3481d40b2ec000738d477b53b953add61a6f5c1c46` |
| tools/migration/verify-intro-voice-clock.py | `63c5ba0b8ed5bf356abfe9ff4d44ec1019b338af8d81501bc111c640674d6a04` |
| evidence/intro-voice-clock-offline.json | `79c6c879e6b43789dde5608761cf1bfb079a576ebfdc3f9178bf15d0a301bd6e` |

引擎 `.emmylua/SoundSource.d.lua` 为只读API参考，其SHA记在报告的 apiReferenceHashes，未误列作需打包的生产文件。

## 冻结后的关联报告刷新

当前c897与g2六页面模块冻结后已实际重跑：timing3989、voice330、mix358、prefetch176、gate920均PASS；contract53由g2实际刷新。该批raw并行只改下载准入，不改变上述voice时钟；详见 INTRO_RAW_GROUP_OVERLAP。页面夹具补充新UI缩放/输入裁剪接口后保留原gate920断言，新增模块哈希也已登记。此段覆盖下方历史刷新清单的“当前”含义，不将离线结果当作自然Web连续性。

按 audit-unified-snapshot 注册关联实际重跑，没有只更新哈希：intro-timing3953、opening-construction328、opening-prefetch153、comms-portraits384、intro-portrait-handoff167、intro-sortie-feedback28、intro-gate920、intro-qa-tools30，全部 PASS。随后 audit-report-freshness 实查原注册71份报告/390条关联为 FRESH、0漂移，证据 `evidence/intro-next-report-freshness.json`。此数量尚不包含待登记的新 voice-clock；登记后仍应统一审计真实发布payload，不能把工作区新鲜度当作包验收。

## 仍需验收

下一统一包必须真实播放通讯/v12、快速两次推进、失焦恢复及取消，并检查真实声音结束后的推进与尾段释放。轮询只能在引擎帧恢复时看到音源完成，不是精确混音线程回调；不能解决主线程长冻结或证明音频连续。

UI箭头由g2消费waitingAdvance，仍需统一包实际验证；本agent未改Page绘制。嘴型依旧是旧lineAge/typing条件，没有新写近似，不签嘴型一致。普通增益淡出、总输出压缩/花屏低通、声音振幅分析与连续性仍按原报告保留 OPEN。
