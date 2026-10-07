# Web 渲染与地图首次加载修复（2026-10-07）

## 点击无法恢复驾驶：异步 Pointer Lock

Web 点击后 `input.mouseMode=MM_RELATIVE` 的浏览器确认在后续帧到达。旧 `DrivePointer` 立即设置 `captured=true`，下一帧仍读到旧的 `MM_ABSOLUTE`，因此执行 Release；稍后浏览器已经锁定，游戏仍为暂停状态。实际点击日志记录了这组相反的状态，并非按钮未收到点击。

修复：Web 使用独立 pending 状态，等 `MM_RELATIVE` 和 `mouseLocked` 同时确认再启用驾驶；等待期间输入保持中立，拒绝/超时后允许重新点击，失焦/退出清理待处理状态。原生和触控保留原有入口；恢复点击仍需松开后才能射击。

23:37 本地官方 Web 1.32.34 + prepare `manifest-f2ef1808` 通过 Chrome 硬件 WebGL 实际鼠标/键盘测试：试车场与陨坑各 9 项断言，包括一次点击锁定、遮罩消失、进入点击不射击、移动鼠标转镜头、按 W 驾驶、Esc 暂停/点击恢复、浏览器解除锁定暂停、T 返回并释放光标。共 18 项通过，无 Lua/资源/shader 错误。测试只自动选择地图和读取状态，不覆盖驾驶控制器；证据在 `evidence/web-pointer-*`。远端预览更新情况以构建返回和实际远端日志为准。

## 21:57 远端复发：CPU 图片被远端重新压缩

`ed7f4d4` 的本地 prepare 包通过 Web 测试，但远端进入陨坑仍报 KTX unsupported，随后在 `CraterDust.lua:16` 读取地面遮蔽图时断言失败。先前的本地 Web 验证不等同于远端纹理烘焙产物验收。

原因：远端构建对 PNG 执行平台纹理烘焙，Web 默认 ASTC。`Texture2D` 可直接上传压缩块，但 `Image:GetPixel` 及 `Texture2DArray` 的逐层 Image 读取路径需要 CPU 可解码像素。源 PNG 扩展名不能保证发布内容仍然是 PNG。

修复：12 张地形数组层和地面遮蔽图（texture-0）以 `.bin` 扩展名存储原始 PNG 字节，保留资源 UUID，调整数组、材质、元数据及下载清单的引用。作为非纹理构建输入跳过 GPU 压缩，仍由引擎根据 PNG 文件头解码。没有复制两份像素或降分辨率，仍按进入陨坑时下载。地面像素解码另有明确断言；包检查逐字节验证这 13 项不含平台压缩变体。

后续验收必须分别记录：本地 Web 包的像素/数组层数/往返结果、远端构建成功、远端实际再次进入的日志。不能仅凭远端大厅启动没有 ERROR 就称陨坑远端验收通过。

### 重入时的 WASM 内存峰值

修复图片格式后，首次进入通过，但第二次进入曾在场景读入阶段 `Aborted(OOM)`。返回后缓存中的陨坑数组已降到 0，再做 GC 和非强制缓存清理仍可复现，因此不是简单的地图缓存未释放。当前 Web Runtime 使用固定约 1.6 GiB 堆；两组 2048×2048×6 纹理数组含 mip 共 256 MiB，连续解码和 GPU 上传暂存会额外产生峰值。

`DriveMaps.crater.webWarmup` 声明两组数组；`SceneLoader` 在下载完成后分别预加载，每组后让渲染器经过三帧，再开始加载场景材质。仅 Web 采用该阶段，保留全分辨率、mip、按需下载和失败时保留大厅的行为。取消时沿用现有延后释放路径。实验中此调度已通过两次进出，而只追加 GC/缓存清理仍溢出；正式代码另做连续三次进出和纹理准备期间取消测试。

22:29 正式 prepare 产物 `manifest-1ebc3b0b` 在官方 Web 1.32.34、Chrome 硬件 WebGL 中通过三次陨坑→大厅往返及准备纹理时取消。每次检查 6 个地面采样点及两组 6 层、2048×2048 数组，返回后数组缓存为 0，CPU 地面 Image 已释放。测试没有覆盖/替换加载器，也没有额外 GC 或手动清缓存。日志无资源/Lua/shader/OOM 错误；存在原有 Panel 布局溢出提示。证据：`evidence/web-cpu-final-result.json`、同名前缀日志/截图。此项仅证明本地 prepare 的 Web 运行结果，远端构建后的验收另记。

## 大厅泛白

同一 Web WASM 引擎，松散资源加载正常、Maker 发布清单加载异常。逐项关闭灯光确认矩形灯产生大面积白斑；曝光、材质参数读取值无误。

引擎内置 `Textures/LTC/LTC_Combined.dds` 是 64×128 RGBA16F（DDS FourCC 113，65,664 字节）。Web 远端 engine-res 同名资源是 5,509 字节的 ASTC KTX，无法保留原表的浮点数值。实际 Web 纹理格式从 5 恢复为 66 后，白地板和表面斑点消失；灯光和曝光未调整。

`Rendering/RectLightLUT.bin` 保留引擎内置表原始字节，作为非图片资源避免再次被纹理烘焙。启动时 `render.RectLightLookup` 通过 VectorBuffer 加载到 renderer 已持有的同一 Texture2D。仅 Web 执行，不修改引擎目录或内置库。上游修正数据纹理的发布处理后可移除此兼容模块。

## 首次切图

- 试车场缺少显式资源下载清单，场景后台加载先于 37 张纹理到达；新增 `Track/Resources.json`，进图前下载，保持按需加载。
- 陨坑 RG8 KTX 在当前 Web 解码器报 unsupported format；五张烘焙图改为 RGB PNG，R/G 逐字节一致、不缩小尺寸，单 mip 配置保留。原生 RG8 的显存节省结论不再适用于此版本。
- 纹理设置 XML 不作为独立下载项，仍留在包内由纹理加载器使用。
- WASM 不支持等待后台资源结束，原 `LOAD_SCENE_AND_RESOURCES` 会跳过等待并出现并行解码内存峰值。Web 使用 `LOAD_SCENE` 分帧创建节点，顺序解析已下载资源；原生仍使用后台资源加载。
- 陨坑光照 include 的局部变量 `packed` 是 Web GLSL 保留字，改成 `dfgSample`；直接光可见度使用引擎文档支持的 BACKLIGHT 在 fragment/light 间传递，能量补偿在 light 内计算，不能写入 WebGL 只读顶点插值输入。计算不变。

## 验证

本地测试使用 Maker 实际 Web 1.32.34 WASM 和官方 prepare 生成的资源包，由全新 Chromium 会话从清单下载。测试挂钩仅由本地 HTTP 服务追加，不写入游戏入口或发布包。截图和完整日志在忽略的 `docs/migration/evidence/`。

发布包检查涵盖 Lua 完整性、启动依赖、LTC 字节不变、两张地图下载清单及实际材质纹理依赖。浏览器渲染与原生加载回归分别执行；无真实移动设备性能结论。

已完成：正式启动流程的大​​厅→试车场→大厅 Web 截图/日志检查，无 Lua、资源、shader 错误。原生加载回归 43/43 断言通过，但启动环境缺少 themis_x64.dll 导致报告总体 FAIL，不能标记原生全通过。

陨坑最终 Web 发布包已完成进入、shader 编译和返回大厅，日志无 Lua/资源/shader 错误；最终画面另用硬件 WebGL 检查。软件渲染测试的耗时不作为真实设备帧率结论。
