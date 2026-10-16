# 开场结束音频尾段

## 基线

冻结源分支 `2026-10-15`，提交 `b276064942ae09c0227ec28d4cfda1d5ff006455`，以 `outgame-baseline.json` 的快照为准。

- `three/src/intro/introAudio.js` 原快照 SHA256：`28f82b26f0bbdae940be63d699520c8e94c1fc10302331634851ef5548c928ad`。
- `shared/audio/musicPlayer.js` 原快照 SHA256：`6de1321dd041e707eea4920da45aaf0c2444e4a0e0ce1e324e1c61d9e52e994c`。
- 这里是快照原始字节 SHA，包含原换行形式；不能用 Git blob LF SHA 替代。

## 交付

原 `_finish()` 在视觉淡出开始时调用 `fadeOutAll(1.2)`，视觉 700ms 后结束，而音频上下文到 1400ms 才关闭。迁移版现在把这些生命周期分开：

1. `IntroSession` 开始结束过程时调用 `IntroAudio:BeginTail()`；全部三个总线沿用原音量、duck、归一化及速率，只额外乘 1200ms 的主淡出。
2. 700ms 视觉交接时，把音频交给 `audio.IntroAudioTail`，Session 清除自身音频引用。尾段只持有独立音频场景，不持有开场 Session、Host、大厅或陨坑。
3. `HangarApp.Update` 推进尾段；1400ms 的绝对墙钟截止先于焦点判断，失焦也会释放。`HangarApp.Stop`、新开场构造和替换音频立即取消旧尾段，重复交接不重置截止。
4. 主淡出使用连续 focused 区间的墙钟差，避免引擎帧 dt 被截断后淡出拖长。源版使用 AudioContext 时钟；本实现是保守近似：焦点切换所在区间缺乏准确事件时刻，整段舍弃，恢复时不补扣失焦时间。不能宣称它与真实音频时钟逐样本一致。
5. `IntroAudioTail.Snapshot()` 只返回 `active/master/remainingWallMs/voicePlaying/sfxPlaying/musicPlaying` 数值和布尔值，供统一 Web 验证，不泄露任何场景或音频对象引用。

## 验证

- `verify-intro-audio-tail.py`：**402 项 PASS**。真实冻结 JS 经 vm.SourceTextModule 执行，真实 Lua IntroAudio、Tail、AudioLevels 在 Lua 5.4 执行。覆盖 0/350/700/1200/1399/1400ms、三个总线、音量变化、暂停/恢复、重复 finish/adopt、Stop、替换、墙钟大跳及查询无对象引用。
- 增加墙钟 1200ms 而每帧 `dt=.001` 的回归，三个总线均归零，1400ms 释放。此用例防止卡顿导致主淡出拖长。
- `verify-intro-audio-envelope.py`：**1529 项 PASS**，原 duck、SFX 包络、默认/零/重复停止、速率、音量变更与复用 token 未回归。
- 证据：`evidence/intro-audio-tail-offline.json`、`evidence/intro-audio-envelope-offline.json`。生产依赖 SHA 与证据关联。
- g1 的实际 Session/Host 结束生命周期检查独立维护；不把其替身 App 当作真实 HangarApp.Update/Stop 已执行的证据。

## 最终生产 SHA

| 文件 | SHA256 |
| --- | --- |
| `scripts/audio/IntroAudio.lua` | `14bdcc949f6f6df4e01b698d62fc94b168a9c74b916fb70667f6123ecc738369` |
| `scripts/audio/IntroAudioTail.lua` | `f4b41399b139e804e2343314e871bae498553ca50c783f4959e786044001cc2d` |
| `scripts/app/HangarApp.lua` | `112b5e165986e1ca22f0d20018bf14e18035fec67d075d65a311f4dd12b5aec0` |

## 尚未关闭

原生 SoundSource/Scene/cache 由受控适配器替代。非强制资源清理中播放引用保活只验证所有权模型；不等于真实引擎资源缓存已经测试。本批不运行 GPU、构建、服务、提交或上传；需主线程在统一新包实际验证尾段接管及最终 inactive。没有签自然音频连续性、真实输出、完整视觉 1:1 或移动真机性能。本增量不属于 5f 历史包。
