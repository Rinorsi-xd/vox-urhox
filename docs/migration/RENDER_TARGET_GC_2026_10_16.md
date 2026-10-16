# 渲染目标后台 GC 修复

本批接续 `manifest-3ba43bd8` 开篇连续性 FAIL，不重开 G0，不改演出、音效或视觉效果，不启动 GPU。

## 已确认的问题与修改

`RenderTargetLifetime.Update` 原来只要 pending 还有外借的 RenderSurface，就每 3 帧调用 `Flush`，每次强制 `collectgarbage('collect')`。即使外借对象一直存活、没有任何纹理可释放，也重复扫完整 Lua 堆。真实旧模块的控制夹具中，60 帧产生 **20 次 full collect**。

现在后台仍每 3 帧工作，但只请求 `collectgarbage('step',128)`；只有返回完整 cycle 结束时，才扫描弱表并释放已终结的 surface 对应父纹理。128 是 GC 工作请求量，不是毫秒上限，不能称为严格每帧耗时保证。

`Flush` 保留同步完整回收与释放语义。`HangarApp.ReleaseSettledAssets` 仅开场增量退场分支不再调用同步 Flush，交给既有每帧 Update 继续处理。普通地图切换、停止等显式 Flush 入口仍保留。

## 安全性依据

Lua 5.4 实测：160 个 surface 模型对象的弱值在其 `__gc` 入口已为空。因此 **weak=nil 本身不是可以释放父纹理的依据**。本实现只在 collector 报告 cycle 完成后释放；测试中的每一次父纹理 Dispose 都检查 surface finalizer 已执行结束，终结器内检查父纹理尚未释放。

pending 表强持父 Texture userdata，外借 surface 只放弱值；外借仍在时即使完整 Flush 也保留父纹理。主要调用方 FilterGraph、ReflectionFilter、SourceLayer、MatchMapShot、HangarBuffers、HangarPreview 均通过 `Texture2D:new()` 创建自有目标，并非 cache 中的贴图资源；本批不调用其显式 Dispose，后续 `ReleaseAllResources(false)` 和环境烘焙缓存清理也未遍历此 pending 表。原生 RenderSurface userdata 和 GPU 释放顺序还须实际引擎验收，Lua 表模型测试不能替代它。

Lua generational 模式的 minor step 可能一直返回 false；在该模式本实现保守保留 pending，直到显式 Flush。测试 600 帧已真实观察到这一行为。项目没有主动切换到 generational，Lua 5.4 默认 incremental；本批不擅自改变全局 GC 模式。若以后更改模式，必须重新验收后台内存回落，不能沿用本批增量模式的释放速度。

## 实际检查

- `check-render-target-retirement.py`：**829 PASS**，执行当前生产模块及真实 Lupa Lua 5.4 collector。旧模块 60 帧 20 full / 0 step，新模块 0 full / 20 step；80 外借目标均保留，放弃其中 79 个后 incremental 模式 3 帧回落到 1 个；最后一个外借释放后显式 Flush 清零。还覆盖重复退役、无 surface 立即释放、nil weak 但 cycle 尚未确认时继续保护。
- `check-intro-runtime.py`：**423 PASS**，包含实际 App 增量开场分支跳过 Flush、普通分支仍 Flush、Stop 的原同步边界及原开场生命周期断言。未降低旧检查。
- 证据：`evidence/render-target-retirement-offline.json`、`evidence/intro-runtime-offline.json`。

最终生产 SHA256：

- `scripts/render/RenderTargetLifetime.lua`：`305d9583c3b4ef5f01adae2457f33939cf32de740b53bc28f1d78de29fe24485`。
- `scripts/app/HangarApp.lua`：`b0c484e3281a886dbaf5d569eae06d18924ff1a9a81f187321836f88314e5863`。

生产已冻结交 root 统一构建与串行 Web 验收。尚未证明最大 1473 ms 音频间隔消失，尚未测定节省毫秒数、原生 UAF、峰值内存或真机帧率；3ba 原连续性 FAIL 全部保留。
