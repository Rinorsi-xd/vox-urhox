# H5 -> UrhoX 全范围迁移质检报告

日期：2026-10-14。本文是基于 `0bf472cb` 的历史静态质检，尚未完成最终运行/视觉/手感验收。用户随后授权 G0，当前执行基线已更新为 `2026-10-14` 最新提交 `0f7734cf4f72f1c01bc088e2b2927b9762a66a9e`（16:27:38 +08:00）。最新增量与运行结果见 [G0_EXECUTION_2026_10_14.md](G0_EXECUTION_2026_10_14.md)，下文的旧构建、日期和“本轮未运行”只描述原审计时点。

配套执行清单：[FULL_PARITY_PLAN_2026_10_14.md](FULL_PARITY_PLAN_2026_10_14.md)。该清单是后续收尾依据；历史迁移文档只提供各自构建的证据。

## 1. 结论

当前不是完整复刻，而是旧基线功能迁移、部分视觉近似、新基线少量补充并存的状态。用户指出的 UI、字体、边界、敌我识别、物理和手感差异具有代码依据。不能用模型数量、按钮存在、公式回放通过、局部原生测试通过代替完整迁移。

本轮发现了实际影响驾驶的旧参数和未接机制，不能统一解释为 Rapier 与 Bullet 的差异。当前不能给可信完成百分比，也不能承诺全部收尾所需天数。

没有一个大系统可以凭本轮检查标记为“10 月 14 日完整一比一验收通过”。部分系统有实际实现与历史流程验证，应该复用；不是全部推倒重写。

## 2. 对照版本与取证范围

| 对象 | 身份 |
| --- | --- |
| H5 原仓库 | `D:/Rino_Project/Vox` |
| 固定 H5 分支 | `2026-10-14` |
| 固定 H5 提交 | `0bf472cbae08f8230102f5bac89ca157d52a2d90` |
| 提交时间 | 2026-10-14 14:43:34 +08:00 |
| 冻结快照 | `.tmp/outgame-source-2026-10-14T07-04-01-867Z` |
| 冻结内容清单 | `outgame-baseline.json`；2156 个已提交文件，545782677 字节，数字取自基线文档 |
| UrhoX 工程 | `D:/Rino_Project/maker/Vox/VoxelCraft` |
| UrhoX 分支/当前 HEAD | `codex/h5-2026-10-14` / `d6f5958` |
| 本轮对照对象 | 当前工作区，包含此前未提交的通讯框/UI/音频改动 |
| 当前模式 | `.project/settings.json` 中 `@runtime.multiplayer.enabled=false` |

冻结快照不包含原仓库随后未提交的修改。最新目标是全部系统一比一，早期“70-80%”“只迁局外”“排除无尽”均已作废。

本轮读取用户截图、源与目标模块、资源清单、历史验证报告。未启动新的游戏试玩、未运行物理对照、未重新构建、未切换预览、未改游戏代码、未提交或发布。以下“确认”是静态证据确认，不是本轮新运行验证。

最后准备的构建为 `.tmp/outgame-cached-1791964511467 / manifest-5443a36b.json`；此前运行交接记录的 4206/4204 服务为 `manifest-26bf9bca.json`。本轮没有重新核验服务进程身份，不能把已准备构建视作当前浏览器必然运行的版本。执行计划 Z02 要重新确认。

状态约定：

| 状态 | 含义 |
| --- | --- |
| 已接入 | 有生产入口和实现；完整一致性仍未通过 |
| 部分 | 有实现，但已知机制、样式、内容或验收缺口 |
| 不一致 | 已找到源/目标的具体差异 |
| 未接入 | 在本次检查的生产路径未找到对应实现，或入口明确为空/阻断 |
| 待核验 | 不能由现有证据判定；必须保留在计划中，不按完成处理 |
| 源占位 | 冻结 H5 自身未实现；复刻现状，不自行发明玩法 |

## 3. 最高优先级问题

### F01：基线声明更新，但资源和验证没有整体更新

`docs/migration/parts-manifest.json` 的 `source` 仍为 `.tmp/outgame-source-2026-10-12T21-18-23-463Z`，即旧 10 月 13 日基线。该清单列出 316 个 rig 引用、579 个模型；当前 `Parts/Catalog.json` 列出 311 个类型。这些数量不是 10 月 14 日逐类型完整同步证明。

旧记录中出现的 198/201、695 模型引用、579 独立模型等口径不能相互替代。必须按源文件、导出依赖、生成物、运行时引用重新建立清单。旧文件可能内容未变化，但需逐项证明，不能仅更改文档日期。

对应 Z01、Z03、R01-R07。

### F02：字体映射没有跟随最终 CSS 覆盖

源 `shared/css/new-ui-tokens.css` 给大量新版界面设置 `--display/--game=VoxIndustrial`；源 `shared/ui/reticle.js` 使用最终变量。目标 `scripts/ui/SourceDraw.lua:24` 的 HUD 注册仍为 Chakra Petch；`CommsCard.lua:97` 的频道标题仍用注册为 Barlow 的 `vox-display`。

目标 `SourceFonts.lua:20` 默认正文为 MiSans，受限环境无法走原 Windows 系统字体选择。目标已导入 Industrial，不等于所有控件选用了正确字体。剧情等独立主题也不能无差别换成同一字体；必须查最终继承和覆盖。

对应 U01-U03、U09。

### F03：通讯框存在自行改排版

源 `shared/ui/nonoComms.js:39` 的频道、身份、信号条属于同一标题 flex 行；目标 `scripts/ui/CommsCard.lua:102` 把频道另起一行，正文分隔线和起始位置随之改变。当前截图不是已接受的一比一画面。

此前新增共享通讯状态、立绘 GPU、打字与声音连续性有局部验证，但不证明标题、框体、字体、动效和全流程全部正确。Boss 代码还引用 `UI/Faces/chairman.png`，本轮交接确认该资源未存在；第五关没有实际接入。

对应 U04、U05、S05、A02-A04。

### F04：地面操控仍使用明显过时的参数和逻辑

对照固定快照 `shared/drive/contactControl.js` 与当前 `scripts/drive/ContactControl.lua`：

| 项目 | H5 基线 | UrhoX 当前 | 影响 |
| --- | --- | --- | --- |
| 起步加速度基值 | `A_MAX=15` | `10`，目标第 22 行 | 起步响应、加速时间不同；实际还受其他限制 |
| 轮车方向响应 | `steerIn=16` | `9`，目标第 6 行 | 打方向和回正过程不同 |
| 轮车横摆控制 | `yawK=18 / yawKFree=8` | `11 / 5` | 转向力度与松手惯性不同 |
| 刹车加速度上限 | `min(16,aStabBrake)`，含模拟压力倍率 | `min(10,aStabBrake)` | 制动距离与模拟量输入响应不同 |
| 松油门减速项 | `mass*1.6*dt` | `mass*.8*dt` | 滑行衰减不同 |
| 轮车低速转向基值/最大角速度 | `PIVOT=1.6 / MAX_YAW=2.8` | 基值 `1.1` / 上限 `2.2` | 低速掉头与高速转向不同 |
| 转向时非转向轮侧向系数 | `DRAG_SIDE=.45` | `.3` | 侧滑和车尾甩动不同 |
| 轮式抓地调校常量 | `CONTACT_TUNING.wheelGrip=2.2` | `TUNING.wheelGrip=1.6` | 常量版本不同；还需核实际悬挂消费路径及最终接地效果 |
| 贴地加速/制动防翘头 | `ANTI_PITCH=.8`，steady/keepUp 联动 | 未找到该完整分支 | 高窄车、短轴距车表现不同 |
| 履带独立调校 | `TRACK_FEEL`，独立响应、转向降速、侧向控制、贴地力 | 旧 wheel/track 分支，没有完整 TRACK_FEEL | 履带被近似当轮车处理 |

这里不是“少数视觉效果”，是控制器版本落后。对应 P03-P07。

### F05：底盘稳定器和物理步后防弹飞未接入

源 `shared/drive/vehicle.js` 调用 `chassisStability.js`：贴地拉回、腾空额外重力、姿态控制、防翻、俯仰/侧倾角速度限制。目标 `Vehicle:Step` 没有对应调用。

源 `Vehicle.postStep()` 在物理求解后限制异常向上速度突增，同时排除主动跳跃、喷气、机翼和钻头。目标未找到对应流程。源调参 `TERRAIN.maxPopUp=4`。

仅已有侧倾阻尼不等于原底盘稳定器。对应 P06、P08、P09。

### F06：石块碰撞规则和高度限制不同

源 `shared/drive/terrain.js` 根据 `TERRAIN.minObstacleRadius=1.6` 决定障碍碰撞，并区分中小障碍碰撞组和车身穿越条件；目标 `CraterPhysics.lua:49` 为 `b.r>=.9`，统一注册地面层。源石块摩擦为 `.8`，目标通用默认 `.85`。

源推进器/机翼与整车有 `CEILING={y:200,band:60}`、定高限制和超限下压力；目标未找到完整软天花板接入。目标地图边界可见屏障也未接齐。

这会改变小石头是否卡车、车底是否被顶起、空中能否无限上升。对应 P09、P13、M03-M05。

### F07：悬浮、翼面、机甲和受损重建状态不完整

源悬浮升降每秒 `.6`、范围 `.6-1.7`；目标 `Vehicle.lua:130` 为 `.4`、`.6-1.35`，恢复状态也钳制在旧范围。

源车辆有 `stepWings`、`MechLegController`、`MechHitboxes`、机翼状态、机甲喷气与支撑份额。目标当前 Vehicle/DriveView 没有完整对应。

源 `getState` 保存底盘历史量 `vPrev/aLong/aLat/airT/drifting/landingTime`；目标 `GetState` 没有这些完整历史量，而受损重建会调用它。可能导致掉件后的手感不连续；实际跳变幅度待对照运行，不能凭静态检查断言每次都会跳。

对应 P10-P14、R04-R06、W07。

### F08：速度感、相机和辅助瞄准不同

源 `ChaseCam` 默认 follow=false、按半径 `clamp(radius*2.3+3,6,80)` 定距，使用原俯仰范围与水平/竖直跟随平滑；目标 TrialSession 默认 follow=true、距离 `max(24,radius*3.4)`、另一套偏移和避障后 FOV 补偿。

源 `SpeedFov` 用水平速度、车型顶速、历史峰值、起效阈值和平滑/变化率限制；目标是 `48+min(1,abs(speed)/28)*6` 加插值。源 FOV 最大速度增量为 12；横移和不同车型的速度感不等价。

源 `aimAssist.js` 包括敌方零件软吸附、遮挡/范围筛选、移速收窄、减灵敏度和触屏跟随；未找到完整目标实现。使用 ThirdPersonCamera 库仍应复刻外部控制契约，不能继续保留临时镜头参数冒充原版。

对应 C01-C08、W03。

### F09：地图屏障、敌我线与威胁系统有明确缺口

源 `boundaryFx.js` 有接近 40m 显现、12m 更清楚、6m 警告、蜂窝/扫描/接触环及顶部屏障。目标大厅的 `Hangar/Boundary.shader` 是建造范围，不是战场边界；打捞物理外墙也不等于可见屏障。

源 `aimLines.js` 为敌红/友蓝狙击线、枪口闪光、恒定屏幕线宽和“正在瞄我”检测。目标名牌和基础目标框不替代该系统。导弹来袭/狙击/锁定威胁与对应声效未接齐。

对应 M03-M05、W08、B06、A06。

### F10：进场阻塞、剧情、无尽及开篇未收尾

目标 HUD 根据 `pointer.captured` 显示局内准星；因此鼠标未成功接管时可能只剩暂停层。`MatchIntro:Finish()` 只为触屏直接 Resume，PC 等待真实点击捕获。用户报告的“卡在 ESC/T 页”必须复现并修正入口/遮罩/焦点/锁定，不能直接删提示或强制锁鼠标掩盖。

`GarageHud.lua:105` 开篇按钮空回调。`MissionData.lua` 只加载 Level1-4；`StoryPage.lua:176` 第五关仅弹迁移提示。未找到无尽运行模块/入口。源 main 有实际 Intro、Endless、Boss/Epilogue 路径。

最新 20:9 教程报告 `evidence/tutorial-web-phone-landscape.json` 为 FAIL：实际修改装配等待超时。其 errors=[] 只表示未捕获运行异常，不表示流程成功。

对应 Z04、C07、S01-S09、N01-N07。

## 4. 全系统覆盖与当前状态

下表源路径均相对固定 H5 快照，目标路径相对本工程。计划中的每个分组有逐条操作与通过条件。

| 分组 | H5 主要来源 | UrhoX 主要承载 | 当前判断 |
| --- | --- | --- | --- |
| Z 基线/入口 | `three/src/main.js`、`shared/ui/shell.js`、完整 manifest | `main.lua`、`app/HangarApp`、构建 manifest | 混有旧派生资源；新构建/预览身份需统一；HUD 启动修复有历史证据 |
| U 字体/公共 UI | `shared/css/*`、`ui/ui.js`、`mechFrame.js`、`nonoComms.js`、`motion.js` | `ui/Source*`、`Comms*`、DialogHost | 不一致，尚未全页视觉验收 |
| H 局外 | `home.js/workshop.js/musicBox.js/liveryPanel.js/salvageHub.js/storyPage.js` | `ui/GarageHud/Home*/Workshop/Livery*/MusicBox/SalvagePage/StoryPage` | 多数页面已接入；新基线细节/入口与完全视觉未收尾 |
| E 建造 | `shared/build/*`、`controls/cameraRig.js`、`mobileEditor.js`、`ui/inventory.js` | `construction/*`、`controls/Build*`、`ui/Build*/Inventory*/RotorHud` | 基础、多选、拉伸、连块、转轴已有；完整新基线与组合边界待核验 |
| R 模型/装配 | `shared/parts/*`、`three/src/parts/*`、Prefab/材料/缩略图 | `parts/*`、`render/PartRig/VehicleView/DriveView`、派生资产 | 旧派生资源未全量核新基线；翼面/新版机甲未接完整 |
| P 物理/驾驶 | `shared/drive/*`、`combat/tuning.js`、`terrain.js` | `physics/*`、`drive/*` | 明确旧参数与缺机制；源逐部件质量与原生质心/惯量适配尚未证明等价 |
| C 相机/输入手感 | `chaseCam.js/speedFov.js/controls.js`、`three/src/drive/testDrive.js` | `TrialSession/DrivePointer/DriveInput/ThirdPersonCamera` | 默认机位、follow、速度 FOV 不同；捕获链路待复现 |
| W 武器/破坏/特效 | `combat/weapons.js/drill.js/carUnit.js/aimAssist.js`、`weaponFx.js/effects.js/aimLines.js` | `combat/*`、`render/Weapon*/Combat*/Missile*/Drill*` | 多武器、逐块破坏已有；辅助瞄准、威胁/线/部分新规则与状态未完整 |
| M 地图/渲染 | `scene/*`、`terrain/*`、`battle/*World/mapModules/boundaryFx/shieldFx`、`salvage/*` | `assets/Scenes`、`scene/*`、`drive/*World/*Physics`、`render/Crater*` | 大厅/试车/陨坑/打捞已导入；边界/碰撞规则缺，质感/动态/成本未全验 |
| B AI/竞技 | `shared/ai/*`、`shared/battle/match.js/matchmaker.js`、`three/src/battle/matchSession.js`、`shared/ui/matchHud.js` | `combat/EnemyDriver/BattleController/*Rules/Matchmaker`、`ui/Match*` | 本地 AI 三模式已有；AI 全行为含钻头专用策略待核；HUD/流畅度未通过 |
| S 剧情/教程/演出 | `shared/story/*`、`battle/story*`、`three/src/intro/*` | `story/*`、`ui/TutorialPage/Mission*/StoryPage`、`app/MatchIntro/MvpShow` | 教程与前四关部分；第五关/Boss/片尾/开篇未接；MVP 有旧基线实现 |
| N 无尽 | `battle/endless*.js`、`ui/endlessHud.js`、源波次/掉落/编辑规则 | 未找到独立生产对应模块 | 未接入；必须按此基线真实规则迁移，不套旧策划案 |
| L 打捞 | `shared/salvage/*`、`three/src/salvage/*`、`ui/salvage*` | `salvage/*`、`ui/Salvage*`、`render/Salvage*`、Warehouse | 行动、仓库、演出已有历史证据；新基线自然流程/经济/AI待核 |
| A 全部音频 | `shared/audio/*`、`ui/uiSound.js`、Intro/Battle voice | `audio/*`、Sounds 导入数据 | 多数采样已有；无线电处理、碰撞、威胁、机甲、全局混音/氛围待补核 |
| D 存档/进度 | `shared/storage.js`、`shared/build/blueprint.js`、`story/progress.js`、`salvage/stash.js` | `storage/*`、construction/Garage、CloudSync | 本地双备份及云协议已有；正式账号刷新/多设备/全类型往返未验 |
| Q 加载/更新/性能 | `render/warmup/pipeline`、loading/transition、资源依赖 | `app/ResourceGate/LoadingFlow/SceneLoader/HotReload`、Quality/RT | 按需下载、分帧与释放已有；完整冷/热性能、边玩边下、更新回滚未验 |

### 原版自身的占位和工具边界

原版普通商店页明确“还在设计/商店还没开张”，目标保留该页面并非漏迁已存在购物玩法。打捞工坊买车是另一条实际经济路径，必须迁移。

固定源的创意工坊主要为官方预制车浏览/详情/导入；不能凭“创意工坊”名字自行添加在线上传、点赞、审核或社交服务。是否有其他真实入口由 Z05 全入口盘点确认。

原版开篇按钮虽标“未完成”，但有 `?intro` 实际播放入口，不能据此把空回调当等价。

用户提到考场；当前固定源已发现试车与节足练习场，但尚未确认一套独立“新手考试任务”入口。S03 要先找真实入口与规则；如果只存在后续未提交工作，明确列基线外待同步，不自行编造，也不直接标已迁移。

离线转换、研究页、调试探针、示例、引擎文档不等于玩家系统；源码可达的 debug 地图和按键仍属于行为覆盖。网络多人当前未启用，源竞技也标 AI 离线；不是此次无依据新增在线服务的理由。

## 5. 现有证据能证明什么

| 证据 | 可支持结论 | 不能支持结论 |
| --- | --- | --- |
| 旧原生规则/装配/武器/步态回放 | 对应源版本、注入状态下局部计算一致 | 两个物理世界自然运行轨迹和新基线手感一致 |
| 已有局外/战斗/打捞 Web 报告 | 各自 manifest 与测试路径的行为 | 当前所有页面/所有构建/真机完成 |
| 音乐沙箱 35、缩略图 37、Web 音乐各 29 项 | 对应 os.getenv/文件读取修复 | 全部 UI、编辑器各入口与局内通过 |
| 通讯原生 19 项及 RT 非空白 | 共享状态、声音、局部 GPU 立绘功能 | 通讯框一比一、最新 Web 全流程通过 |
| 最新 20:9 tutorial FAIL | 改装路线存在未解决验收失败 | errors=[] 所以教程正常 |
| 历史 Web 4V4 压力记录 | 60 秒流程运行过，后段 rAF 中位约 118ms，流畅度失败 | 15 项流程 PASS 就代表性能 PASS |

性能出处 `BATTLE_PRESSURE_2026_10_13.md:27`。历史原生启动 DDS/DLL 错误和本地 aggregate archive 404 需独立登记；测试窗口错误 0 不能表述成所有日志无错误。

## 6. 为什么偏差累积到现在

1. 迁移单位偏向“模块有实现”，没有始终以玩家完整操作与可见状态作为验收单位。
2. 源 CSS 级联被拆成手工绘制参数，保留了旧字体/主题/布局假设，没有每次核最终 computed style。
3. 逻辑回放输入了原版已经算好的状态，能测公式，但掩盖了原生质量、惯量、悬挂和碰撞导致的闭环差异。
4. 资源导出、基线声明、当前预览和测试报告存在版本分离；旧 PASS 被过度用于新版本。
5. 临时镜头、视觉近似和缺功能没有统一阻止“大系统已完成”的结论。
6. 自然试玩、真机压力和完整视频不足；小截图/非空白检查无法评估驾驶、转场和声音连续性。

这些是当前工作方式和实现的缺口，不能把用户观察归为错觉。

## 7. 收尾执行原则

按照配套计划的 Z/U/H/E/R/P/C/W/M/B/S/N/L/A/D/Q 共 16 组逐条关闭。先统一版本并修进场，再处理驾驶控制和核心 UI，补齐战斗/地图/内容，最后做同构建整体验收；性能采样从第一批开始。

保留现有模块边界：输入产生 command，模拟拥有状态，render/UI 读取状态，app 负责切换与资源所有权；在同一游戏入口修正，不新建替代游戏。共享数据从固定源转换；保留语义 ID、坐标 ABI、米单位和稳定 partId。

所谓一比一指所有可达功能、规则、数值、输入、文案、字体选择、构图、动画节奏、声音事件和反馈保持原版。引擎格式转换是实现手段，不能成为删机制的理由。跨引擎字形栅格/物理数值误差需要记录、量测及人工判断，不得直接批准看起来或开起来不一样。

每条需要同一基线、同一目标构建的自动证据与画面/视频/操作证据。最终 PASS 字段分功能、视觉、手感、性能；缺任何适用项都不能关闭。

计划文件是完整范围的执行合同，不是已经完成穷尽式动态审计。Z05 要扩展真实可达入口/事件清单；新增发现继续入表，不能因为本次报告没点名就跳过。

本轮只新增报告和计划，保留所有此前未提交改动；不上传、提审、发布或重新部署预览。
