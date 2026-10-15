# 旧版残留独立审查

日期：2026-10-15。首批为独立静态审查，当时未改生产代码、未启动浏览器或 Runtime；后续授权修复状态另列于下，不替代真实画面与完整流程验收。继续原 G1-G6，不重新启动 G0。

接续状态：LA12–15及恢复青光现已有工作区候选；LA12最终646、LA13/14最终1516、LA15最终753、恢复FX44项功能通过，各自100ms尖峰仍令整体FAIL，实际同包Web未验。下文“新增未实施”等描述保留初审时点含义，不能据此重复报当前已落地候选为未开发。独立第二审由新agent承担，详见 `LEGACY_INDEPENDENT_REAUDIT_2026_10_15.md`（产出后引用），LB编号不与本报告LA编号混用。

**当前状态（后续快速复核）**：最新候选 `manifest-e1faa514`，普通4306/QA4307，`.tmp/outgame-cached-1792058408682`，脚本指纹 `11c223a54d66f2d77161e9134cd385494dc600c81926526a3aaa36dd0a270a15`。相对561唯一变化是ResetProgress样式修正；561已包含LA01–09/LA11候选及帮助wheel修复。首批下表的11e3证据明确为历史发现，不能解读为这些功能仍全部未实施。LA01原生33、LA02最终42、LA03–05 162、LA06–09/11最终752项功能通过；各自性能与实际路线边界见专项文档。561真实PC帮助wheel及R实际PC/20:9操作已通过，必要剧情PC12/触屏17断言通过；e1faa514新读条样式真实20:9 6/6通过，运行错误0，截图已查看。证据分别见CURRENT_EXECUTION和专项记录，旧包结果不改挂新包。LA01/03–05未全部关闭：自然陨坑/三竞技/恢复青闪和部件丢失通知仍缺或待验。LA10基线导航已校正，派生来源风险继续保留。新LA12–15为本次只读复核的剩余遗漏，独立审查agent未改生产、未运行引擎或浏览器。

## 基线与范围

- 权威冻结源：H5 `2026-10-14 / 2b169a9964645f5f346a7158bcb14447f040814a`。
- 下表 `源/` 指 `.tmp/outgame-source-2026-10-14T10-09-50-505Z/`。
- 实际原版入口：`http://localhost:5173/three/`。本次未操作页面；此前已验证该端加载的 26 份 CSS 与冻结源一致。
- 原仓库当前 HEAD `5f0bc4024d3edb7ef309f4fe19bb40f38892d4b9`；已执行 Git diff，差异均在 `review/audio/` 音乐听审档案，不解释下面的玩法/HUD 差异。
- 目标 HEAD `ad72080b262f93cf87ff464ae2ad72e5b10e2d89`，首批读取当时未提交工作区及普通预览 `manifest-11e3cbe9`；最新e1faa514包身份见顶部。后续生产修改和新包必须重新记录身份，不能把本文静态结论直接写成新包已修复。
- 用户所称训练场，当前生产入口对应“试车场”(`HomeBattle` 的 `test`，目标 `DriveMaps.trial`)；自由模式对应“自由探索”(`crater`)。没有另造第三个训练模式。
- 读取了 CURRENT_EXECUTION、FULL_PARITY_PLAN、outgame-baseline；重点扫描共享 TrialSession、TrackWorld、剧情/竞技控制器、公共准星/反馈层及派生数据。

结论：**初审确有玩法和 HUD 仍走旧版，不能归因为字体渲染或用户记错。** 初审证实原版已统一的玩家损伤链和剧情战斗 HUD 在目标存在真实运行分叉，现已有候选和上述有限实际验证；新增LA12–15仍未实施。本报告不是全项目完成证明，尚未满足各项完整验收时保持OPEN。

## 已确认差异

以下目标行号为初审/11e3生产快照的定位锚点；并发修复会使当前工作区行号移动。后续候选与实测状态单列，表中“旧版”描述初审时已证实的缺陷，不表示同一路代码修过后仍未修。

| ID / 严重度 | 分类与玩家影响 | 冻结源证据 | 目标证据 | 修复归属 / 主验收项 |
| --- | --- | --- | --- | --- |
| LA01 / P1 | 已确认旧版：试车场、自由探索仍使用裸 Vehicle；玩家不在 CarUnit 损伤/结构/重生链，HP/完整度读数回退到常数 1。战斗模式虽然已接 CarUnit，练习/探索没有一起统一 | `源/three/src/drive/testDrive.js:314` `sim.setPlayer`；`源/shared/drive/trackSim.js:103` 创建 externalControl CarUnit，`:111` combatUnits 包含玩家；`testDrive.js:1458`/`:1474` 两 HUD 都读真实 Life/structure | `scripts/app/TrialSession.lua:42` 非战斗直接 Vehicle.New，`:43` combat 仅竞技/剧情/打捞/无尽；`scripts/drive/TrackWorld.lua:83` SetUnits 只有靶车；`scripts/ui/ReticleState.lua:64`/`:66` 仅从 combat.player 取血；`scripts/ui/DriveOverlay.lua:104` 无 combat.player 直接退出玩家受伤/维修事件消费 | root 共享玩家生命周期，G1/G3：P/W/U09 |
| LA02 / P1 | 已确认旧版：R 仍立即原地抬高翻正，缺安全重置的读条、取消、冷却与避障；可能反复脱困失败或连续原地抬升 | `源/three/src/drive/testDrive.js:788` 起：1.2 秒读条、二次 R 取消、4 秒冷却；`:805` 安全历史；`:841` 安全点包围盒/坡度/占用检查 | `scripts/app/TrialSession.lua:152` Flip 原地 y 加 radius*.6；`:198` R 直接 Flip。全 scripts 未找到 resetChan/safeHist/resetReady 实现，仅触屏 UI 有对不存在 resetChan 的判断 | root 驾驶输入/物理，C/P/E |
| LA03 / P1 | 已确认旧数据：站点争夺、推车实际复活仍 8 秒，冻结规则已是 15 秒；出兵节奏、死亡 HUD 和对局平衡不同 | `源/shared/battle/match.js` 导出 MATCH_MODES.conquest/escort.respawn 均 15；本次 Node 导入结构化比较 modes=false。源 `shared/ui/home.js:56` 自身仍写8秒，属于源内部文案矛盾 | 初审 `assets/Combat/Arena.json:1` 两者 respawn=8；`scripts/combat/BattleController.lua:121` 实际使用 rules.cfg.respawn。HomeBattle卡片8秒与源相同，不列作迁移旧版 | 竞技数据导入/控制器，B/H06 |
| LA04 / P1 | 已确认旧规则：站点圈只有 16 米，源为 22 米；占点/推车仍要求车中心进圈且高度差小于 8 米，大机甲车身压圈但中心较高时不生效 | `源/three/src/battle/matchSession.js:184` inPoint 水平阈值 radius + 车 bounds.radius*.5，高度阈值 8 + bounds.radius；`:200` 三点 radius=22；`:238` 占点、`:461` 推车、`:474` 推车回血复用 | `scripts/combat/BattleObjectives.lua:80` 占点 Flat<16 且高度<8；`:87` 推车固定 push22、高度<8；`:140` 推车回血也只检查固定水平半径。目标 AI Goal 的站点半径 `:165` 也仍16 | 竞技目标控制器，B/M/P |
| LA05 / P1 | 已确认漏统一：争夺离开基地、推车离开车旁后缺脱战恢复；源所有竞技模式共用呼吸维修 | `源/three/src/battle/matchSession.js:172` breathe，默认5秒脱战、每秒15%、每.5秒RestoreMissing；歼灭`:133`、争夺`:285`、推车`:472` 都调用 | `scripts/combat/BattleController.lua:134` 只有 elimination 调呼吸维修；`scripts/combat/BattleObjectives.lua:133` 争夺仅基地维修、`:140` 推车仅攻击方车旁回血 | 竞技控制器/目标，B/W/U09 |
| LA06 / P2 | 已确认旧版剧情 HUD 分叉：武器槽仍旧右上220×54，缺新版右上火控和速度进度；仍在准星下显示旧长句 | `源/shared/css/new-ui-reticle.css:4`/`:16`/`:22` 明确剧情同新版；`源/shared/ui/reticle.js:439` _chips 同新版；源 CSS 隐藏 dh-cross-hint | `scripts/ui/ReticleState.lua:54` Chips(story) 另走旧布局；`scripts/ui/ReticleWeapons.lua:9` 实际传 story；`scripts/ui/ReticleGauges.lua:45` if not story 隐藏速度/火控；`scripts/ui/MechReticle.lua:17` 剧情长句仍显示 | root 公共 HUD，G2/U09 |
| LA07 / P2 | 已确认旧版剧情导弹冗余读数：MSL SEEKER/充能/齐射数仍重复显示，和统一 HUD 去噪不一致 | `源/shared/css/new-ui-reticle.css:28` 隐藏 seek text.zl 与 enmsg，所有模式适用 | `scripts/ui/MissileHud.lua:38` 剧情显示 MSL SEEKER/阶段文字，`:44` 显示齐射x/y | root 公共 HUD，U09/W |
| LA08 / P2 | 已确认缺失：顶部罗盘未接任务目标，缺目标菱形、名称/距离、高低箭头和超范围左右提示。剧情现有屏幕目标菱形不能替代这一独立导航通道 | `源/three/src/drive/testDrive.js:1316` _waypoint，`:1479` 传准星；`源/shared/ui/reticle.js:528` _compass(yaw,wp)，`:543` 起画目标 | `scripts/ui/ReticleGauges.lua:61` Compass 只画航向；ui/story 全扫描无 waypoint 实现。`scripts/ui/MissionHud.lua:33` 屏幕投影标记存在，但不是罗盘导航 | 公共 HUD + MarkerRules，U09/S/M |
| LA09 / P2 | 已确认旧字体路径：伤害跳字数字仍用旧工业标题字；准星数字已切 Chakra 不等于所有局内数字已统一 | `源/shared/css/new-ui-reticle.css:38` 至43包含 `#driveHud .dh-pops span`，最终字体 VoxHudNum→VoxIndustrial、无斜体/无合成 | `scripts/ui/DriveFeedback.lua:24` DamagePop 固定 vox-title（SourceDraw将其加载为VoxIndustrial），独立于已修 ReticleDraw | 字体/HUD专线，U01/U02/U09 |
| LA10 / P2 | 已确认追踪文档过期：开发导航里的基线文件与权威清单不一致，容易继续参考旧快照；不是运行玩法结论 | `docs/migration/outgame-baseline.json:5` 和 CURRENT_EXECUTION 指向2b169/10-09 | `docs/migration/BASELINE_2026_10_14.md:6` 仍0bf472、07-04快照，并声称本轮使用该提交 | root 文档与派生来源，Z01/Z03 |
| LA11 / P2 | 已确认虚构开镜叠层及旧倍率：旧目标隐藏公共准星/武器槽/罗盘，改画黑遮罩和大镜框，所有武器都有额外scope元素；与源开镜样式和倍率不同 | `源/shared/ui/reticle.js:12`倍率mg1.4/laser2.2/missile2.8/sniper5；`:75` scopeSvg非狙击返回空串，狙击仅细线/24点/5.0×与距离；`:693`实际调用；冻结CSS没有按开镜隐藏公共frame | 初审`ReticleState.lua:6`仍laser1.6/mg1.3/sniper4/missile1.5；`MechReticle.lua:12`开镜提前return，Scope另画原版不存在的全武器叠层 | HUD专线g4，U09/C |

LA01 连带影响需同修同验：真实玩家的 HitRay/Explode、零件破坏→Flush→Vehicle/Weapon重绑、结构恢复/Heal通知、5秒默认重生、HUD Life/结构与红边方向、维修扫光/声音以及落界死亡/恢复。不是给 HUD 单独接一个可变血量就关闭。源试车/探索没有据此额外增加“基地回血/5秒脱战回血”模式规则；这些具体恢复触发仍应按源，不能从竞技凭空搬入。

## 逐条验收

所有行均需固定同一新 manifest，分别从真实试车场、自由探索、剧情、歼灭、争夺、推车入口走，PC 与20:9触屏各保留适用记录。自动规则对照与实际画面分开签收。

| ID | 必须执行的步骤与通过条件 |
| --- | --- |
| LA01 | 同一冻结蓝图进入 test/crater；验证世界存在唯一 externalControl player，真实物理命中/爆炸造成 Life下降、指定零件脱落并重建模型/武器；实际 HUD 随之更新。杀核心后禁用驾驶/开火，5秒默认复活并重绑，旧对象不再访问；Backspace复原与N传送保留源差别，退出/重进无双玩家和旧引用。通过源同条件CarUnit事件黄金检查后，再实际观察红边、维修特效/声音与重生。 |
| LA02 | 正常驾驶记录安全位置→开到倒翻/夹墙处→按R；1.2秒前不移动、第二次R取消、完成后4秒内不能再触发。最终落点能容纳整车且坡度合格，不落其他车上。轮车/T5机甲/飞机分别检查；触屏情境翻正必须接相同通道，不能保持立即Flip后仅补动画。 |
| LA03 | 结构化断言所有 MATCH_MODES 参数与源相等；争夺/推车真实死亡后14.9秒仍死，达到15秒首次可复活，HUD倒计时按实际规则；歼灭回合内不复活保持。模式卡8秒保留源文案，内部矛盾单独记录，不擅自重写。 |
| LA04 | 源/目标相同蓝图、位置和高度：小车中心距站点20米可占；车身压圈、中心在圈外的大车能占/推；大车COM高于8米但在8+radius内仍有效；完全离开车体容差或高度超限无效。两队同时在圈、上下层桥面、死亡单位不计数；画面圈与规则同22米。 |
| LA05 | 三竞技模式相同损伤与被打掉零件：离开基地/车旁，4.9秒不回、5秒后15%/秒，.5秒恢复节拍及3%耐久预算正确；新命中重置等待。歼灭决胜禁维修、争夺基地额外.4秒恢复、推车攻击方2%近车回血分别对照源组合顺序，不用一套通用回血抹掉模式规则。 |
| LA06 | 同装备/武器选择/就绪/冷却/能量耗尽/被挡住状态，在试车/自由/剧情同viewport截图并排；除任务专属面板外，武器槽位置尺寸/速度轨/火控文案一致，无旧中心长句；PC与20:9分开检查。 |
| LA07 | 剧情导弹搜索、锁定、开闸、齐射、装填各状态：冗余旧标签不存在，右上新版火控仍传达相同信息；搜索框/锁定进度功能与普通模式一致。 |
| LA08 | 剧情目标正前/左后/右后/高于4米/低于4米/目标切换；核菱形、距离、高低箭头、左右边缘提示以及中心航向避让；目标不存在或演出隐藏时不残留。 |
| LA09 | 实际打出普通/大伤害/穿甲/抵抗/击碎/击杀六类跳字；分别量英文数字Chakra与中文工业字、字号/描边/基线/时序；同状态原图并排，不以截图有字代替一致。 |
| LA10 | 权威文档与导入器都指同一冻结commit/snapshot，旧文档明确历史身份；每份派生资源分别比较实际内容再更新来源，禁止仅批量替换commit标签。 |
| LA11 | 四种武器各自开/关镜，实测倍率分别1.4/2.2/2.8/5.0；公共准星、罗盘、武器槽和火控保留。非狙击没有虚构大框；狙击仅源三段细线/24点/倍率与实际距离。PC/20:9分别截图对照，不把“车体不漏出镜框”旧检查当作UI一致通过。 |

## LA03–05 后续修复检查点

- 已授权实施竞技专项；规则、数据和22米显示圈候选已完成，细节见 `LA03_05_ARENA_PROGRESS.md`。
- 新工具直接执行冻结JS原函数/原模式类生成72个区域、36个恢复场景；原生真实CarUnit/Bullet及实际武器装配首次检查158/158功能PASS。
- 首次运行100ms门槛仍整体FAIL：195.305/597.041ms两次尖峰，不当成性能通过；原证据保留。
- 扩测162/162功能PASS：实际WorldState双队/死亡/圈外/高度边界、AI22米目标及真实ObjectiveView顶点22米均通过；整体仍FAIL，214.179/654.305ms两尖峰，详见专项进度。
- 历史11e3cbe9未包含本专项；当前561已包含，但真实三竞技模式完整流程、PC/20:9画面及性能验收仍未全部关闭，LA03–05继续OPEN。

## LA06–09/LA11 并发修复检查点

- HUD专线g4已恢复公共剧情槽位/速度与火控、隐藏源CSS已隐藏的导弹冗余文案、补任务罗盘导航、改伤害数字字体及LA11开镜倍率/元素，当前561已包含；历史11e3不能据此宣称已修。
- 源真实JS执行夹具：`tools/migration/source-hud-unification.json`，54导航/12槽位/4开镜场景，由g4持有。
- 首轮原生611/622，缺资源4，原FAIL保留；夹具引用不存在图标及半倍率SVG边缘提取有误。后续701/701后继续修紧凑比例及源坐标，最终752/752功能PASS、Lua/resource0，整体仍FAIL：9次100ms尖峰，最大493.563ms。g4已查看原生及部分561真实Web图；源VM54导航/12槽位/4开镜通过。详见`LA06_09_HUD_PROGRESS.md`，Web全部同状态及移动缩放未全CLOSED。
- 当前候选位置：`ReticleState.lua:54`统一Chips；`ReticleGauges.lua:62`公共Compass并调用ReticleNavigation，`:53`开镜火控原位置；`MechReticle.lua:7`公共frame、`:46`狙击专有Scope。精确新包行号及证据由合并时重新核对。

## 已对齐或不能误报为旧版

| 项目 | 本次核对结果与边界 |
| --- | --- |
| 共用准星字体 | `ui/ReticleDraw.lua:27` 已统一用Chakra/Industrial，不再按story换字体；仍有描边近似和平台着墨差异需视觉验收，不应说整个准星仍默认字体。 |
| 驾驶详情/底部长键串 | `ui/DriveHud.lua:64` 已挂新DriveReadouts；旧Chrome keys和weapon卡最后显式隐藏。死路径仍有代码不等于用户看得到旧版。 |
| 教程派生数据 | Node直接导入冻结 `shared/story/tutorial.js` 并按原导入器转换：16条steps内容全等、FLOWS全等；script SHA为 `19980997a549df6fbfff96f32e3df8f40c29a86c763081cf2604aae00de3a961`，与Tutorial.json metadata SHA相等。旧commit标签0bf472属于来源记录未刷新，**没有据此证实教程内容旧版**。 |
| 剧情呼吸维修 | 源 `storyMission.js:34`/`:307` 与目标 `story/Mission.lua:139` 均5秒等待、15%/秒、.5秒RestoreMissing。目标 `combat/CarUnit.lua:140` 已实现至少补整车耐久3%，并非永远每次只补一个实体；不能将调用RestoreMissing(1)误报为少修零件。自然完整场景表现仍待验。 |
| 陨坑边界 | `render/BoundaryFx.lua:23` 和TrialSession实际接入已存在，视觉墙到200米；`drive/CraterPhysics.lua:34` 物理墙抬至260米；源视觉也到CEILING.y=200，不应把200/260不同当旧版。全路段/飞机自然越界未在本次重验。 |
| 最新五关数据 | `assets/Story/Mission/Level1..5.json` metadata均2b169；不能仅凭metadata签全部任务一致，本次没有逐句/逐状态重导验证五关。 |
| 竞技CONQUEST/ESCORT常量 | Node直接比较 `Arena.json.conquest`、`.escort` 与冻结导出，两组全等；但上表的MATCH_MODES复活参数真实不等，且控制器inPoint/breathe另有遗漏。 |
| 友敌基础标记 | `ui/DriveFeedback.lua:49` 已有红敌青友/分段血条/距离，不能写“全部没做”。源reticle._marks另外有掉血白残影、低血闪烁、敌方百分比和命中闪白；目标此路径缺这些状态，列入后续视觉专项，不以基础双色等同完整效果。 |

## 待进一步证实

- `assets/Combat/Arena.json`、FlowSounds.json、Radio.json来源标签仍10月13日。Arena部分参数已证实内容旧；其所有预制车、AI tuning、台词和音频内容尚未全量逐项比较，不能把标签旧扩大成三份全部旧。
- `tools/migration/import-battle-source.mjs:7` 正确读取冻结snapshot，但Arena实际仍留旧参数，属于派生文件未重新导出；应先输出dry-run结构差异再定向更新。`tools/migration/import-ui-source.py` 主体仍读取 `D:/Rino_Project/Vox/shared` live目录，而新帮助导入器读取冻结基线，工具间存在来源漂移风险；本次没有据此判定全部字体资产旧，也没有运行会覆盖大量资源的重导。
- `SourceDraw`/NanoVG与浏览器CFF字体着墨不同、SVG stroke缺原生等属于渲染实现差异；必须记录可见误差及替代方案，不能伪装成源码版本差异或随意加粗。
- 已有G1真实物理量测仍有GT转角/质心、履带加速距离差异。它们是已记录的引擎映射/手感问题，尚不能从本次静态代码判定为旧版控制器。
- 未重新全面穷尽全部武器/模型/动画/碰撞分组、地图所有道路/边界、AI每状态、五关与Boss自然通关、结算/片尾、开篇音频、无尽全阶位、打捞成功撤离、存档账号刷新/跨设备和真机持续性能。138主验收项仍以总账本为准，本报告不能关闭这些项。
- CURRENT_EXECUTION已登记的自然开篇PCM卡顿/连续换图OOM/打捞敌人依赖漏载仍是有效未关闭问题；无需为本次审查重复冷启动调查，也不能因本报告未重新跑而隐藏。

## 快速复核新增确认 LA12–15

本批新增4个正式验收ID；其中LA12是首批备注已提到的头顶标记缺口，本轮补足精确引用和独立验收，不伪称四项都是首次发现。其余三项为新增独立确证。范围仅现有模式共享HUD/聚焦，未扩审全项目或重开G0。

| ID / 严重度 | 确认遗漏及影响 | 冻结源证据 | 当前561/工作区证据 | 独立验收 |
| --- | --- | --- | --- | --- |
| LA12 / P2 | 普通头顶标记缺伤害白残影、敌低血220ms闪黄、命中闪白和敌耐久百分比；已有友敌双色及分段血条不能替代这些状态 | `源/shared/ui/reticle.js:567` _ghost；`:590`至597消费ghost/low/hit/pct；`:162`至166定义lost白、dim黄、hit文字白 | `scripts/ui/DriveFeedback.lua:47`至59只有当前Life阈值单色10段、名字和距离；`scripts/ui/DriveOverlay.lua:90`至104更新tags未保存ghost或命中闪白状态。ReticleTarget的focusGhost只属于聚焦框，不能补普通tags | 同一非聚焦敌车连续打伤，核掉血白残影延迟回落、30%以下220ms闪黄、刚命中名字闪白、敌百分比；友车不显示敌百分比；PC/20:9同状态并排 |
| LA13 / P1 | 开镜聚焦挑选/保持未迁移：准星稍微偏离敌车时不会按原屏幕范围挑选，已有aimRef的.5秒短暂保留不足以实现源焦点保持 | `源/three/src/drive/testDrive.js:1545` _focusPick：13%屏高挑最近、已有目标25%屏高内保持、挑选距离1000米；`:1564` _aimTarget在scope且直接aimRef无有效敌车时调用并保存focusRef | `scripts/ui/ReticleTarget.lua:8`至14仅aimRef/导弹lock及focusHoldTime=.5，无scope挑选；`scripts/controls/DriveAim.lua:11`至14仅原AimAssist输出aimRef，未实现独立focusPick。全controls/TrialSession没有focusPick或focusRef通道 | 无直接射线命中时开镜，敌人在0.12h范围能挑选；保持后移到0.24h仍同目标，超过0.25h重新选择或退出；远于1000米不新选、友军/死亡排除，普通开镜和导弹锁定分开核 |
| LA14 / P2 | 聚焦目标牌漏武装数量与警告、低血状态；目标减少武器后没有源“武装×n”与≤1黄色提示，低血不按源闪黄 | `源/shared/ui/reticle.js:650`至658绘制arms数量、arms<=1 warn、hp<.3 tlow与220ms闪烁；`:176`定义lost/低血黄/warn色 | `scripts/ui/ReticleTarget.lua:31`计算arms=#ref.spec.weapons，但`:58`至69实际Render只画名字/血条/距离/HULL，未读取f.arms、未按低血改变目标牌状态。已有focusGhost白残影保留，不能误报完全没做聚焦血条 | 目标多武器→击掉至1/0件，文字和黄警告随重建后的spec变化；Life低于30%按220ms闪黄，白残影仍正确，原HULL与距离不挪位 |
| LA15 / P2 | 开镜图层顺序与原版相反：现scope后画，会盖过公共frame；窄横屏RNG与EN原版接近同基线，不能靠擅自挪位置掩盖顺序差异 | `源/shared/ui/reticle.js:219` constructor先svg.scope再svg.frame；`:101`两者同绝对定位，frame由后绘制覆盖scope | `scripts/ui/MechReticle.lua:12`至16先Gauges/Compass/Weapons/Center，最后Scope，scope覆盖共享frame | 同原PC和20:9狙击镜截图，保持源坐标/倍率，仅核scope在frame后方、冲突像素由frame覆盖；不把源已有近基线位置当迁移bug另改布局 |

LA12不是死CSS：源 `three/src/drive/testDrive.js:1585`实际遍历场上单位，`:1596`输出`hit: time-u.hitAt<.15`，`:1478`将marks传给共享准星。LA15由g4独立复核同一source/target绘制顺序；源窄横屏RNG/EN近基线几何重叠是原版自身布局，不加新“位置错误”项，也不建议擅改坐标。

未新增确认：试车/自由玩家链、R安全重置、竞技恢复、剧情公共槽位及scope倍率已有LA01–11和实际修复证据，未重复算新项。地图全部碰撞/五关任务自然流程/相机全载具物理差异本轮没有新精确证据，继续原OPEN，不推断旧版。此轮没有动生产或运行浏览器/原生。

## 修复顺序

先统一LA01玩家链与LA02安全重置；竞技数据/规则LA03-05可由独立负责人并行；公共HUD/font/navigation/scope LA06-09及LA11单独并行。统一包后按上表真实入口验收。LA10和派生资源清单随修复补齐，不能只改基线标签掩盖实际残留。
