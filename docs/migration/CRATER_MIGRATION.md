# 坠舰陨坑 PC 地图接入

当前加载数据与碰撞分帧优化见 `CRATER_LOADING_SLICES.md`：布局改为元数据+59 个数组片段，同一份源高度与碰撞记录重组后供现有系统使用；取消/失败/重试验证 43/43。3 ms 预算仍有超时峰值，不宣称加载性能全部达标。

最新战斗地表修正见 `CRATER_COMBAT_GROUND.md`：碎片/重力火花改用原 1 米画面高度，负高度与地形边界采样、取消释放均已验证。旧章节的测试数字保留其当时范围。

源：`D:/Rino_Project/Vox/three/terrain-sample.html` 使用的 `buildCraterWorld`。原 H5 目录只读，未改写。目标为当前 VoxelCraft 工程，同一个 main.lua / HangarApp / TrialSession，不是独立演示游戏。

## 进入和操作

运行项目 → 出战 → 选择 **[debug]坠舰陨坑地图测试** → 开始战斗（Enter）。右侧“试车”和快捷键 T 的大厅入口仍进入原试车场。

进图点击画面接管鼠标，移动鼠标转视角；滚轮调镜头远近。Esc 释放鼠标，释放后按住右键仍可拖动视角；再次 Esc 或 T 返回车库。W/S 油门与刹车、A/D 转向、C 切换镜头跟车、N 切换原地图的 9 个探索位置、R 翻正。

相机继续调用引擎 ThirdPersonCamera：默认距离为 `max(24 m, 车体包围半径×3.4)`，缩放范围随车体尺寸调整。保留墙壁碰撞，室内遇到墙体时会自动缩近；不保证狭窄房间内始终保持 24 m。鼠标、滚轮的输入坐标与 PC NanoVG UI 分辨率处理共用当前系统，不增加竖屏/移动适配。

默认俯角为 30°，轮式车辆观察点至少高于底部 3.8 m。相机独立使用实际建筑表面的三角网格避障；相机触发体不参与车辆响应或武器命中。室内缩短镜头时自动扩大 FOV（上限 76°），保留完整车身。2026-10-07 的默认出生点、四方向和室外截图见 PC_HANDOFF.md。

## 场景与代码组织

- `assets/Scenes/Crater.xml`：可直接在编辑器打开的地图，包含原模型、材质、层级、散布实例、太阳、天空和环境光资源引用。StaticModelGroup 的实例 ID 已写入 XML，不依赖进入游戏后才出现。编辑器中“打开场景”选择此文件；动态动画和驾驶从项目运行入口启动。本轮没有操作或重启编辑器。
- `assets/Crater/`：300 个转换模型、98 份材质、六层地形纹理、建筑烘焙图、天空 HDR、碰撞/传送布局和动态节点索引。
- `assets/Shaders/BLGL/Crater/`：SurfaceShader 版本的地形混合/三向投影、建筑面板/烟熏/积沙、岩石、天空、解析高度雾、完整状态护盾、烟柱/尘卷、浮尘与贴地风沙。
- `scripts/scene/Crater.lua`：绑定场景中的 54 个动态部件，更新雷达、环、核心、探照灯、旗帜、呼吸灯等。
- `scripts/drive/CraterWorld.lua`、`CraterPhysics.lua`：原 2 m 高度场、2066 条建筑碰撞记录（跳过 noPhysics）、153 个原散布大石块碰撞球；复用原生车辆和武器系统。
- `scripts/render/CraterEffects.lua`、`CraterDust.lua`：有界烟尘池、4 股尘卷、1600 个浮尘种子、26 条地面风沙。风沙避开烘焙图标记的建筑区域。
- 浮尘已恢复源网页的 GPU 动画方式，静态种子只上传一次，地面风沙仅重新布点时提交几何。12 项验证和三组前景渲染对照通过；CPU/分配测量及边界见 `CRATER_EFFECTS_PERFORMANCE.md`。
- `scripts/app/DriveMaps.lua`：场景、世界模块和资源释放入口注册。地图只在被选择后加载，离开后释放未引用资源；转换中间数据放在 `tools/migration/crater-source/`，不随游戏资源打包。

## 再转换

建筑图导出后，先运行 `pack-crater-bakes.py --apply`，将五张建筑烘焙图打包为无损 RG8 KTX，再运行编译器；原 PNG 保留在转换输入目录，不进入运行包。地面烘焙图保留原 mipmap。

散布材质需保留 normalScale；旧导出可先运行 `restore-crater-scatter.py` 恢复该字段，再运行编译器。模型导出现在自动做完整顶点记录去重及安全的 16 位索引，详见 `CRATER_SCATTER_AND_MODELS.md`。

`node tools/migration/crater-export-server.cjs` 提供只读源服务和写入目标工程的转换端点。打开 `http://127.0.0.1:43187/three/crater-export.html`，点击转换原地图。浏览器执行原地图工厂，导出变换、网格、材质参数、shader 源以及原贴图的 GPU 采样结果。

导出器保存原始基础颜色和动画前姿态。用 `restore-crater-authoring.py --check` 对照原 GLB/材质表；不加 `--check` 可修复旧转换数据的动画污染。先运行 `convert-crater-dfg.py` 转换原光照查找表，再运行 `bake-crater-tonemap.py` 生成 PC 色彩查找表，再依次运行 `compile-crater.py`、`compile-crater-effects.py`、`bake-crater-sky.py`（Python 需要 Pillow / numpy）。编译器会重写生成的 Crater.xml；如果之后在编辑器人工改过该文件，先保留人工版本再比较生成结果。

shader 适配修复包括：局部 tint 参数与材质 uniform 命名冲突、生成器保留名 surfaceNormal 冲突、线性贴图重复 sRGB 解码、建筑烘焙图 mip 串色，以及贴地发光条的深度冲突。早期法线抬升方案已移除：它改变真实遮挡，导致舰内多出宽光条。现用材质深度偏移并保留原几何位置；当前 DX11 同机位对照已验证，详见 `CRATER_VISUAL_PARITY.md`。

## 验证与边界

正式 H5 固定机位对照、点光源强度修正、Bloom 阈值及护盾法线修正见 `CRATER_VISUAL_PARITY.md`。旧 `crater-source-overview.png` 来自转换工具，不包含正式后处理，不能作为最终画面参考。当前对照图为 `evidence/crater-formal-comparison.png`；画面尚未完全一致。

`verify-crater-game.ps1` 检查真实 UI 指针路由选图/进入、相机距离和缩放上下限、游戏 Update 消费鼠标转向、接管/释放、停车/前进、9 个区域落地、动态部件、返回释放及原试车场独立入口。测试通过隔离输入适配器回放，不能等同于已在用户编辑器里手动验证鼠标锁定。

`verify-crater-render.ps1` 在原生 Runtime 真正绘制并截图，也验证场景可以序列化。证据保存在 `docs/migration/evidence/crater-*.png/json`。原试车场驾驶与 PC HUD 使用已有验证脚本回归。最终计数和冷缓存结果见本目录对应 JSON，不以编译成功替代画面检查。

当前 Runtime 为 20260923-1717-bf3316f，尚无文档中的 SkyLightCapture；使用按原天空公式生成的 HDR，经支持的 Zone 环境烘焙提供 SH/IBL。与 H5 的阴影、PBR 响应、护盾亮度仍有差异，尚不能宣称逐像素一致。原太阳光束、Bloom/mist/Grade/ACES/lens 已接入；护盾原有命中波纹、低血量裂纹、溶解/重建表现已恢复；源代码没有护盾伤害规则，未擅自添加战斗伤害绑定。详见 `CRATER_SHIELD_EFFECTS.md`。天空重复位移修复与光束验证见 `CRATER_SUN_SHAFTS.md`。

加载依次经过原生资源下载就绪检查、异步场景载入和分帧碰撞准备。`Crater/Resources.json` 由转换器生成；`ResourceGate` 只请求本地缺失的所选地图资源，使用引擎 `DownloadResources` / `CancelDownloadGroup`，不另建下载器。原大厅在准备期间保持活动，原通知显示进度；Esc 可取消，失败后再次选图重试。代次检查丢弃迟到回调，取消/失败释放候选场景和部分碰撞世界。物理与效果共用同一份解析后的地形布局。

当前验证使用本地资源，下载回调边界使用可控后端回放；未验证实际远端传输、弱网或续传。当前粒度是整张所选地图，尚无按地理区域边走边加载，也没有任意 Lua 状态热迁移。编辑器交互稳定性、其他图形后端和真实设备持续性能未在本次证明。


## 当前验证（2026-10-06）

当前地图流程 **58/58**、画质 **45/45**，两次连续隔离开发缓存复测通过，零运行错误、零新增 shader 编译文件。修复了 RenderSurface 借用对象晚于父纹理释放引起的原生异常；不是通过禁用 GC 或保留旧地图规避。证据和生命周期规则见 `RENDER_TARGET_LIFETIME.md`。该阶段的缓存计数为 488；后续护盾和光照修正后的当前包为 520 文件、3,983,276 字节。

PC 后处理覆盖原太阳光束、高光钳制、五级 Bloom、mist、Grade/Three ACES 与镜头效果。七组实际 H5 Pipeline 测试图全图 RGB 最大误差 1/255；这不代表整图材质/光照一致。天空 alpha/HDR 4/4、光束实际开关 8/8、动画/材质/正式机位 233/233。动态分辨率 70% 时颜色缓冲从 106.44 降至 52.16 MiB，PC GUI 保持原尺寸。

已查看模式选择、基地出生、驾驶、东洼地、舰体大厅和 H5 并排截图。整体仍有 PBR、阴影、护盾和朝阳天空输入差异，尚未达到“完美复刻”。护盾战斗规则绑定、远端弱网/续传、地理分区流式加载和真实设备持续性能仍待完成。当前测试回放输入，不冒充用户编辑器中的手动鼠标验收。

历史阶段报告保留在 evidence；最新状态以本节和 `RENDER_TARGET_LIFETIME.md` 为准。资源下载/取消与分帧准备的既有验证为 23/23，原试车场 34/34、PC 驾驶 HUD 127/127；这些是此前阶段的结果，本次未全部重跑。

最新烘焙阴影通道修正见 `CRATER_DIRECT_LIGHT.md`。已消除将直射阴影错误乘入底色导致的崖壁发黑；真实地图间接光隔离像素检查通过，更新三处正式机位及九种护盾状态截图。当前 shader 下隔离开发缓存复测：大厅 3/3、画质 45/45、地图 58/58，零错误、零新增编译。护盾 50/50、正式机位 233/233、天空 4/4。

后续散布法线遗漏已修复，300 个模型无损减少约 7.37 MiB。最新正式机位标签 `scatternormal`，233/233；散布材质渲染 12/12、切线公式 240 组通过。当前 shader 包为 519 文件、3,976,571 字节，冷缓存大厅/画质/地图再次通过。细节及尚未通过的天空资源完全卸载检查见 `CRATER_SCATTER_AND_MODELS.md`。

后续天空驻留问题已定位并修复，场景切换现在等待环境光照就绪。建筑烘焙图无损转换为双通道 KTX，三处固定机位全图像素差为 0，纹理有效载荷减少约 96.67 MiB（不是总显存实测值；未打包文件反而增加约 19.70 MiB）。最新资源生命周期、测试入口与限制见 `CRATER_RESOURCE_RESIDENCY.md`。

最新画面修正：旋转探照灯外壳的斜率深度偏移会穿透舰壁，现只修正这一份独占材质，保留地坪及灯带偏移。五机位渲染 26/26、正式对照 233/233、地图操作 58/58 复测通过，零运行错误。当前正式截图标签为 `surface-depth`，细节见 `CRATER_SURFACE_DEPTH.md`。
