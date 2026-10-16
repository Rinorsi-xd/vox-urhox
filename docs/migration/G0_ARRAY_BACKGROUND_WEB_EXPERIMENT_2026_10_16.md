# 地形数组后台准备：实际 Web 实验与生产候选 A

## 结论与交付边界

不重开 G0；继续固定 H5 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`。本次只处理已定位的地形数组同步准备长帧，不改视觉资源、材质、着色器预热覆盖或全局缓存参数。

独立 Web 实验支持将 SceneLoader 的两个同步数组准备调用改为后台排队并轮询。原直接调用分别阻塞 701/743 ms，后台队列调用分别为 1/0 ms，两张原数组实际完成且原材质引用相同缓存对象。实验并没有缩短数组总完成时间，不能代替整场加载、声音连续性或移动设备验收。

生产候选 A 已落到 `scripts/app/SceneLoader.lua`，SHA256 `6439e69cd81d854a6e5f1064c40b4524e9d25c42382f50bb969ab322d82b2aff`。CPU 契约回归通过，尚未用包含此 SHA 的构建实际进入第三关，不签生产性能改善。

## 两次原始实测

root 串行运行，均使用冻结 `manifest-80e98fd5.json` 的相同 18 个资源 payload。独立 HTTP main 覆盖没有修改生产入口。1600×900、Chrome headless、ANGLE D3D11，运行时报告 `graphics.apiName=GLES`。每个模式只有一轮，不能推算受控 A/B 百分比。

| 项目 | background | synchronous |
| --- | ---: | ---: |
| albedo queue 调用 | 1 ms | 701 ms |
| albedo queue→ready | 723 ms | 733 ms |
| nra queue 调用 | 0 ms | 743 ms |
| nra queue→ready | 721 ms | 752 ms |
| 原材质构造及引用检查 | 185 ms | 194 ms |
| EndFrame 事件间隔样本数 | 94 | 9 |
| 原始最大间隔 | 349 ms | 1320 ms |
| 原始 P95 | 17 ms | 1320 ms |
| 原检查器 responsiveness | FAIL | FAIL |
| 实际资源及清理检查 | PASS | PASS |

两模式均为 1024×1024、6 层、11 级 mip，每张 `memoryUse=33554792`，格式枚举 59；材质 `tAlb`、`tNra` 引用原数组缓存对象。结束时后台资源数 0，清理后两个数组缓存引用均不存在。此场景没有绘制地图，格式、绑定与内存一致不能替代像素验证。

### 349 ms 首样本的具体边界

探针在 EndFrame 时读取当下 phase，记录从上一 EndFrame 至今的区间，未在 download→queue 时重置 lastFrame。background 首条记录：

- EndFrame `wall=1116337322`，`ms=349`，区间起点 `1116336973`。
- 首次 queueWall `1116337321`，queueMs 1。
- 因此该区间有 348 ms 在首次数组排队之前；不能将 349 ms 归为数组后台最终提交。
- 第一个数组 readyWall `1116338044`；包住该完成点的 EndFrame 区间是 `1116338019→1116338077`，58 ms。
- 第二个数组 readyWall `1116338823`；包住该完成点的区间是 `1116338803→1116338837`，34 ms。
- 首个跨 download 边界样本以外的最大区间是 207 ms，phase=finish，包含 185 ms 的材质步骤。只作阶段归因，不更改原始 FAIL 或删除样本伪装通过。

synchronous 首个 1320 ms 区间 `1116592482→1116593802` 也跨下载边界，queueWall `1116593070`；但直接 GetResource 的 701 ms 和第二次的 743 ms 有独立函数计时，足以证明同步阻塞。第二次 EndFrame 间隔为 768 ms。

完整浏览器 RAF 包含引擎启动和下载：两模式最大均约 1434 ms。background 最后一个接近首数组队列前的 long task 为 346 ms，但探针没有输出 browser performance.now 与引擎 wall 的共同锚点，不能逐毫秒映射或据此认定 348 ms 的内部 decode/文件处理归属。后者仍 OPEN；不作线程归属、解码/上传内部耗时分拆或全启动不卡结论。

## 候选 A 的生产行为

- 仅 Web 已配置 webWarmup 的阶段走新路径；原 native LoadAsyncXML 模式不变。
- 逐一 GetExistingResource；尚未完整准备时仅调用一次 BackgroundLoadResource，再由后续 Update 轮询。
- BackgroundLoadResource 返回 false 可能是已由其他所有者排队，不立即同步 fallback；统一等待缓存实际 ready。
- Texture2DArray 要求 width、height 均正；按实际 ready 才推进进度。
- 每个 pending 记录 generation 和墙钟，超过 20 秒走现有 Fail→Cancel→cleanup；dt=0 仍可超时。
- Cancel 清除 pending token；晚到的共享缓存完成不会触发回调、复活旧场景或推进旧任务。
- 保留每张数组完成后的原 warmWait=3 阶段屏障、场景加载页的两次呈现门禁及所有后续暖机。
- 不调用没有证据的 native 后台取消 API，不强制释放可能被别的场景使用的共享缓存；原生已经开始的队列不能据此宣称被取消。真实中途取消后的缓存退役与重入仍需同包验证。

## 已运行检查

`check-loader-background-arrays.py` 实际执行生产 Lua 5.4，受控 cache/wall：57 项通过；阻塞 fallback、重复排队、关闭墙钟超时、关闭 generation 门禁四个负控均被拒绝。覆盖冷/热缓存、false 队列返回、未完成缓存对象、逐张顺序、三次屏障、20 秒超时、单次失败回调、取消、旧 token、inspect/queue 异常及重试。没有引擎/GPU 性能结论。

关联 CPU 回归实际重跑：

| 检查 | 结果 |
| --- | --- |
| verify-scene-loader-single-parse.py | 132 项 PASS，20 场景 |
| check-web-map-transition.py | 124 项 PASS |
| check-opening-prefetch.py | 184 项 PASS |
| check-opening-budget-staging.py | 89 项 PASS，2 负控 |

single-parse 的原生 cache double 新增 GetExistingResource，明确模拟已准备完毕的原 1024 数组；不是调用真实后台加载。新专用 57 项检查覆盖未准备的真实生产分支。

`check-loader-progress.lua` 等原生检查本轮没有运行：root 独占所有 GPU/native；旧 native 证据不能签新 SHA。尤其其连续 16 次同步 Update 的 320 秒模拟循环不是后台准备调度测试，若资源为冷缓存需先明确预备缓存或将其改为跨帧调度，不能借同步循环断言后台线程必已完成。

## 下一次必须完成的验收

root 同包构建后实际第三关进场→正常退场，读取 resources 的 loader.Update/EndFrame，确认原 651/715 ms 两次数组同步帧不再出现；保留真实 download 边界长帧记录。核对原 331 个 shader 集没有缺失、原材质像素正常、退出后 arrayBytes=0；中途取消→重试不得停住或错用旧 generation。此项通过也不关闭约 85 秒总加载、首关长路线 OOM、全剧情、声音连续性和真机性能。

## 证据身份

- background：`evidence/array-preparation-background-2026-10-16T02-27-47-645Z/result.json`，SHA256 `ecc2a4475ce775c5161b9e011db08e374388bab0b55faffcc980bdfcd00f46ba`；runtime.log `31b9b2f40645e5b731c6c5a717288b1f253120390f3b5575238a9ce59a5dd7e4`。
- synchronous：`evidence/array-preparation-synchronous-2026-10-16T02-32-05-046Z/result.json`，SHA256 `62df6ecbc8f64d576c6449340b55ebfb58a47b6bde1c4881515abfb93bd7c508`；runtime.log `6205706a96945fb2dc6b356a24da37ec1eba856d6865a010eadd80f7a47a16e7`。
- 两次 probe SHA256 `9ed623fb5601a7e2cc941e76c92fcc34e01f8c229db7f4fc408dc9b868cc89f1`；manifest SHA256 `fff4045a9a5e4a7627eae024ed0d6578bb35d4a1c40e0b12a74fb78ea4ce414e`。
- 候选 CPU 证据 `evidence/loader-background-arrays-offline.json`；输入/生产哈希均在报告内。

本次未启动服务器、浏览器、native 或构建，未修改共享 probe、CURRENT_EXECUTION，未提交或上传。
