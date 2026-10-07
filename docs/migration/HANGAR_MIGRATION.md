# 轨道改装机库迁移记录

初次迁移：2026-10-05；动态画布更新：2026-10-06。源工程 `D:\Rino_Project\Vox`，目标工程 `D:\Rino_Project\maker\Vox\VoxelCraft`。当前优先 PC 横屏；移动与竖屏暂停。

## PC 甲板与反射修正（2026-10-06）

原 H5 `deckShader` 在合成 PBR 和平面反射后将地砖缝压暗；旧移植只改 ALBEDO，强高光区域的缝因此消失。Deck.shader 现在通过 AO、AO_LIGHT_AFFECT 和独立 EMISSION 衰减覆盖直接光、环境与平面反射，并在其后绘制原版网格/边框/亮环/扫描线。保留源强度 0.28、粗糙度 0.38、blur 4、distort .003；不靠任意减弱反射掩盖缝隙。此为当前 SurfaceShader 接口的映射，并非 Three.js outgoingLight 的逐通道等价；原生镜面 AO、清漆、环境强度与后处理仍有差异。

反射不再使用 FRAGCOORD 除窗口尺寸，改用每次捕获的反射相机投影矩阵。1920×1080 游戏视口生成 960×540；带偏移的 1440×900 视口生成 720×450；宽高比取实际 viewport，近远裁剪跟随主相机。编辑器嵌入渲染目标的像素预算仍需编辑器实测，当前只确认独立 PC Runtime。

直接启用原生 RT mip 链实测分配成功但低层全黑；默认完整渲染流程用于过滤还会重复曝光/色调映射。正式实现使用 ReflectionFilter：独立两命令 clear/base 流程，三个 HDR 目标直接读取同一原始反射，固定 1/4/16 个双线性采样对应 2×2/4×4/8×8 box filter。按源 LOD 1.52、2.12、2.52 做线性混合。没有 GPU→CPU 读回或运行时图片生成，三次过滤绘制只随反射刷新，未改变原有 PC 30Hz/尺寸上限。960×540 下三个目标约 1.30 MiB，源反射约 3.96 MiB；不含深度、驱动、视口等开销，不作为骁龙 845 性能结论。

各过滤目标独立读原始捕获，避开已实测会跨帧滞后的多级串联。动态整数循环在当前 DX11 验证中停住，已删除，改为固定展开采样；该结论限于此实现/后端。纹理缩放时先成功创建再换绑，失败保留旧资源；新模块持有过滤 Scene，关闭/重载显式释放全部材质、纹理、场景。main 的逐帧资源所有权不变。

最终 `verify-hangar-reflection.ps1` 17/17、`verify-home-camera.ps1` 902/902 通过，零 Lua/资源/引擎运行期错误。GPU 取证比较锐图与模糊图、确认模糊图非黑；三个世界点的反射投影误差为 0；恒定 (0.25,0.5,0.75) 经三个独立层读回均约 (0.2471,0.4980,0.7490)，在输入/读回量化容差内。覆盖 PC 两种比例与偏移视口、重载释放。未证明快速运动时的逐帧捕获/过滤顺序完全一致，后续需同步多帧验证。

最新 `evidence/pc-home-camera-comparison.png` 左 H5、右当前原生；`pc-deck-before.png` 保留修改前实际画面，`reflection-mip0.png` / `reflection-mip3.png` 为过滤验收输出。地砖已恢复，正文、灯光、天空、阴影、地面反射强度/模糊和全屏后处理仍可见不同；环境动画时间未同步。尚未验收完整大厅复刻。

本轮将当前 **Three.js 主线的轨道改装机库** 接入正式场景 `assets/Scenes/OrbitalHangar.xml`，`scripts/main.lua` 与编辑器 Play 共用 `HangarApp`。没有使用旧 Babylon 车库，也没有改写源工程。运行时为原生 Lua、Model、Material 和 SurfaceShader，无浏览器嵌入依赖。

## 动态反射补充检查（2026-10-06，修正前诊断）

换车升降验证后，新增 `verify-reflection-refresh.ps1`，直接读取正式 `h.reflTex`，不另外创建探针渲染场景。最终结果 **4/5，FAIL**：地上洋红标记可见 891 像素；隐藏标记后，手动刷新与持续刷新均为 0 像素，确认正式反射能够更新。将标记放到地板下方，启用与关闭 `Camera.useClipping` 均得到 6131 像素，地下裁剪断言失败。证据为 `evidence/reflection-refresh.json`、`reflection-refresh-measurements.json` 与同名前缀截图。零 Lua/资源/引擎运行期错误不等于此渲染检查通过。

该结论来自 Runtime `20260923-1717-bf3316f` / DX11 / 正式 SurfaceShader 路径，不能据此推断所有引擎后端都失效。安装器的 HTTP 304 不是引擎版本号。试验性的自定义斜投影已完整撤回；进一步实测 `IsProjectionValid()` 返回 false，反射停留旧帧。正式实现仍为原有反射相机和裁剪平面，没有保留投影替代模块。早期额外探针 Scene 的截图存在刷新干扰，已删除，不作为正式证据。

因此前述 17/17 仅覆盖静态过滤、投影、尺寸和释放，不覆盖地下裁剪正确性。上述失败作为修正前诊断保留，最新结果见下一节。动画范围、原版时序与证据见 `GUI_MIGRATION.md` 的“PC 大厅换车升降”。

## PC 镜像视图的地下裁剪修复（2026-10-06）

正式 SurfaceShader 现在共享 `lib/PlanarClip.shaderinc`：只在镜像颜色视图中裁掉 Y<0 的片元，普通左手相机和阴影 pass 跳过。半浸入地板的车辆保留地上部分，不整体隐藏节点。推进器和悬浮体积按实例局部射线与世界裁剪平面的交点缩短积分区间，避免误删地上火焰；没有新增 Lua 事件、逐帧材质遍历或渲染目标。相机/反射强度/过滤预算不变。实现与未来新增镜面时的边界见 [PLANAR_REFLECTION.md](PLANAR_REFLECTION.md)。

`verify-planar-clip.ps1` **84/84**：12 组不透明、清漆、实例色、发光、全息、双面动态、武器、大厅、透明和体积效果；每组包含地上正例、地下裁剪、正常视图保留地下对象、关闭裁剪正例、跨地板保留、裁剪前后差异及恢复一致性。含倾斜/非均匀缩放的推进器。所有地下反射计数为 0，正常视图与关闭裁剪的正例可见，零 Lua/资源/引擎运行期错误。GPU 接触表为 `evidence/planar-clip-sheet.png`，只检测测试对象，不是大厅相似度指标。

正式大厅 `verify-reflection-refresh.ps1` **5/5**：地上标记 891 像素，地下启用裁剪为 0，关闭材质与相机裁剪后为 6131；手动/持续刷新隐藏标记均为 0。原失败已在这条 PC/DX11 路径修复，不等于其他后端或整个大厅渲染已验收。此前 `reflection-refresh` 同名文件现保存最终通过结果。

新增裁剪与武器光晕的条件表达式组合曾触发 HLSL 编译器内部错误，已将两段线性光晕改写为等价的 max 表达式并合并 discard。原外观曲线不变。字体、整体光照、后处理与 GUI 的其余差异仍未关闭。

本轮完整场景换车仍为 342/342、建造菜单 82/82、画面设置 45/45。反射过滤验收移除额外 Probe Scene，直接读正式反射及现有过滤纹理，并在同一过滤链中检查常量颜色；17/17 通过。武器动作缩放表的同步遗漏也已补入正式导出，动作 3156/3156、持续效果 756/756 与加特林渲染 755/755，见 CURRENT_SOURCE_DRIFT.md。以上数值不作为整体视觉一致性结论。

## 已接入的场景

| 内容 | 实现 |
|---|---|
| 仓库主体 | 原始 60×72×32 米布局、装甲墙、门框、顶灯、桁架、环廊、栏杆、控制室、设备与货箱 |
| 地面与建造甲板 | 底层地板、切角甲板、刻线、网格、对称轴、亮环、建造范围光墙与高度线 |
| 门外 | 跑道平台、引导灯、塔、泊位支臂、天线、停靠飞船 |
| 太空 | 原始 Shader 的星云、闪烁星空、太阳光晕、地表星球与大气、带环巨星、卫星、空间站、航行飞船及流星 |
| 动态设备 | 4 台多关节机械臂、2 台巡航无人机、行走天车及小车、6 件旋转陈列零件 |
| 光效 | 能量门、顶灯薄光束、全息投影光束、车辆欢迎扫描、呼吸灯、闪灯、浮尘 |
| 贴图 | 原 H5 Canvas 输出的招牌、控制室、操作屏、整备位墙牌、地面编号、双全息面板 |
| 原生渲染 | PBR、阴影、HDR 场景环境、按质量档限尺寸/频率的实时平面反射、引擎 SSAO、ACES、UE Bloom、暗角、距离雾 |

转换输出：133 个原生 `.mdl`，387,906 顶点、129,302 三角形；27 张场景 PNG、1 张 HDR 环境图；14 个 Hangar SurfaceShader。几何数量含旋转展柜的原 H5 模型，不含另行转换的车辆零件资源。坐标按 X 镜像转换，同时转换三角绕序、法线、UV 与旋转；单位仍为米。

## 打开与操作

编辑器通过“文件 → 打开场景”打开 `assets/Scenes/OrbitalHangar.xml`。Scene 可直接编辑；Play 启用动画与车辆，Maker 加载同一份已保存场景。独立开发预览在项目根运行：

```powershell
.\preview-hangar.ps1 -Dev
```

- 首页左/右键拖动旋转；中键或 Shift+左/右键拖动平移；滚轮缩放。手动操作打断自动取景和旋转。建造页左键保留编辑语义。
- F1：帮助；F2：大厅全景；F3：门外；F4：仓库后区。
- B：建造网格/光墙；R：欢迎扫描和机械臂迎接；G：分页零件目录（PageUp/PageDown 翻页）；1–5：档位信息。
- `preview-hangar.ps1 -View car|hall|door|rear|display`：同一场景的截图观察视角，隐藏 HUD，Shader 时间固定在 10 秒；日常查看动画请使用默认入口。

正式场景是编辑器和游戏的共同来源，包含 160 个命名模型资源、98 个命名材质资源（含程序化平面、光点、浮尘等落盘结果）。Lua 只绑定已有节点与瞬态渲染资源。F5 重读场景；开发模式保存场景/大厅材质触发重载，保存 HangarMotion.lua 热替换动画。完整边界见 `../ARCHITECTURE.md`。

## 保留范围和视觉差异

当前 H5「赤焰 GT」已同步为 209 件、质量 1311 kg、预算 788、耐久 7530；「磐石」为 223 件，见 CURRENT_SOURCE_DRIFT.md。两块全息面板、墙牌和地面车位号由 HangarPanels 按蓝图版本、车名、档位和车位变化重绘。编辑器保留四张 T3 原版画布作为静态预览；废弃的其他四档共 16 张贴图及其 meta 已删除。

这是场景及其原生渲染接入，**还不能称为逐像素一致**：

1. Three 的 PBR/矩形光与 UrhoX 光照求解不同；当前 UrhoX 阴影、墙缝对比和地面反射更硬、更清晰。
2. 原 H5 的 GTAO 使用 UrhoX 前向 SSAO 替代；Bloom/ACES/暗角使用原生实现。独立 HDR clamp、柔焦扩散、分离色调/饱和度调色及镜头色散尚未逐通道复刻。没有为了外观擅自切换到尚未做移动端验收的延迟管线。
3. 原 H5 指数平方雾以原生距离雾近似；HDR 环境图离线捕获，动态外景不逐帧重烘焙 IBL，地面平面反射实时更新。
4. 四块信息面已接原生 NanoVG 按需重绘，空蓝图会清空旧投影；只改车辆零件时不重绘墙牌和地面。正文系统字体与原生 MiSans、文字栅格和场景光照仍有差异。证据见 GUI_MIGRATION.md 的动态画布小节，不能据此宣称整个大厅逐像素一致。
5. 展柜保留源几何及基础 PBR/发光外观，源零件内部特殊效果不等于已完成整个零件渲染管线迁移。驾驶、碰撞导航、建造交互、H5 大厅菜单/商城/车位功能不在本轮完成范围内。

## 验证证据

`evidence/validate.json`：真实 GPU 渲染运行 180 帧，**PASS；16/16 断言；Lua/资源/引擎运行期错误均为 0；缺失项目资源为空**。断言覆盖真实入口创建的场景、机械臂/无人机/天车运动、六个展柜、双面板、外景/能量门、IBL、反射目标、网格开关与档位切换。

已人工检查原生 `hall.png`、`door.png`、`rear.png`、`display.png`、`normal.png`；另保留 H5 同视角 `h5-hall.png`、`h5-door.png`、`h5-rear.png` 用于对照。原生截图实际尺寸为 2040×1080。用户视觉验收、移动设备帧率/发热和发布包验收尚未进行。

独立 Runtime 在项目资源挂载前仍输出默认 `Cube/Day/DaySpecularHDR.dds` 和可选 `themis_x64.dll` 启动诊断；项目运行阶段使用 `Hangar/HangarEnv.hdr` 且报告无缺失资源。这与真正 Shader 编译错误区分记录，不能把整个原始 stderr 称为无错误。

本轮已修复并通过画面确认的跨后端问题：条件表达式中的负数字面量被重复取负；HLSL 保留字 `line`；负底数 `pow` 导致黑带/NaN；全息 PNG 上下方向；独立 Runtime 中文字体资源。

## 文件与复现

- `scripts/scene/Hangar.lua`：绑定正式场景中的节点、材质、全息、边界和生命周期。
- `HangarMotion.lua` / `HangarAtmosphere.lua` / `HangarBuffers.lua` / `HangarMaterials.lua`：动画、光照、缓冲与反射、材质绑定。
- `HangarConfig.lua`：运动参数和相机边界，布局以 XML 为准。`assets/Hangar/`：正式模型/材质/贴图/HDR。`assets/Shaders/BLGL/Hangar/`：原生 Shader。
- `tools/migration/export-hangar.cjs`：只读加载源 Three.js，转换几何、Canvas PNG、展柜与环境。依赖 Node、Playwright 和本机 Edge；`PLAYWRIGHT_MODULE` 可指定模块目录。
- `tools/migration/environment-capture.html`：供导出器读取的离线捕获模板，不是运行时网页。
- `assets/Shaders/BLGL/Hangar/`：正式维护的 SurfaceShader，来源为 `hangarFx.js` / `hangarMaterials.js` / `render/reflection.js`。初次迁移用的一次性 `port-shaders.py` 已删除：它依赖已删除的 GaragePad 废案，且会覆盖后续全息画布与反射修正。
- `tools/migration/check-hangar.lua`：运行断言，同时导出当前原生蓝图数据 `native-panels.json` 供 Canvas 烘焙。
- `tools/migration/capture-reference.cjs`：只读拍摄源 H5 同视角证据。

复验脚本见项目 README。源导出器写入 `.tmp/hangar-import`，用于差异核对，不覆盖正式场景；Shader 转换器仍会修改正式 Shader，修改后需渲染验证。

资源来自源项目现有几何、Canvas 绘制和 Shader，未调用 AI 重画。MiSans 字体、默认 Vignetting 和启动环境依赖来自本机 UrhoXEditor 版本包 Data/Res 的已有资源。旧车库代码、旧贴图/Shader、编号资源副本、一次性场景快照工具、备份旧实现已移除。本目标目录未初始化 Git，未创建提交或发布。

## 编辑器与加载闭环（2026-10-05）

- 实际编辑器 Scene 视图已看见大厅；Play 后 Game 视图显示动态大厅和车辆；随后新版 142 件车辆也已显示，但用户报告运行中操作触发原生崩溃，编辑器交互稳定性尚未通过，Stop 正常返回编辑场景。
- 通过编辑器 MCP 将 Equipment 平移 0.25 米并保存，独立运行验证 3/3 通过（`evidence/editor-save.json`），随后 Undo 并保存恢复布局。
- `evidence/lifecycle.json`：12/12，通过修改场景布局、保存相机/档位/蓝图、无效场景保留旧画面、重试恢复、无重复车辆/反射、目录按需加载。
- `evidence/hotreload.json`：4/4，通过实际修改 Lua 文件、监听保存、替换动画模块、恢复源码，场景不重建。
- 当前正式场景截图 `evidence/hall-authored.png`；旧 H5 对照图保留作视觉依据，不是旧实现。
- DWP 配置取消 default 全量预下载，只预取 boot 字体/IBL；其余媒体使用引擎机制。尚未进行线上发布、远端冷缓存/弱网验证或手机性能验收。
