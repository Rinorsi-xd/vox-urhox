# 回厅下载回调窄定位与独立 Web 实验

本轮承接既有 G0 证据，不重新开始 G0。固定构建：`.tmp/outgame-cached-1792120761228`，`manifest-35b14da3.json`；冻结 H5 为 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`。本文件对应 CPU 定位、可执行工具及两个最小 Web 实测，不代表完整回厅已通过。

## 已证事实

`evidence/intro-return-manifest-35b14da3-cpu-summary.json` 的 441ms 长任务窗口中，采样间隔归入下载完成回调调用栈约 404.38ms；self 归入 `_emscripten_get_now` 约 228.194ms、`now` 约 89.14ms。原报告保留约 66.8ms 时钟对齐包络，最近 gate 画面标记比长任务早约 1262ms。不能把旧画面标记当作当时 Lua 状态。

当前实际服务的 `.tmp/web-engine/UrhoXRuntime.js` SHA256 为 `260edf443545a4531672291c3cfdddd73aee0d864cd8108b81b7d6422491884f`；WASM 为 `4fb569673a30585b99bac49c1873f3b21140173d6876a851898d0d1b0f6ed765`。其实际实现为：

```javascript
function doCallback(f) {
  if (fetchAttrSynchronous) f();
  else callUserCallback(f);
}
// callUserCallback 直接执行 func()。
// reportSuccess 经 doCallback 直接调用 getWasmTableEntry(onsuccess)(fetch)。
```

因此异步网络完成后，JS 仍在 XHR 事件处理栈内同步进入 WASM 回调，不会自动推迟到下一引擎帧。`fetchXHR` 的 `xhr.onload` 在调用成功回调前执行 `saveResponseAndStatus()`，按条件分配内存并复制响应字节。XHR 处理器总时长包含这段复制和同步回调，不能叫作网络传输耗时。

实际 `ResourceGate` 完成函数直接执行调用方 callback；若两个文件已在本地，`Exists` 快速路径还会在 `Start()` 返回前同步完成。故调用方必须能处理同步完成和后续取消。普通 `MusicPlayer` / `GameAmbience` 已把 cache 排队留到 Update；原 `StoryCommsCues` 与 `StoryComms` 后备分支曾在下载回调里调用 cache，主线程正在独立修改并验证其延后操作。

## 尚未证明

现有采样不能指出具体 Lua callback、原生锁的持有者或等待对象。大量时钟调用与未命名 WASM 等待/代理样式相符，但不证明 `GetExistingResource` 或 `BackgroundLoadResource` 就是此 441ms 的根因。现有历史 WAT 未核对与当前 WASM 同源，不把函数语义猜测升级成当前证据。

将回调中的 cache 操作推迟到下一 Update 是合理的执行边界修正，目前没有测得它已消除这次冻结。不要将时间相关、Node HTTP 速度、下载并发数量或单次干净运行当作因果结论。

## 已实现的独立实验

工具：`serve-sound-callback.cjs`、`probe-sound-callback.lua`、`check-sound-callback-web.cjs`、`check-sound-callback-fixture.py`，均在 `tools/migration/`。

实际测试固定原始文件：

- `Sounds/Music/hangar-04-lost-mining-belt.mp3`
- `Sounds/Ambience/amb_hangar_a.wav`

服务器读取固定 35b manifest 和 payload，逐项验证其等于冻结 `assets/` 的字节；原 `app/ResourceGate.lua` 也验证同源。只对 QA HTTP 响应替换 `main.lua` 以及启动预载组（该 main、原 Gate、引擎默认 MiSans 字体），保留资源查找表。源工程、冻结产物和普通运行服务均不更改。入口没有 Scene、UI、播放、地图、完整开篇或游戏预热。

模式 `download`：下载回调只记标量和时钟；下一 Update 观察完成，等待十五帧，再走 warm 同步快速路径。模式 `prepare`：同样纯标记回调，下一 Update 之后每帧最多排队一个 Sound，再每帧最多观察两个 Sound 的 cache 就绪；warm 验证既有资源复用。没有在下载回调中打印日志或调用 cache。

保留原始 native `Time:GetSystemTime`、帧号、回调进入/退出、Start 返回、下一 Update、排队调用/返回和 observer-ready 时间；JS 记录 XHR send、onload 进入/退出、真实响应字节、CDP request/response/loadingFinished、resource timing、rAF 和 LongTask。JS/CDP/native 各自原始时钟不强行当同一时钟；observer-ready 不是原生 EndLoad 时刻。

CPU 自测已运行通过：真实 Lua 5.4 执行原冻结 Gate 和实际 probe，download/prepare 分别记录 60/68 帧，冷下载及 warm 同步回调均通过；fake native 接口断言禁止在 callback 内 reenter cache。实际 HTTP 临时服务器验证 manifest/entry 响应、确切两文件 SHA、路径约束。CPU fake 不算 Web 实测。

```powershell
node tools/migration/check-sound-callback-web.cjs --self-test

# 主线程独占 GPU 时运行；两个模式串行，端口可更换。
$env:VOX_PREVIEW_PORT='4420'
$env:VOX_CALLBACK_MODE='download'
node tools/migration/serve-sound-callback.cjs

# 另一终端执行并等其关闭浏览器。
$env:VOX_QA_PORT='4420'
node tools/migration/check-sound-callback-web.cjs

# 停止上一服务，再将 VOX_CALLBACK_MODE 改为 prepare，重复。
```

结果写入 `docs/migration/evidence/sound-callback-{mode}-{UTC}/`。生命周期 PASS 与严格 100ms 响应门槛分列，超过阈值必须保留 FAIL。初始两个文件必须不存在、warm 必须本地同步完成；必须观测确切两个 XHR 的 onload 进入退出，warm 不能再下载。任何条件不满足则工具 FAIL，不能改口说冷加载通过。

若纯下载已有长 onload，而 Lua 标记 callback 很短，可进一步查引擎完成派发/复制/代理等待；若纯下载短而下一帧 queue/readiness 出现尖峰，则缩到 Sound 准备路径。两模式仅缩小因果范围，不能推断锁持有者，也不能代表完整开篇、音乐连续性、移动端或生产性能改善。首轮不启用 CPU Profiler，避免采样开销混入窄对照；确需解释新尖峰再单独录制。

## 两个最小 Web 实测

主线程已串行运行两模式，结果来自以下原始 `result.json`；本次只补文档，没有重跑实验、修改生产代码或启动 GPU。

- [download 原始结果](evidence/sound-callback-download-2026-10-16T03-45-26-320Z/result.json)：UTC `03:45:26.320` 至 `03:45:49.955`。
- [prepare 原始结果](evidence/sound-callback-prepare-2026-10-16T03-46-42-803Z/result.json)：UTC `03:46:42.804` 至 `03:47:05.780`。

两次均核对相同冻结 manifest、引擎 JS/WASM、Gate 和两文件字节。每次仅观测到这两个目标文件各一次 XHR，状态均为 200；warm 不再发出目标文件请求。报告中的 `errors`、`httpFailures` 均为空，浏览器生命周期均为 `CLOSED`。下表的 `result=PASS` 只表示冷/热加载及下一帧生命周期断言通过；响应门槛独立保留 FAIL。

| 实测项 | download | prepare |
| --- | --- | --- |
| 生命周期 `result` / 浏览器 | PASS / CLOSED | PASS / CLOSED |
| 严格响应门槛：非 boot 帧最大间隔 ≤100ms | FAIL | FAIL |
| 非 boot 帧数 / 最大间隔 / P95 | 33 / 410ms / 283ms | 47 / 409ms / 17ms |
| MP3：2,625,662B，XHR `onload` 处理器时长 | 404.285ms | 403.120ms |
| WAV：1,872,044B，XHR `onload` 处理器时长 | 272.540ms | 274.350ms |
| 冷下载 Lua 纯标记 callback 进入至退出 | 0ms（原生毫秒分辨率） | 0ms（原生毫秒分辨率） |
| 冷 callback 至下一 Update / 帧号 | 4ms / 16→17 | 5ms / 17→18 |
| 后续帧调用 Sound 后台排队 | 无：此模式不准备 Sound | MP3 1ms，frame 19；WAV 0ms，frame 20 |
| 排队调用至首次 observer-ready | 无此步骤 | MP3 70ms，frame 24；WAV 116ms，frame 27 |
| warm Gate 同步完成 / callback 进入至退出 | 是 / 0ms | 是 / 0ms |
| warm callback 至下一 Update / 帧号 | 16ms / 32→33 | 16ms / 42→43 |
| warm 已有 Sound / 再排队 | 不检查 Sound | 两个均已有 / 均未再排队 |

prepare 的两次冷 `GetExistingResource` 检查均记录 0ms；两个后台排队均返回 true。后续各自出现 `ResourceBackgroundLoaded` 成功事件，MP3 `dataSize=2625662, compressed=true`，WAV `dataSize=1872000, compressed=false`。warm 的检查及复用也在后续 Update 中执行，分别为 frame 44、45。这里的 ready 是轮询观察到资源存在的上界，不是原生解码或 EndLoad 的精确完成时刻；0ms 仅表示没有跨过该原生毫秒时钟刻度。

这组实测已把复现范围缩小到：没有游戏 Scene、UI、地图、音频播放或游戏预热，且下载完成的 Lua callback 只做标记，仍出现约 273–404ms 的 XHR `onload` 长处理器及约 409–410ms 帧间隔。prepare 把 cache 查询和排队放到后续 Update 后，仍保留相近的下载完成尖峰。因此，回调中重入 Sound cache 不是这个最小复现的必要条件；本组不能证明延后一帧已消除响应问题。

两个模式各只有一次实际运行，P95 的差异不作为改善结论。XHR 处理器包含响应复制和同步进入 WASM 的完成派发，其总时长不是纯 Lua callback 时长，也不是网络传输耗时。当前结果不识别原生锁所有者、等待对象、具体 native 函数或引擎内部后台活动；不能据此断言某个 cache API、音频解码线程或 native 所有者就是根因。完整回厅、音乐连续性、移动端和生产性能改善仍未由这两个最小实验验收。
