# VoxelCraft 开发结构

当前阶段：大厅、零件/关节、轮式/履带/悬浮/飞行/节足移动、战斗及主要装备效果接入；继续核心建造与完整 GUI，编辑器稳定性尚未验收。迁移顺序为 **大厅 → 结构/骨架/移动/武器 → 特效 → 核心建造 → GUI**，每阶段以实际运行和画面验收结束，不以文件复制数量结束。

## 内容与状态的归属

| 层 | 路径 | 职责 |
|---|---|---|
| 正式大厅 | `assets/Scenes/OrbitalHangar.xml` | 编辑器与游戏共用，保存结构、变换、灯光、材质引用、运动节点和入口组件 |
| 大厅资源 | `assets/Hangar/Models`、`Materials`、同级纹理/HDR | 独立命名资源；运行时不重新生成建筑网格 |
| Shader | `assets/Shaders/BLGL/Hangar` | 外景、能量门、地面、全息、光束和浮尘；使用 SurfaceShader |
| 应用 | `scripts/main.lua`、`scripts/app` | 启动/停止、异步加载、场景切换、重载事务 |
| 大厅行为 | `scripts/scene` | 绑定已有节点，更新动画与瞬态反射，不重建大厅 |
| 首页换车 | `app/HomeVehicleSwitch.lua`、`scene/CarLift.lua` | 应用调度一次待执行换车；表现层只计算原版升降曲线。Garage 保持同步事务，切场/建造前停稳，销毁时取消回调 |
| 大厅反射过滤 | `render/ReflectionFilter.lua` | 大厅拥有三个按反射帧更新的 HDR 降采样目标，直接读同一反射图；独立两命令过滤流程，尺寸变化事务替换、退出显式释放 |
| 大厅反射裁剪 | `assets/Shaders/BLGL/lib/PlanarClip.shaderinc`、`Equipment/Volume.shaderinc` | 镜像视图的世界平面片元裁剪；体积按实例局部射线区间裁剪。正常视图和阴影跳过，无逐帧材质遍历或额外渲染目标；边界见 `migration/PLANAR_REFLECTION.md` |
| 车辆数据 | `scripts/construction`、`parts/Defs.lua`、`Config.lua` | 蓝图、装配规则、档位与零件定义，独立于场景对象 |
| 建造命令 | `construction/BuildEditor.lua`、`Placement.lua`、`GridRay.lua`、`EditHistory.lua` | 源格/子格拾取、装配方向、选择/移动/涂装与 300 条事务历史，不依赖原生节点或输入 |
| 建造适配 | `app/BuildSession.lua`、`controls/BuildInput.lua`、`render/BuildGhost.lua` | 当前大厅内组合交互与预览；增量更新同一 VehicleView；限定池/签名缓存；切场释放 |
| 建造自由相机 | `controls/FreeFlight.lua`、`BuildCamera.lua` | 纯源坐标飞行计算与原生相机/鼠标捕获分开；复用大厅视口，不创建角色或第二份场景 |
| 首页取景 | `controls/HomeStations.lua`、`OrbitCamera.lua` | 源车辆尺寸与四个栏目机位独立映射；650ms 原版镜头过渡、手动打断与房间边界；首页左键旋转和建造左键编辑分开 |
| 建造透视 | `render/BuildXray.lua` | VehicleView 拥有两份按需透明材质与原材质引用；作用于结构批次，不改变蓝图、共享材质或功能件机械显示 |
| 客户端存档 | `scripts/storage` | 原生 File 双版本恢复、草稿/20 车位、H5 蓝图码；WASM 持久化需后续云适配 |
| 物理描述 | `scripts/drive/VehicleSpec.lua`、`assets/Drive/Geometry.json` | 从连通蓝图计算车身/薄板碰撞、悬挂点、推进器、受击体积和碎片 |
| 原生物理与驾驶 | `scripts/physics`、`scripts/drive` | 源坐标适配、原生刚体/碰撞、射线悬挂和轮胎约束；60 Hz 固定步长，输入注入 |
| 试车场 | `assets/Scenes/TrialTrack.xml`、`assets/Track` | 原版场地、标线、牌子、贴图与 SurfaceShader；静态模型按材质和空间区块合并 |
| 试车生命周期 | `scripts/app/TrialSession.lua` | 进入时创建物理世界/车辆/跟随相机，离开时释放；复用唯一 main.lua，不另设游戏入口 |
| 武器模拟 | `scripts/combat`、`assets/Combat/Weapons.json` | 固定步长瞄准/能量/弹道，依赖注入射线和伤害回调；不读取键盘或写入场景 |
| 破坏与残骸 | `combat/CarUnit.lua`、`Debris.lua`、`VehicleRay.lua` | 临时损伤蓝图、连通组、物理重建、到期回收、受击零件定位；源玩家车保持无伤害规则 |
| 破坏显示 | `render/CombatView.lua`、`ChipEffects.lua` | 复用存活零件实例、残骸姿态插值、有限容量碎屑池；退出试车场销毁 |
| 战斗显示 | `render/CombatEffects.lua`、`EffectBatch.lua`、`TargetFeedback.lua` | 消费每个模拟步的事件；有限容量、分批提交、按场景销毁；显示不回写伤害 |
| 武器装备显示 | `render/WeaponMotion.lua`、`WeaponPresentation.lua`、`WeaponEffects.lua` | 纯动作状态、原生关节/私有动态材质、车辆所有的惰性特效批次；最终炮塔变换后更新；预算和远近裁剪 |
| 车辆显示 | `scripts/render`、`parts/PartAssets.lua` | 按需加载离线转换的原生模型；PartRig 保留关节，目录分页创建并释放 |
| 悬浮/推进显示 | `render/ActuatorView.lua` | 读取物理出力/方向，更新万向架、转子与悬浮环；不回写物理，不复制共享模型 |
| 节足 | `drive/LegControl.lua`、`LegGait.lua`、`LegHitboxes.lua`、`render/LegView.lua` | 支撑/步态/受击/显示分开；60 Hz 同一 IK；显示锁脚针对插值后的车身求解 |
| 输入与界面 | `scripts/controls`、`scripts/ui` | 相机输入、原生首页/车位/库存/快捷栏与试车 HUD；原版细节继续对齐 |
| 试车统计 | `drive/TrialMetrics.lua` | 不依赖 UI/物理的三秒伤害窗口、累计伤害与直线计时；固定步长事件驱动 |
| 试车输入 | `controls/DrivePointer.lua`、`DriveInput.lua`、`ui/DriveControls.lua` | PC 捕获/释放与右键开镜采样、驾驶命令、点击恢复分开；失焦/窗口变化清除输入，释放鼠标后独立按键仍有效 |
| 试车界面 | `ui/DriveHud.lua`、`DriveChrome.lua`、`DriveMeter.lua`、`DriveDetails.lua`、`DriveVitals.lua` | 源 PC 锚点组合、NanoVG 外观、速度与运动状态、逐轮数据、双弧仪表；格式化数据最多 10 Hz 更新；无自创菜单/触屏分支 |
| 试车反馈 | `ui/DriveOverlay.lua`、`DriveFeedback.lua`、`DriveDraw.lua` | 投影和数据与 NanoVG 绘制分开；40 条循环飘字、3 个真实靶车标签；复用 UI 的帧和字体资源 |
| 车位规则 | `build/Garage.lua` | 换车前保存、槽位选择、新建/复制/删除、失败恢复；通过回调替换车辆，不持有场景 |
| 首页与缩略图 | `ui/GarageHud.lua`、`GarageLayout.lua`、`HomeStats.lua`、`GarageDialogs.lua`、`BayPreviews.lua` | 页面/布局/统计/弹窗分开；可见车位排队离屏渲染，单个临时场景，切页复用、离屏释放 |
| 通用弹窗与蓝图库 | `ui/DialogHost.lua`、`PauseMenu.lua`、`BlueprintLibrary.lua` | 首页/建造共用所有权与关闭流程；确认、可见缩略图、输入隔离；不另存槽位状态 |
| 诊断与定位 | `app/BuildInspection.lua`、`render/BuildHighlights.lua`、`ui/BuildStats.lua` | 编辑版本/档位缓存，原版内联诊断；两批有上限的格子高亮，离开建造释放 |
| 画面偏好 | `render/GraphicsSettings.lua`、`ui/GraphicsPanel.lua` | 受校验的原生设置、延时保存/失败重试、切场重用、退出恢复全局状态；不修改编辑场景 |
| 开发工具 | `tools/migration` | 源项目导出、参考截图、验收；不属于资源根，不进入正常游戏包 |
| 文档与证据 | `docs` | 当前结构、迁移边界、验证报告；不保存旧实现副本 |

`urhox-libs` 只读。资源地址相对 `assets/` 或 `scripts/`，不把绝对磁盘地址写进运行逻辑。尺寸为米、Y-up 左手坐标。

TargetFeedback 由 TrialSession 创建/更新/释放；TrackWorld 不再 require 显示模块。TrackWorld 仍是原生场地/物理适配器，会持有引擎节点，不能据此称为纯模拟。全场复原原地清零 stats，保持 env.stats 引用；重置靶板、靶车、锥桶、残骸和计时。HUD 在视口变化时先关闭弹窗、清除输入，再显式销毁旧控件树并重建；退出不依赖 UI.SetRoot 默认销毁（该默认值为 false）。

## 一份场景、两种运行入口

- 编辑器打开 `assets/Scenes/OrbitalHangar.xml`，不点 Play 即可查看环境。
- 场景中的 `GameplayEntry` / `app/HangarEntry.lua` 在 Play 时调用 `HangarApp`，使用当前编辑场景的运行副本。
- Maker / 独立 Runtime 从 `main.lua` 调用同一个 `HangarApp`，异步加载同一个 XML。
- 主入口设置启动标志，避免场景组件再创建第二个应用。
- 嵌入 Play 复用场景 Camera，Game 视口由编辑器持有；独立 Runtime 才设置 viewport 0。停止时恢复借用的渲染/鼠标/资源监视设置，Stop 可重复调用。
- 场景中不保存玩家车辆快照。车辆由蓝图实例化，编辑器 Play 停止后不会把运行期车辆写进正式场景。
- 运行逻辑不保存 XML；编辑保存由编辑器负责。重新导入 H5 时先写入 `.tmp/hangar-import`，不得覆盖正式场景的人工修改。

## 可编辑静态物件与动态行为

建筑和固定设备使用 StaticModel；StaticModel 表示网格组件，并不禁止节点移动。机械臂保留 Turret/Shoulder/Elbow/Wrist 层级；无人机使用 DronePatrol 锚点；天车保留桥架/小车；全息屏和展品各自保留节点。

编辑这些锚点/初始姿态，游戏以它们为基准施加运动。反射贴图、相机和车辆由运行期创建并负责释放；不会烘焙成假动画或写回编辑资源。材质按场景克隆，运行时更新 uniforms 不污染原始材质。

当前源项目的部分固定建筑已经按材质合批，因此 Interior/Exterior/Equipment 内并非每个小货箱都有独立节点。未来需要交互、移动或破坏的物件应拆出为独立模型/预制体，再接行为；不能把整个建筑批次当作单个动态物件。

## 热加载与更新边界

开发启动：`./preview-hangar.ps1 -Dev`。

- 保存大厅 XML 或大厅材质后，文件事件触发 350ms 合并，加载候选场景；验证并绑定成功后才替换旧场景。
- F5 手动重新读取磁盘场景。保留车辆蓝图、档位、相机位置和建造网格状态；不保留临时目录展开状态和动画时钟。
- 材质、模型和贴图启用引擎资源监视；大厅材质克隆通过场景重绑获得最新值。
- `HangarMotion.lua` 保存后读取最新本地源码，编译成功且导出 Update 时才替换行为模块，不重建车辆。UrhoX 的 LuaFile 缓存独立于 `package.loaded`，不能只清 require 缓存冒充热加载。
- 入口、数据结构、物理世界等结构性代码修改仍需重启预览。本阶段没有承诺任意 Lua 状态迁移。
- 编辑器 Play 使用当前场景副本；修改场景请先停止 Play，保存后再播放。F5 不会在 PIE 内创建与编辑器脱离的另一套场景。
- 发布版本的资源更新使用平台资源清单与发布版本；开发文件监视不是远程热更新。尚未发布本轮改动。

## 按需加载与边玩边下

采用 UrhoX 自带 DWP、资源清单和缓存，不建立第二套下载/版本系统：

1. `resources.json` 保留全量构建引用，预下载仅包含 boot 组的中文字体与大厅环境 HDR，取消 default 全量预下载。
2. XML、Lua、材质、Shader 等 blocking 资源按引擎规则就绪后启动。**当前文档也将 `.mdl` 列为 blocking**，不能宣称所有模型都能延迟下载。
3. 贴图、声音等媒体引用走引擎占位与下载完成后的热替换。只有打开功能时才引用该功能额外资源。
4. 场景反序列化使用 `LoadAsyncXML`，节点加载预算为每帧 3ms；旧场景保留到新场景成功。该预算不保证 Shader 编译和 GPU 上传绝不卡帧。
5. 车辆仅生成实际蓝图需要的模型，移除全零件 Warm；零件目录延迟到用户打开时构建。
   试车模块与资源只在进入时加载。完成场景切换后释放旧场景、动态反射与未被引用的缓存；重复进入/返回已检查模型卸载。不能靠隐藏两个场景冒充卸载。
6. 后续地图/战斗资源预取应在确定即将使用时发起 `DownloadResources`，完成/失败走回调。无需资源不能先 GetResource 再隐藏，否则已经触发加载。

DWP 主要减少首屏下载等待和资源驻留；高面数、阴影和实时反射的每帧开销需要另外优化。当前本地验证不能证明远端弱网、断线续传、缓存命中或手机帧率已达标。

## 后续迁移验收

| 阶段 | 必须验证 |
|---|---|
| 大厅 | 同视角对照；编辑保存进入游戏；Play/Stop；动画；热加载；缺失资源；资源释放 |
| 结构/骨架/移动/武器 | 对照当前 Three.js 定义与真实 GLB，保留枢轴/挂点/尺寸；逐类别验证装配、关节、手动移动和武器状态，不能只导入静态外观 |
| 特效 | 对接真实状态事件；推进/悬浮/履带/足部接触/开火/命中等分别验证；暂停、回收和重复进入不残留 |
| 核心建造 | 放置、旋转、删除、连接/预算/碰撞校验、撤销重做、蓝图保存加载；编辑结果直接用于同一个试车流程 |
| GUI | 当前先做 PC 原版复刻；UI 控件负责输入/所有权，SourceDraw/SourceButton 使用同一 NanoVG 帧绘制源外观；分别验收画面和功能 |

大型模块按职责拆分，不预先搭建空 ECS、插件框架或未使用的服务层。公共三维运算位于 `core/Math3.lua`；源坐标只在原生显示/物理适配边界转换。武器模拟只发出事件，`render/WeaponView.lua` 消费实际状态驱动炮塔，不反向修改命中计算。

武器与车体描述已有源数据对照；地面驾驶、悬浮/飞行、节足控制及关节、机库往返、交互射击与靶车破坏已接入。编辑器仍只托管机库 Play；试车使用独立 Runtime 的同一应用入口。原生车辆质心/惯量与 Rapier 有差异，悬浮支撑份额根据原生质心适配。剩余特效和完整 GUI 待继续迁移，见 `migration/DRIVING_MIGRATION.md`、`migration/AIR_DRIVE_MIGRATION.md`、`migration/LEG_MIGRATION.md`、`migration/COMBAT_MIGRATION.md` 与 `migration/DESTRUCTION_MIGRATION.md`。

装备显示由 DriveView 所有的 EquipmentEffects 消费物理状态，世界空间代理与批次位于场景根下，避免车辆 CELL 缩放叠乘。共用体积材质和流纹理按引用计数释放；动态发光走实例参数。细节和预算见 `migration/EQUIPMENT_EFFECTS.md`。

武器机械动作与持续特效由 VehicleView 所有，机库、分页目录、试车复用同一套显示模块。视觉状态复位不能重置真实能量/冷却。最后一把武器移除时释放其持续批次，场景切换时释放所有私有材质；参见 `migration/WEAPON_PRESENTATION.md`。核心建造应操作现有 Blueprint 并增量同步 VehicleView，不增加第二个预览世界或另一份存档模型。

首轮核心建造已按上述边界接入；F5 与试车往返保留同一 Blueprint 和编辑历史。增删/移动仅更新受影响零件；外壳私有材质由零件视觉对象所有。源对照和存档边界见 `migration/BUILD_MIGRATION.md`。

库存界面已替换临时分页按钮；纯 Inventory 数据、BuildSession 编排、原生 InventoryPanel/BuildHotbar 显示分别管理。零件缩略图直接由只读原版 Three.js 渲染器离线导出，完整哈希/透明检查后导入 112×112 PNG；游戏运行时只按可见行引用 PNG；CatalogList 与 OwnedModal 显式释放池化布局节点和独立弹窗容器。见 `migration/GUI_MIGRATION.md`。

BuildHud 拥有并显式释放 PC 控件树；BuildButton/BuildNameField/BuildStats/BuildOverlay 分别绘制按钮、车名、参数和场景提示。窗口变化由 BuildSession 清除输入后重建 UI，保留蓝图、命令历史、相机、展开状态和未提交车名。零件库由 InventoryPanel 组合、InventoryChrome 绘制原版外观、InventorySearch 保留文本输入、InventoryDetail 显示属性、InventoryList 管理带材质行的虚拟列表。恢复列表位置使用已知视口/内容尺寸，避免 Modal 测量阶段的 NaN 高度将偏移夹回零。UI 重建不重载三维场景；调色板关闭后不恢复旧按住状态。

InventoryPanel 明确计算列表视口高度并传给 CatalogList；不能在 Modal 的临时、不受约束测量阶段用可能为 NaN 的布局高度计算可见行。CatalogList 仅实例化该范围，最多保留两行空闲池。库存换屏状态是临时 UI 状态（顶部零件 ID、详情页、过滤器滚动），与持久化的纯 Inventory 快捷栏数据分开；不写入 Blueprint 或存档。

首页由 GarageLayout 调整现有控件，不因换屏重建根节点、弹窗输入框或车位预览。GarageHud 记录并取消按住的指针，清除滚动惯性；按车位序号比例恢复横向浏览位置。当前仅支持 PC 横屏布局；没有移动/竖屏分支和新增参数折叠入口。进入建造或离开首页时关闭弹窗、释放预览、取消输入并显式销毁根控件。布局状态不进入 Garage/Blueprint 存档模型。

2026-10-06 的代码拆分、依赖扫描、Git/worktree 实际状态及未完成项见 `migration/ARCHITECTURE_AUDIT.md`。Blueprint 的装配元数据已与模型缓存模块拆开；本项目目前尚未初始化 Git，没有 worktree 隔离或提交基线。

PC 首页按源码拆分为 SourceDraw（字体/矢量图元）、SourceButton（按钮绘制）、HomeChrome/HomeStats/HomeBay/HomePages（页面显示）与 GarageLayout（CSS 锚点）；不在 Render 中重算车辆统计，不新建第二个 NanoVG 上下文。UI.Scale.DPR 对应网页 PC 的 CSS 像素。素材导入保留原字体许可和图标路径来源，正文系统字体差异见 GUI_MIGRATION。

SourceModal 复用 OwnedModal 的内容容器销毁，接管原版弹窗绘制、布局和关闭生命周期；SourceHelp 从原版文本数据绘制帮助。DialogHost 区分逻辑关闭与资源释放，至多持有一个活动弹窗和一个退场弹窗；首页、建造、试车 Update 在 UI 遍历外推进退场，160ms 后销毁，场景 Dispose 立即回收。帮助页立即关闭，普通弹窗可在其背后继续淡出。SourceCodeField 复用输入控件的 Unicode 编辑和剪贴板，缓存文本换行并只画可见行；SourceHint 独立绘制 CSS 提示，避免通用主题覆盖源字号。首页蓝图导入复用 GarageHud 的动作/确认流程，车位数据归 Garage 所有。

弹窗关闭立即取消焦点和已捕获指针，停止 dialogTick；蓝图库 FinishJob 后保留已完成图片到 onDispose，画面设置在 onClose 保存。SourceModalVisual 只负责布局和绘制，SourceLayer 负责有限纹理、NanoVG 上下文及预乘透明度合成。过渡期间先合成完整卡片、再与遮罩合成，最后应用外层透明度；停稳时回到 UI 直接绘制，不持续重画离屏纹理。原网页 clip-path 会裁去弹窗外阴影；分组仅含卡片与 2 物理像素滤波保护边，固定 extent 避免小数位移重新分配纹理。1× 四张 RGBA8 暂停窗合计 3,142,800 字节、帮助窗 17,310,480 字节，关闭时释放。BayPreviews 按 context 持有图片句柄，避免离屏/直接绘制切换时误用另一 context 的句柄。

HomeNewMenu 的原版矩形外阴影由 SourceBoxShadow 九宫格采样静态高斯核实现；PNG 6,318 字节，解码 RGBA 148,996 字节，不做逐帧模糊。仅适用宽高均不小于 blur×3 的大矩形，不用于小悬浮框。菜单按 context 持有一个图片句柄，在 Destroy 中、UI context 销毁前删除。核由 import-ui-shadow.py 离线计算，主 UI 导入入口同步生成，未替换原版美术。

HomeNewMenu 入场复用 SourceLayer 整组合成，避免 UI 的逐图元 globalAlpha 使阴影透过背景。首次打开才建立独立 context，优先级 999979；内容在布局、DPR、悬停变化时更新，纯位移/透明度变化复用同一组。UI 保持原有子控件和命中坐标，只在过渡时跳过直接子树绘制；translateY 仍由 UI 渲染和输入共用。动画结束或提前关闭立即释放两张 RGBA8 目标和视频桥接，恢复直接矢量绘制，字体 context 保留到首页销毁避免反复加载。320×332.375 菜单含真实阴影及保护边的两张目标在 1× 为 1,544,944 字节、2× 为 6,102,768 字节（不含字体图集/驱动存储）。位置小数变化不会调整纹理尺寸。销毁顺序为 shadow 图片句柄、SourceLayer 桥接/纹理/context、控件树。

实际 Runtime 的 globalAlpha 是覆盖，像素证据见 migration/evidence/pc-nvg-opacity.json。子控件保留自己的 disabled/hover 透明度，弹窗父级透明度由 SourceLayer 在整组上应用；已删除上一版逐控件传递父透明度的 helper。不修改引擎 UI 参考库或全局 NanoVG API；两个独立离屏 context 在其 NanoVGRender 中工作，优先级早于 UI context，不在 UI 的帧内嵌套 BeginFrame。

BuildHover 只读取 BuildEditor 预览/目标和 BuildInspection 缓存，不重新执行命令或另建连接图。SourceRichText 为短提示缓存混合字体的换行测量。SourceToasts 归 HangarApp 持有，并注册为 UI 全局组件；队列最多三条，事件自行超时，跨 PC 窗口和 UI 根节点重建保留时间，应用 Stop 时显式注销。首页与建造通知复用此队列，旧常驻消息面板已移除；不增加独立 NanoVGRender 订阅。

PC 系统字体由 ui/SourceFonts 选择，core/SystemFontCollection 仅处理本机 TTC 字面与固定字距元数据。缓存放用户私有目录，按源大小和修改时间失效；SourceDraw 复用初始化结果，不在帧内做字体 I/O。原版字库导出仍是离线工具职责，系统字库不进入项目资源包；发布环境验证边界见 migration/GUI_MIGRATION.md。

SourceTextLayout 负责原版字体的 EM 字宽、标题 GPOS 字偶距、CSS 1/64px 行内宽度和共用基线，SourceDraw 仍统一调用 NanoVG 字体图集绘制。离线 source_font_metrics.py 从原标题字体导出 SourceFontMetrics.json（62,350 字节）；字距类压缩后保留相同查表语义，不引入浏览器运行时。首次使用解码，最多缓存 256 条、每条至多 2048 字节的文本布局；连续同字宽且无字偶距的字符合成一段绘制，避免中文标题逐字提交。缺字/组合字符沿用现有原生回退；不宣称完整 Unicode shaping。该模块依赖 ResourceData 和 SourceFonts，不接触模拟、蓝图或存档。

BodyFontMetrics 在 SourceFonts 初始化时读取已选正文 SFNT/TTC 的度量表和 Unicode cmap，文件立即关闭。当前 PC 正文保留 cmap/hmtx 共 223,904 字节及最多 2048 个字符宽度缓存；不缓存字体轮廓、不写系统字体资源。cmap 支持 format 4/12；有未支持 GPOS kern 的字体保留原生字宽路径。SourceRichText 按每行 baseline/上下边界布局，混合字号共享基线；行内片段累计原始小数字宽，整行才作 CSS 量化。同样式正文的断词片段合并绘制，控件继续缓存完整布局，DPI 改变不依赖之前的字宽取整结果。

SourceParagraph 由使用它的页面/控件持有，每个实例只缓存当前文本、宽度、样式和context对应的一份分行；移动、悬停或普通重绘复用已有行。HomePages、HomeStats、BuildHud调色板和SourceHint复用该路径，SourceDraw.Wrap已删除，避免每帧nvgTextBox和浏览器不同的分行算法。SourceRichText清除行首/行尾折叠空格，保留行内有效空格；正文行距按原CSS量化，混合字体仍共享基线。

工坊裸code标签的当前Windows Chromium monospace实际度量与SimSun一致，和显式Consolas文本框不同。SourceFonts.ResolveInlineCode按需选择系统SimSun，SourceDraw在该context第一次使用时才创建字体；只保留路径、hhea和ASCII等宽值，读取临时字体度量后的大缓冲可回收。13px原网页ASCII进位是7个逻辑像素，原生在DPR2的物理字形hint会改变进位，因此对该字体使用源逻辑字距修正。原字体表只读，系统字体不进入assets；缺少系统字体时保留内置等宽字体回退，不宣称非Windows或用户自定义浏览器字体设置下的像素一致。
