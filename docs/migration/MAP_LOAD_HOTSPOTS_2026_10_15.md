# 地图加载热点复核（只读）

## 当前证据

复核 `evidence/combat-performance-2026-10-15T13-35-59-350Z` 的实际 04a23389 Web 20:9 运行、console、rAF 与 CPU profile；不是新 706d 的性能结果，也不是手机实测。当前实际层图均为 1024×1024 RGBA PNG 字节 `.bin`。旧调研里的 2048/256 MB 不再代表当前数组。

| 记录项 | 实际值 | 归因边界 |
| --- | ---: | --- |
| 下载阶段 | 39.663 s | 阶段墙钟，包含准备查询，不等于纯网络传输 |
| 两个数组准备 | 1.756 s | SceneLoader 一次同步 GetResource 处理一整个 6 层数组，中间已等 3 帧 |
| 场景异步加载 | 7.703 s | asyncLoadingMs=3 不会中断单个原生资源解码/组件加载 |
| prepare 阶段 | 37.914 s | 包括物理与实际会话准备，不能全部算碰撞构建 |
| activate 阶段 | 24.359 s | 包含实际渲染暖机，不等于单个 Lua 构造器 |
| 两个数组 memoryUse | 67,109,584 B | 每组 33,554,792 B，约 32 MiB（含 mip） |
| 最长 rAF | 15,617.825 ms | 在 prepare，非数组阶段 |

最长断档附近的引擎 console 状态为 `21:38:18.353 → 21:38:34.321`，仍是 prepare。数组在 `21:37:53.428/21:37:54.328` 已准备结束，因此不能把约 15.6 秒冻结归给数组上传。

整个 match-load CPU 采样中 `getProgramParameter` 自采样约 7,608.254 ms、`getShaderParameter` 279.294 ms；`texSubImage3D` 17.616 ms、`texImage2D` 58.655 ms。无符号 WASM 栈只能区分 GL 等待与匿名内部调用，采样不是每个 GL 调用的精确墙钟，也不能说明 PNG 解码免费。加载 profile 相对 76–93 秒区间内，`getProgramParameter` 约 4,229.244 ms；时间靠近上述 prepare 长冻结。单纯把 Lua 外层套协程无法中断驱动链接。

## 精确候选与顺序

1. **先量本批烘焙底图**：旧 MatchMapShot 在 prepare 尾部用 1200 米相机实际画全图 5 个视图，临时放开所有 drawDistance，会触及驾驶视野未用的材质和 shader 变体。新离线底图去掉这一整套实时捕获与逐像素调色，优先确认 baked 命中、最长帧及阶段变化。仍未能用旧 profile 唯一证明 15.6 秒全由 MapShot 引起，必须看新包实证。
2. **保留数组原图，先补每数组的实际耗时**：`SceneLoader.lua:142` 的同步 GetResource 无法在 6 层中间 yield。当前已每数组分帧，不应再添加空等待帧称作分帧上传。引擎 API 有 `Texture2DArray:SetData(layer,image)`，但当前绑定未见将手建对象加入 ResourceCache 的 `AddManualResource`；仅创建私有数组不会替换场景 XML 自动加载的同名数组，会形成双份分配。暂不改这条生产路径。
3. **异步 scene 的资源粒度预备**：当前 Web `LOAD_SCENE` 已避免等待后台资源线程，asyncLoadingMs=3 只能在节点之间退回主循环。可在资源阶段预备 `mesh-280.bin`（10,569,956 B）和 `mesh-279.bin`（8,317,356 B），一帧一个，验证是否减少 scene 内多次资源连读。单个大模型加载仍可能超过 100 ms，不能承诺该改动完全消除冻结。拆网格/离线碰撞才可缩小不可抢占单次工作，但应另有画面与碰撞等价验收。
4. **驾驶暖机的剩余编译**：新底图不再为全地图预编译，因此后续驾驶转向到未见区域仍可能首编。应在加载页按现有 SceneWarmup 逐批原 drawable 暖机；不能一次用全图俯视截图替代，因为该操作会重新引入长帧。Shader 预缓存的 Web 支持仍需实际引擎接口验证。

## 独立兼容项

`app.ResourceGate` 对旧 Web 的 `cache.DownloadResources` 缺失已有降级分支；MapShot 当前直接调用该方法。代码中存在兼容分支不证明本次引擎必定缺 API。root 已固定新 706d 并进入真实 Web，等该运行的实际接口/错误结论后再决定是否复用可选 ResourceGate；当前不改生产，避免未验证地重复烘焙。

若确认缺少，修法应为 MapShot 持有自己的 Gate（成功/失败均可继续）、超时/Dispose 中 Cancel；旧 manager 轮询由现有主循环处理。不得仅把缺接口路径直接退 capture 后称烘焙优化有效。修改 MapShot 会改变烘焙输入 checksum，必须重烘焙和重新固定统一包。

## 本轮没有做的事情

没有改图片尺寸、过滤、光照、贴图格式、碰撞、场景或构建；没有启动第二个浏览器/native。现有测量不支持将数组认定为最长冻结根因。新包验证与是否继续分层上传由 root 在统一运行窗口完成。
