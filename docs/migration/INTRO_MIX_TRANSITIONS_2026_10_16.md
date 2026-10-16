# 开场声音交互与切换补全

> 下文生产 SHA 属于收入9b的声音交互批。9b之后的真实音源完成等待修复与最新 SHA 见 `INTRO_VOICE_CLOCK_2026_10_16.md`；不得用本表旧 SHA 代表当前生产。

## 范围与构建隔离

接续 `CURRENT_EXECUTION.md`，不重开 G0。冻结源 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`。本批是 e9 不可变候选之后的独立生产增量，不属于 e9 或 5f，不能复用其 Web 验收结果。

只修复已只读确认的声音差异，保留字幕、样式、全部响度常量与全局音量规则。没有运行 GPU、构建、服务、提交或上传。

## 已补与逐项验收

| 项目 | 原差异 | 当前实现与验收 |
| --- | --- | --- |
| 决定长按的心跳 | 固定速率，决定后硬停 | 实际 Session.Update 按 `1+holdProgress*.9` 乘原采样频率；0/.25/.5/.75/1 对照执行冻结源实际语句。决定和跳过均走100ms淡出，再保留20ms停止尾部 |
| 花屏切换 | 450ms硬停 | 450ms墙钟后开始150ms音频淡出，再保留20ms停止尾部。失焦时墙钟仍能排入淡出，音频时钟保持暂停；恢复后继续淡出 |
| 停止配音 | 立即停止 | 全部在播配音80ms淡出、20ms后停止。音量滑杆继续乘当前淡出值；新一句使用同独立音频场景中的空闲源槽，保留旧句尾段，不覆盖旧源。源槽按峰值并发创建、结束后复用，整个场景在取消/尾段截止时一并释放 |
| 签名抬手/取消 | 立即停止签名沙沙声 | 实际 IntroPage.OnPointerUp/Cancel 调用100ms渐出，并带SFX token避免迟到旧句柄误停复用后的声音；重复抬手不重排尾部 |
| 音乐未完全淡入时切走 | 按满幅速度减，提前归零 | StopMusic记录当前插值值，再按完整目标时长线性到零，停止另保留20ms；零时长及默认800ms入场也按源规则执行 |
| 通讯展开 | 缺少连接提示音 | 实际 Run 到comms时只触发一次 `confirm vol=.6`，与原introStory270行一致 |

音乐中断的具体复现：750/1000相对音量、1200ms淡入，300ms时请求600ms停止；请求时原增益 .1875，150ms之后冻结H5为 .140625，旧Lua为0。当前实际Lua已按真实源自动化逐样本通过。

## 测试与证据

- 新增 `tools/migration/verify-intro-mix-transitions.py`，**358项 PASS**，证据 `evidence/intro-mix-transitions-offline.json`。真实冻结 IntroAudio.js 经 vm.SourceTextModule 执行，真实Lua IntroAudio、IntroSession.Update/Run 和 IntroPage 指针处理在Lua5.4执行。
- 覆盖语音80ms停止、旧句/新句并发、未满幅/零时长音乐停止、花屏150ms停止、签名100ms停止、心跳5档、失焦暂停/恢复、音量中途修改、slot复用token与立即取消释放。
- `source-intro-audio.cjs` 新增上述真实源自动化样本和原心跳语句执行。原源码先按冻结registry逐SHA验证，未用手抄常量替代源运行。
- 最终生产SHA上实际重跑：包络 **1529**、独立音频尾段 **402**、完成交接 **53**、运行生命周期 **423**、签名布局/指针 **53**、原演出时序 **3953**，全部 PASS。各报告依赖关联已刷新；`check-intro-contract.py`只补新的StopSfx适配边界，不修改原53项断言。
- 未执行原生 `check-audio-levels.lua`。上述原生SoundSource、Scene、UI和WebAudio边界使用受控适配器，不证明原生实际输出或听感。

## 最终生产 SHA

| 文件 | SHA256 |
| --- | --- |
| `scripts/audio/IntroAudio.lua` | `e7482426babe20b6e09612b49b5f6deb282df2096e9eb805ab1ffdf7a3f2e9d0` |
| `scripts/audio/IntroAudioTail.lua` | `f86b7ddd5325372fde607f11a52ae98397559d4a3bebcd6e2aca77f7c264d9b7` |
| `scripts/intro/IntroSession.lua` | `9869f1c2b8f2de682f1d2648ba0ec7e5f81a38931b0f12104f2553d708996149` |
| `scripts/ui/IntroPage.lua` | `4135bef813f2d3f9f57ac4307ed7854dd389c328b947842d7a52a05913a2b2f0` |

## 仍未关闭

- 原总输出 DynamicsCompressor：threshold -14、knee8、ratio4、attack .004、release .2；尚未确认等效引擎接口，没有猜API或用统一降音量代替。
- 花屏声1800Hz/Q .5低通仍缺；当前只补原淡出，不宣称高频听感已一致。
- 语音振幅驱动嘴型/声波仍缺，现有固定动画不等同源分析器。
- 普通局部增益包络仍用既有focused Lua音频时钟，帧dt截断时不等于原AudioContext真实时钟；独立结束主淡出另有focused墙钟近似，详见上一份 `INTRO_AUDIO_TAIL_2026_10_16.md`。不能签所有焦点边界逐样本一致。
- 必须统一下一候选自然完整播放、快速跳过与对话推进、真实签名、回厅和音源释放；不可将离线检查当作连续音频、无长帧、完整1:1或手机真机通过。
