# G4 通讯、签约、盖章与开门镜头时钟

2026-10-16。对照固定 H5 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`。

## 已修差异

生产只修改 `scripts/intro/IntroSession.lua`，当前 SHA256 `ee64cbda80f72353ddb880bb825f583dc4ea51846c7f3b5db5f2cfecc445f3b9`。本文件同时包含协作线程负责的工资条冲击效果四处接线，效果模块与 Page 由另一线程独占。

1. H5 `intro.js:1268` 在 `prepareStoryScene` 注册一个持续 camera task；`mark(contract/stamp)` 不清此 task。旧 Lua 用每个 shot 的 age 算镜头，签约、盖章会把它跳回起点。现在通讯入场记录 `storyCameraAt`，后续镜头使用同一经过时间。
2. H5 该镜头持续到门缝开完、`prepareStoryGate` 清 task。旧 Lua 进入 gate 就停止更新这段镜头。现在 gate 前段继续共享时钟，闸门推进开始后才切换。只看闸门的调试入口从 gate 入场开始建立此时钟，与源调试路径 `prepareStoryScene` 对齐。
3. H5 `introStory.js:582` 门缝动画结束后立即调用 `prepareStoryGate`，再等 0.3 秒并开始门全开/音乐淡出。旧 Lua 在该 0.3 秒之后才设置 `gateCameraAt`，推进晚了 300 毫秒。现在把设置移到 `.36` 等待后、`.3` 等待前，音乐和关门后等待保持原位置。
4. `Start` 清两个镜头起点，避免取消后再次开始沿用上次时钟。

## 验证

- `source-intro-story-camera.mjs` 执行完整冻结 `prepareStoryScene/prepareStoryGate/task/mark/update/camMove`，真实源算法产生 13 个通讯、签约、盖章、门缝及推进帧。门闸时点复用实际冻结 `IntroStory.actGate` oracle，源 camera cue 为闸门开始后 **3.94 秒**。
- `check-intro-story-camera.py` 对比实际 Lua `Camera/Mark` 的上述帧，并实际跑 `Run/Update` 的 contract、gate-only、normal 三条路径；Ad/Vivi 由明确适配器隔离。三路的 camera cue 分别为约 3.950、3.956、3.952 秒，1ms 步长多段等待的离散误差小于 25ms，没有原来的 300ms 延迟。
- 每帧检查签约、盖章、门闸前半段仍用源 scene 起点；覆盖失焦冻结及再次 Start 清理。
- 三个负控均实际失败：旧 5b8c、恢复每 shot age、恢复 gate 晚 300ms。工具记录 74,335 个含逐帧断言，验收含义是 13 个源码帧与三条真实 Lua 流程，不代表自然整段演出已验收。
- 既有旁白/时间线 **3,989 检查 PASS**；退场释放 **53 检查 PASS**；工资条基础镜头 **616 检查 PASS**。

证据：`docs/migration/evidence/intro-story-camera-offline.json`，及 `intro-timing-offline.json`、`intro-finish-offline.json`、`intro-payslip-camera-offline.json`。

## 边界

没有修改 OpeningHost、IntroShots 或渲染灯光。测试执行真实时钟和摄像机生产代码，但适配原生场景与 DOM，不证明布局、画面/声音听感、GPU、加载性能或自然完整开篇。本批尚待主线下一包验证，不能借前包 5b8c 宣称完成。
