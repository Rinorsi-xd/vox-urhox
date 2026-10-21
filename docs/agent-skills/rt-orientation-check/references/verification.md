# 验证与回归

## 一、自检场景

`project-files/scripts/render/OrientationSelfTest.lua` 复制到项目后：

```lua
local SelfTest=require 'render.OrientationSelfTest'
SelfTest.Start()   -- 接管 viewport 0，绘制 3 行 × 2 列格子
-- ... 观察完 ...
SelfTest.Stop()
```

屏幕布局（两列分别是"裸显示"和"纠正后"）：

| 行 | 路径 | RAW（裸） | FIXED（纠正后） | 判定位 |
|----|------|-----------|-----------------|--------|
| 1 | B 相机 RT 被 shader 采样 | 可能倒 | **必须正** | sentinel `sampled` |
| 2 | C NanoVG RT 被 shader 采样 | 可能倒 | **必须正** | 方向图左列 `nvgSampled` |
| 3 | D 相机 RT 快照 → OrientedCopy → NanoVG | 可能倒 | **必须正** | `sampled XOR shown` |
| 4 | A 相机 RT → 内容 shader 按 `shown` 翻 → NanoVG | 可能倒 | **必须正** | `shown` |

**合格标准**：所有 FIXED 格显示「上部红、下部蓝、左上角绿点」。绿点同时能暴露左右镜像问题。

RAW 格显示的是本设备当前的怪癖，记录下来即可（例如"这台手机 sampled=1, shown=0"），**不要**据此写平台判断。

第 4 行模拟了完整的路径 A：内容 shader 在相机 RT 内按 `shown` 翻 UV，再把该 RT 经 `nvgCreateVideo` 显示；若这一行通过，说明"在内容 shader 内纠正"的链路成立。如果自检通过但业务画面不过，说明业务内容链路与自检链路有差异（见下方排障）。

## 二、平台矩阵

每次新增 RT 路径或升级 runtime，至少覆盖：

- [ ] 桌面原生（Windows / macOS）
- [ ] 桌面 WebGL
- [ ] 桌面 WebGPU
- [ ] Android WebGL（至少两款 GPU 不同的手机）
- [ ] Android WebGPU
- [ ] iOS Safari（WebGL / 如支持 WebGPU）
- [ ] 有 NanoVG 软渲染 / 低端机兜底路径时也测

本项目历史观察：桌面原生通常 0/0/0；桌面 WebGPU 与手机 WebGPU、两款手机 WebGL 曾分别出现不同组合。**这张表只用于判断"是否需要更多测试设备"，不用于写代码分支。**

## 三、runtime 升级后的回归（关键）

升级 runtime / 引擎后按顺序做：

1. 全量搜索残留的写死补偿：
   ```bash
   grep -rn "apiName\|WebGPU\|浏览器\|platform" scripts | grep -i "flip\|orient\|uv\|y"
   ```
   一旦发现按平台分支的翻转逻辑，删除它——现场测量已经覆盖。
2. 跑一遍自检场景（上面平台矩阵）。
3. 观察日志：
   - `[OrientationMap] orientation map ready api=...` 出现一次
   - 无 `[OrientationMap] unavailable ...`
   - 无 `[OrientationMap] sentinel unavailable ...`
   - 无 `[OrientedCopy] orientation map never painted`
4. 若日志出现上述失败，说明新 runtime 改了 NanoVG 渲染目标或 `nvgCreateVideo` 的行为，导致检测链路本身建立不了。此时画面会退化为"不翻"（不会错误翻转），按下面"排障"定位 API 变化。

**为什么这套机制能在 runtime 改动后自动正确**：所有判定位都是"现场测量值"，每次显示/拷贝时从 GPU 重新读；runtime 加了或去掉了翻转，测量值随之变化，消费方 shader 自动跟随，无需改代码。

## 四、排障

| 现象 | 可能原因 | 处理 |
|------|---------|------|
| 所有 FIXED 格都倒，RAW 也倒 | 测量链路与内容链路不同（标记没画在真实 texel、被 AA 吃、用了不同 RT） | 检查标记是否在 `nvgResetTransform` 后按 texel 画；检查 `DrawCorner` 是否用 `nvgImagePattern`（而非直接画色块） |
| FIXED 格方向对，但业务画面倒 | 业务内容 shader 没有用 `orient_*_flip()`；或用了两次 | `grep` 业务 shader 里是否还有手写 `1.0-UV.y` 类补偿 |
| 偶尔闪一下倒 | 方向图还没画好就开始采样，且兜底是"不翻" | 静态上传类（路径 C1）用 `Settle(startFrame)`；拷贝类（路径 D）已内建等待 |
| 方向图一直是透明 | `nvgCreate` / `nvgSetRenderTarget` 失败，或 `NanoVGRender` 没触发 | 看 `OrientationMap` 日志；确认 `LuaScriptObject` 可用 |
| sentinel 一直不就绪 | 渲染路径 XML 或 `OrientSentinel.shader` 加载失败 | 检查 shader 路径、`SetSurfaceShader` 返回值；检查 `SURFACE_MANUALUPDATE` + `QueueUpdate` |
| WebGPU 下什么都不翻且无报错 | 检测资源创建成功但方向图从未绘制 | 确认 `Request()` 在每帧被调用（`Update` 或显示循环） |
| 双重翻转（纠正后反而倒） | 旧补偿没删；或路径 A 同时用了 OrientedCopy | 删旧补偿；路径 A 只在内容 shader 翻一次 |

## 五、交付前检查清单

- [ ] 没有 `apiName` / 平台 / UA 分支参与翻转决策
- [ ] 没有 CPU 像素读回（`GetImage` / `ReadPixels` / 截图比较）
- [ ] 每处 `nvgCreateVideo` 显示的相机 RT 都归入路径 A 或 D
- [ ] 每处 `SetSurfaceTexture` 采样 RT 的都归入 B 或 C
- [ ] 方向图 / 哨兵的兜底都是"不翻"（全透明纹理）
- [ ] 静态结果用完即释放场景、材质、viewports（无每帧泄漏）
- [ ] 自检场景在所有目标平台通过
- [ ] 日志无 `unavailable` / `never painted`
