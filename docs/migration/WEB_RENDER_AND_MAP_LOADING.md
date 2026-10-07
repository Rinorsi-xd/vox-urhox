# Web 渲染与地图首次加载修复（2026-10-07）

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
