# 3ba 开篇音频迟滞归因

本批沿现有开场连续性失败调查，不重开 G0，不启动 GPU/服务，不改生产音频，不以功能 PASS 代替连续性验收。

## 固定证据

- 当前迁移基线 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`；`Intro.json` 仍保留原导入提交身份，不能把这个字段误称为当前迁移分支。
- 构建 `manifest-3ba43bd8.json`，完整自然开场 61 项功能 PASS、连续性 FAIL；错误 0。
- 原报告 SHA256 `b1e3b6b3298d89950ce26a9cb3f4190e35ae407f40ea16c50d72d095b73940cb`。
- 完整 `intro-natural-web-1600x900-manifest-3ba43bd8-audio-timeline.json` SHA256 `c53387abfd56ea3134f6e2b9d56f7064b2affb56277ef175fea013bc89a349c2`，包含原始 `playbackTime`。
- 本地实际 Web 引擎 `.tmp/web-engine/UrhoXRuntime.js` SHA256 `260edf443545a4531672291c3cfdddd73aee0d864cd8108b81b7d6422491884f`。输出实现 `SDL2.audio.scriptProcessorNode` 通过 `createScriptProcessor` 连接 destination，`onaudioprocess` 同步 `dynCall` 进入原生混音；这份 JS 没有 `audioWorklet`。

## 最大间隔确实跨过音频时钟，但不证明说话音节丢失

时间原点 `1792098420996.8`、时区偏移 -480。最大运行期间回调间隔：`331915.695 → 333389.530 ms`，相差 **1473.835 ms**。对应音频 `playbackTime` 从 `277.7466667 → 279.2266667 s`，跳过 **1480 ms**；两端 AudioContext 均为 running，输出 peak 均为 0。4096 帧 / 48000 Hz 每块 **85.333 ms**。

同一窗口 longtask（北京时间 10/16）：

| 起点 | 主线程占用 |
| --- | ---: |
| 05:12:32.404 | 269 ms |
| 05:12:32.715 | 195 ms |
| 05:12:32.939 | 745 ms |
| 05:12:33.774 | 157 ms |
| 05:12:33.948 | 187 ms |
| 05:12:34.150 | 221 ms |
| 05:12:34.386 | 251 ms |
| 05:12:34.774 | 195 ms |

最长 745 ms 主线程任务与后续密集长任务挤占了主线程 ScriptProcessor 的调度机会。旧探针在原生混音返回后取时间，未记录回调进入时间，仍不能拆出各次原生混音本身的成本，也不能唯一归因于某个 Lua 函数。

最大间隔结束于 **05:12:34.386**。1 项音乐下载组完成是 **05:12:33.680**；机库控件真实探针是 **33.697**；MusicPlayer 成功日志是 **34.644**，比该间隔结束晚 258 ms；教程 25 项完成是 **35.193**。因此最大回调间隔跨越回大厅，不能把旧 `shot:gate` 当作仍在 gate；不能认定 1473 ms 全由 MusicPlayer 的播放或第一句教程语音装载造成。

两端静音不代表连续性可通过。驾驶期间非零样本也有 **370.785 ms** 回调间隔，对应音频时钟跳 **370.667 ms**（`195584.785 → 195955.570 ms`），两端 peak `.18094/.33182`。这说明问题不只发生在本来无声的退场。17 个原饥饿候选、6 个 >250 ms RAF 全部保留，结论仍 FAIL。

旧数据 2222 个运行期间回调里有 212 个与上一条相同 `playbackTime`。旧探针没有处理器 ID，可能包含延迟后集中派发，不能据此认定多处理器、真实播放丢帧数量或物理扬声器输出。原 `event.playbackTime` 也不等于独立硬件录音证据。

## 本批修改和验证

仅修改 `tools/migration/check-intro-natural-web.cjs`：

- 每个处理器/AudioContext 固定 ID，记录创建参数和 statechange。
- 原混音回调前后分别取 `performance.now()` 和 `currentTime`，分开记录 delivery wait 与 `mixMs`；保留原输出 RMS/peak、录音片段和原始 at。
- 增加每处理器诊断；原 `250 ms / 3 个 buffer` 判定、原总体连续性 PASS 条件均不变。
- 实际确认回大厅后刷新标记；保留原始回调，不能回写历史 `gate` 样本。
- 保留 `baseline` 导入身份，新增 `sourceDataBaseline` 和 `migrationBaseline.branch/commit`。

`node tools/migration/check-intro-audio-meter.cjs` 实际执行当前 AudioMeter 函数，**27 项 PASS**；覆盖原混音仅调用一次/this、12 ms 混音与 488 ms 等待分离、多个处理器同 playbackTime、上下文状态变更、替换与清空 handler。`node --check tools/migration/check-intro-natural-web.cjs` 通过。未启动浏览器，因此新增字段的实际 Web 证据仍待 root 串行跑同包。

当前 MusicPlayer SHA256 `6b1679e1c9fd457a2f448723de8da9c46d0d84524bbf44694841b60879cb3098`，本批未改。场景所有者正在拆分已确认的同步退场/全 GC/资源释放；下一包必须记录回调进入/结束及各段清理计时，才可判断该窄修改是否减少饥饿。不能删除音效、增大阈值或用静音掩盖失败。
