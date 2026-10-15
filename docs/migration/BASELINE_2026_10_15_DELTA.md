# 10月15日基线升级差异与迁移影响

审计时间：2026-10-15。该报告只读源和目标生产，不代表新基线已激活或新内容已迁入。旧破坏测试原样保留，旧基线验收结果不得挂到新包。

## 1. 身份与范围

- 源仓库：`D:/Rino_Project/Vox`。
- 新分支：`2026-10-15`；已现场核对 HEAD 与 origin/2026-10-15 均为 `b276064942ae09c0227ec28d4cfda1d5ff006455`。
- 对比旧提交：`2b169a9964645f5f346a7158bcb14447f040814a`。
- 源工作区仅有未跟踪 `.claude/worktrees/`，不纳入基线，没有切分支、fetch、启动游戏或修改源。
- 两棵 Git tree 完整差异：185 文件，4929 行增加、41 行删除。README 1、根 index.html 1、art 55、review 85、shared 27、three 3、tools 13。
- 新提交是 merge：第一父 `faae6485f47f0abdb0ae7ef16fa117c898b0bc22`，第二父 `e22b3e3a02c4cd312f0f7b9f3bc5e0788621c210`。本审计对比最终合并 tree，包含另一支的新车与物理修复，没有只看 first-parent。
- 旧冻结快照：`.tmp/outgame-source-2026-10-14T10-09-50-505Z`。另做运行源码规范化换行比较：shared 与 three/src 的 JS/CSS/JSON、three/index.html、three/manifest.webmanifest 共23个语义内容变更/新增，与本报告源码项吻合。原始字节 hash 出现778个差异，其中大量只是文本换行，不能据此宣称778处逻辑变更。
- 目标审计时 Catalog 为311项、Prefab.keys 为16辆；新源 PART_LIST 为331项。目标仍为待升级状态，以下“缺失”是本次检查时实况。

## 2. 来源提交

| 代号 | 完整 sourceCommit | 内容 |
| --- | --- | --- |
| C-PHYS | `ffd43f200c480e19b17b22f77676cdd031ecf045` | 只合并单格重量相近的碰撞格 |
| C-FOX | `f4dd0f24548345198425bb2305ca998573c8dacb` | 九尾狐背炮换追踪飞弹 |
| C-CARS | `3640b8d64dbc9dd8af39f270d10993fbd91883ba` | 蝠鲼、鼠、蟑及工坊 |
| C-MERGE | `e22b3e3a02c4cd312f0f7b9f3bc5e0788621c210` | 保留另一支新车并接最新局外 shell |
| C-MUSIC | `5f0bc4024d3edb7ef309f4fe19bb40f38892d4b9` | 音乐听审归档 |
| C-BRAND | `faae6485f47f0abdb0ae7ef16fa117c898b0bc22` | 构装纪元 CONSTRUCT ERA 更名 |
| C-HEAD | `b276064942ae09c0227ec28d4cfda1d5ff006455` | 最终 merge，作为统一新基线 |

## 3. 逐项影响与验收

### D01 / P0：碰撞盒按质量限制合并，目标尚无

- 源：`shared/drive/vehicleSpec.js:118`，C-PHYS。以当前起始格质量 m0 为参考，候选须满足 `m <= m0*2 && m*2 >= m0`；边界恰好2倍仍可合并。外循环必须独立检查是否存在并重新赋 m0，不能把上一个种子的质量条件误用到下一个种子。
- 目标：`scripts/drive/VehicleSpec.lua:84` 的 MergeBoxes/Has 仍仅查占格，没有质量条件。
- 运行影响：重车身格与长条轻装饰被合并时，盒子用几何中心分配质量，导致整车 COM 偏移；源提交说明蟑头胸甲曾让重心前移1.2m、停下前栽。会影响驾驶、刹车、落地与损伤重建，不能仅当模型问题处理。
- 迁移：保留现有协程 checkpoint 和拓扑/装配规则，仅对齐源 Has/m0/外循环语义。不需要重导三角网格；已有物理黄金夹具须以新源重生并保留旧结果。
- 验收：等质量、0.5/2倍边界、超2倍、轻重相邻长条、零质量等实际源用例逐盒 center/half/mass 对比；蟑/九尾狐的 native COM、停车与受损后重建再测。不能用测试数量替代真实驾驶手感。

### D02 / P0：新增三辆车及20个整件装饰，目标缺失

所有源路径与 C-CARS：

| 车 | 蓝图 / 占格连接数据 / 运行GLB / 工坊图 | 真实蓝图装配 | 新装饰ID |
| --- | --- | --- | --- |
| manta 蝠鲼 | `shared/build/mantaData.js`；`shared/parts/mantaData.js`；`shared/assets/manta/manta.glb`；`shared/assets/ui/prefabs/manta.jpg` | 408件，hover3×6、laser3×2、missile3×1 | mtBack、mtHead、mtWingL、mtWingR、mtTail1、mtTail2、mtTail3 |
| rat 鼠 | `shared/build/ratData.js`；`shared/parts/ratData.js`；`shared/assets/rat/rat.glb`；`shared/assets/ui/prefabs/rat.jpg` | 162件，steer2×2、drive2×2、sniper2×1 | rtBack、rtHead、rtFlankL、rtFlankR、rtTail1、rtTail2、rtTail3 |
| roach 蟑 | `shared/build/roachData.js`；`shared/parts/roachData.js`；`shared/assets/roach/roach.glb`；`shared/assets/ui/prefabs/roach.jpg` | 163件，track2×2、laser2×1 | roHead、roTail、roElytraL、roElytraR、roSideL、roSideR |

- 公共注册：`shared/parts/decorVehicles.js:82`、`shared/parts/defs.js:551`、`shared/build/prefab.js:9` 和 `:70`；目标 `assets/Parts/Catalog.json`、`assets/Parts/Rigs/`、`scripts/construction/Prefab.lua:3` 均缺相应条目；三张目标 `assets/UI/Prefabs/{manta,rat,roach}.jpg` 也不存在。
- 不只是渲染：每件 cells、base、mass、hp、all sockets、decorVehicle、涂装材料必须随模型导入，否则会发生装配/连通/破坏/质量差异。源三车是不同移动方式，必须复用现有悬浮、轮式、履带系统。
- 源 decorDefs 对全部新外壳仍给 `unlock:'T5'`、budget0，虽然车的工坊标签是T3/T2。该事实需保留，不能擅自把外壳解锁阶位改为车阶位。
- 现有 `tools/migration/export-parts.cjs:96` 已通用遍历 DECOR_VEHICLES；但 `:110` 的预制builder白名单没有 buildManta/buildRat/buildRoach，原样重导会缺三车蓝图。需补导出白名单及 Prefab.keys。
- 需派生：20个零件rig与其实际model bins、Catalog新定义/新预制；检查 Drive/Geometry、依赖JSON是否实际变化，仅复制变更文件；新零件UI缩略图与新工坊原图/Filtered卡图。
- 验收：331定义与20件占格/底面/材料/精确包围盒对照；三个公开工坊卡→详情→创建→建造→试车→受损掉件→保存重载；各车武器数与移动类型核对；PC与20:9实图。只导出成功不算完成。

### D03 / P1：工坊列表、描述及展示统计，目标旧版

- 源：`shared/ui/workshop.js:30` C-CARS；`shared/ui/shell.js:9`、`:29` 最后改动C-MERGE；`shared/ui/prefabStats.js:114` C-CARS。
- 目标：`assets/UI/Workshop.json` 仍16车，fox介绍仍写狙击；`scripts/ui/Workshop.lua` 已按数据数组绘制/筛选/详情分页，但新Prefab.keys尚缺。
- 源货架顺序：scorpion、fox、trooper、manta、rat、roach、miniAssault、miniScout、miniHeavy，再是原后续项；新增manta/mech、rat/wheel、roach/track分组。主页“更多”、车数、分类计数及货架前5张图片随顺序改变。独立的 FEATURED 轮播仍是 scorpion、fox、trooper、hawk、raceCar、megaMech、vanguard、tianyuan，没有插入新三车。
- 源展示数据与真实蓝图不能混为一套口径：

| id | 源展示 parts | tier | speed | weapons | mass | 实际完整parts |
| --- | --- | --- | --- | --- | --- | --- |
| manta | 401 | 3 | 78 | 3 | 2532 | 408 |
| rat | 155 | 2 | 84 | 1 | 981 | 162 |
| roach | 157 | 2 | 49 | 1 | 1022 | 163 |
| fox | 2202 | 5 | 80 | 3 | 12914 | 2227 |

- parts差值恰为装饰件数量。忠实沿用源UI统计与源装配，不能用“修数字”改变源页面。
- 验收：19车货架顺序/分组/文本/统计逐项核对，货架第四第五张为 manta、rat，FEATURED 轮播保持源版8车顺序，过滤卡图不漏；公开创建三车可用且无空模型。

### D04 / P1：九尾狐背炮狙击改飞弹，目标仍狙击

- 源 C-FOX：`shared/build/foxData.js:2`、`shared/assets/ui/prefabs/fox.jpg`；`shared/ui/workshop.js:31`、`shared/ui/prefabStats.js:85`。工具链同步 `tools/fox.mjs:113`、`tools/prepare-scorpion.mjs:14`、`art/fox/build_fox.py:26`、`art/fox/fox_decor.py:516`、`art/fox/fox_export.json`、`art/fox/fox_guns.json`。
- 实际唯一装配武器变化：`sniper5@{0,27,-3},rot10` → `missile5@{0,27,-3},rot10`；两侧laser5保留，完整蓝图仍2227件。源展示质量12869→12914。
- 目标 Catalog.buildFox 仍sniper5同位，Workshop.desc仍旧。目标fox卡图SHA256 `451379c64f8e19dfd65dc583dfca938575d4303b56e6457e0fe0364c23c5dd10`；新源卡图 `679a88c82d8fdbf453dadaa60d1c2e00368a798ebe2f2068a362bd463cf51e27`。
- 重要边界：`shared/assets/fox/fox.glb` 两提交 Git blob 完全相同 `365e755c5e1ebea324b22c696820c3f36b7655c5`；fox占格数据也未变。因此无需重制狐壳、重导其全部壳模型或改武器尺寸，只更新蓝图/卡图/文字统计及真正受影响的派生。
- 验收：新建fox精确导入missile5、两laser5；背部弹舱、锁定/发射/弹药HUD/声音走现有飞弹逻辑；旧玩家自存fox保持自存内容，禁止全库强制改装。

### D05 / P1：游戏更名，目标仍旧文案

全部 C-BRAND：

| 精确源路径 | 变动 | 对应目标现况 |
| --- | --- | --- |
| `shared/ui/home.js:131` | 主页方块战车→构装纪元 | `scripts/ui/HomeChrome.lua:22` 仍旧名 |
| `three/index.html:10`、`:13`、`:137` | 苹果桌面名、网页title、启动页标题 | `scripts/ui/BootLoading.lua:36` 仍旧名；包网页title另归root发布入口核查 |
| `three/manifest.webmanifest:2` | name/short_name | 平台/打包元信息需单独核对，不靠Lua自动同步 |
| `shared/controls/touchControls.js:104` | 横屏提示新名 | 目标未找到该新名；只替换对应横屏提示，不新增竖屏布局 |
| `three/src/main.js:1`、`:93` | 注释与预加载标题字体字符集 | `scripts/app/HangarApp.lua:177` windowTitle仍旧名 |
| `shared/ui/perfMeter.js:84` | 性能报告标题 | 目标性能报告应跟统一品牌 |
| `index.html:6`、`:24`；`tools/site-build.mjs:60`、`:64`；`README.md:1` | 源入口/重定向/文档名 | 不原样复制H5引擎选择页到UrhoX；目标真实入口元信息对应更新 |

验收：主页、启动页、原生窗口、Web标题、横屏提示和打包名称分别检查；不全局替换资源ID、存档key、函数名或历史证据中的Vox。

### D06 / P1：机库品牌牌与自动缩字，需局部重导/逻辑同步

- 源 C-BRAND：`shared/scene/hangarTextures.js:49` 新fitFont，`:61` HANGAR_NAME = CONSTRUCT ERA 轨道改装机库；`:85` 地面牌、`:136` 墙牌、`:167` glowSign统一按可用宽度缩字号，保持完整文字不截断。
- `shared/scene/hangarLayout.js:237` signBack两行更名；`shared/scene/textures.js:551` signTexture中文/英文更名。
- 目标 `scripts/render/HangarBaySigns.lua:19`、`:32` 仍VOX，`scripts/render/HangarCanvas.lua:44` Fit用省略号，不能拿该截断算法代替新源fitFont。
- 需检查重导 `assets/Hangar/signBack.png` 及实际被场景引用的对应牌纹理；动态Bay/Mark直接改其文字与缩字绘制。signDoor源文本未改，但glowSign共用fitFont可能改变过宽行，因此stage做像素/hash差异后判断。无建筑几何变化，禁止全机库模型重写。
- 源signTexture是否被当前有效场景使用，需按实际调用/manifest确认；未使用的不凭文件存在就添加新场景牌。
- 验收：地面、墙牌、背部发光牌各一张原比例实际图，完整英文不出界、源字体和字重保持，动态换车位不回旧名。

### D07 / P2：新车离线制作和检查工具

- C-CARS精确工具：`tools/manta.mjs`、`tools/manta-glb.mjs`、`tools/rat.mjs`、`tools/rat-glb.mjs`、`tools/roach.mjs`、`tools/roach-glb.mjs`、`tools/decor-check.mjs`、`tools/weapon-glb.mjs`。
- 公共工具：`tools/bp-glb.mjs:15` 与 `:33` 加悬浮GLB注册；`tools/mega-mech-glb.mjs:37` 把hover/wheel/track纳入legs分组供穿模检查。
- art/manta、art/rat、art/roach各17项制作源，art/fox四项更新；附录列全路径。Blender/渲染图/导出cfg是制作证据，不应打入游戏启动组。
- 三份check_report均写武器无穿模、无浮空、炮座留空；同时保留若干装饰件与自身炮座/尾节交叠记录，源export_cfg有boss合并映射。不能把该美术报告当UrhoX装配/碰撞/性能PASS。
- 目标无需复制全部art工程才能使用已提供GLB。已有export-parts通用decor注册能复用；悬浮注册也已具备，无需重复造一条模型管线。

### D08 / P3：音乐试听归档，不能误当游戏音乐更新

- C-MUSIC新增85个review文件，精确全路径见附录：music-audition-20-22、23-24、25、26、27-28、29、30、31、32，prompt-research-2026-10-14及vocal-direction-2026-10-14。
- 两提交差异没有修改 `shared/audio/musicBoxCatalog.js`、`shared/audio/musicQueue.js`、`shared/audio/musicPlayer.js` 或运行音频资源目录。
- 因此是候选/试听/来源记录，不应全部迁进游戏音乐盒、启动下载或发布包，也不能说新基线更换了音乐播放逻辑。只保留来源可追溯，正式接入需以源运行引用为准。

### D09：这次没有新增的系统差异

- `shared/combat/`、`shared/story/`、`three/src/battle/`、`three/src/drive/testDrive.js`、`shared/ui/reticle.js`、`shared/ui/storyPage.js`、`shared/build/editor.js` 在两提交tree差异中没有变更。
- 不能由此推导目标这些模块已经1:1；既有LA/LB/G0-G6缺口继续保留。该事实只说明本次升级不需要把这些全部从零重迁。
- 全部模型、驾驶、战斗、UI旧证据保留原commit/manifest；新源发生的D01-D06需新证据，不篡改旧PASS归属。

## 4. 建议实施顺序与逐项关单

| 顺序 / ID | 必须交付 | 可核验通过条件 | 当前状态 |
| --- | --- | --- | --- |
| 1 / B15-01 | 固定b276快照和hash；统一导出器输入 | 每个派生文件标明新sourceCommit及输入hash；不可混用活动旧baseline | 审计完成，激活由root统筹 |
| 2 / B15-02 | D01质量合盒 | 原JS→Lua盒数组/质量一致；保留checkpoint；实际COM/驾驶复验 | 目标缺失 |
| 3 / B15-03 | D02三车20件与D04狐换炮 | stage差异白名单；331定义、19预制；未变模型hash不变；旧玩家蓝图不被重写 | 目标缺失 |
| 4 / B15-04 | D03工坊数据与图片派生 | 19车顺序/分组/统计/详情/创建/筛选图齐全；PC/20:9实图 | 目标旧数据 |
| 5 / B15-05 | D05-D06品牌/招牌 | 真实入口/动态牌/烘焙牌对照；长英文完整缩字 | 目标旧数据 |
| 6 / B15-06 | 同一新包回归 | 三车公开建造/试车/损坏/存档、狐飞弹、物理和UI；帧时间/下载变化实测 | 未运行 |

本报告没有启动浏览器/native，没有修改目标生产，没有提交Git，没有声明真实性能或1:1通过。后续迁入时先stage、列差异，只写确认变更，不删除未知资产。

## 5. 完整Git文件清单

下表直接来自 `git -c core.quotepath=false diff --name-status 2b169a9 b2760649`。A/M仅表示新源Git状态，不表示已迁入目标。

| 状态 | 精确源路径 |
| --- | --- |
| M | README.md |
| M | art/fox/build_fox.py |
| M | art/fox/fox_decor.py |
| M | art/fox/fox_export.json |
| M | art/fox/fox_guns.json |
| A | art/manta/build_manta.py |
| A | art/manta/check_clip.py |
| A | art/manta/check_report.txt |
| A | art/manta/export_cfg.json |
| A | art/manta/manta.blend |
| A | art/manta/manta.json |
| A | art/manta/manta_decor.py |
| A | art/manta/manta_export.json |
| A | art/manta/manta_guns.json |
| A | art/manta/manta_sweep.json |
| A | art/manta/render_front.png |
| A | art/manta/render_hero.png |
| A | art/manta/render_low.png |
| A | art/manta/render_rear.png |
| A | art/manta/render_side.png |
| A | art/manta/render_top.png |
| A | art/manta/run.sh |
| A | art/rat/build_rat.py |
| A | art/rat/check_clip.py |
| A | art/rat/check_report.txt |
| A | art/rat/export_cfg.json |
| A | art/rat/rat.blend |
| A | art/rat/rat.json |
| A | art/rat/rat_decor.py |
| A | art/rat/rat_export.json |
| A | art/rat/rat_guns.json |
| A | art/rat/rat_sweep.json |
| A | art/rat/render_front.png |
| A | art/rat/render_hero.png |
| A | art/rat/render_low.png |
| A | art/rat/render_rear.png |
| A | art/rat/render_side.png |
| A | art/rat/render_top.png |
| A | art/rat/run.sh |
| A | art/roach/build_roach.py |
| A | art/roach/check_clip.py |
| A | art/roach/check_report.txt |
| A | art/roach/export_cfg.json |
| A | art/roach/render_front.png |
| A | art/roach/render_hero.png |
| A | art/roach/render_low.png |
| A | art/roach/render_rear.png |
| A | art/roach/render_side.png |
| A | art/roach/render_top.png |
| A | art/roach/roach.blend |
| A | art/roach/roach.json |
| A | art/roach/roach_decor.py |
| A | art/roach/roach_export.json |
| A | art/roach/roach_guns.json |
| A | art/roach/roach_sweep.json |
| A | art/roach/run.sh |
| M | index.html |
| A | review/audio/music-audition-20-22/listening-decisions.json |
| A | review/audio/music-audition-20-22/prepare.mjs |
| A | review/audio/music-audition-20-22/provenance.json |
| A | review/audio/music-audition-20-22/raw/20-orbital-service-shift-a.mp3 |
| A | review/audio/music-audition-20-22/raw/20-orbital-service-shift-b.mp3 |
| A | review/audio/music-audition-20-22/raw/21-armored-sideslip-a.mp3 |
| A | review/audio/music-audition-20-22/raw/21-armored-sideslip-b.mp3 |
| A | review/audio/music-audition-20-22/raw/22-starport-night-shift-a.mp3 |
| A | review/audio/music-audition-20-22/raw/22-starport-night-shift-b.mp3 |
| A | review/audio/music-audition-20-22/requests.json |
| A | review/audio/music-audition-20-22/tracks/20-orbital-service-shift-a.mp3 |
| A | review/audio/music-audition-20-22/tracks/20-orbital-service-shift-b.mp3 |
| A | review/audio/music-audition-20-22/tracks/21-armored-sideslip-a.mp3 |
| A | review/audio/music-audition-20-22/tracks/21-armored-sideslip-b.mp3 |
| A | review/audio/music-audition-20-22/tracks/22-starport-night-shift-a.mp3 |
| A | review/audio/music-audition-20-22/tracks/22-starport-night-shift-b.mp3 |
| A | review/audio/music-audition-20-22/validation.json |
| A | review/audio/music-audition-20-22/试听说明.md |
| A | review/audio/music-audition-23-24/requests.json |
| A | review/audio/music-audition-23-24/编排方案.md |
| A | review/audio/music-audition-25/failed-attempt.json |
| A | review/audio/music-audition-25/provenance.json |
| A | review/audio/music-audition-25/raw/25-lightgap-homecoming-a.mp3 |
| A | review/audio/music-audition-25/raw/25-lightgap-homecoming-b.mp3 |
| A | review/audio/music-audition-25/requests.json |
| A | review/audio/music-audition-25/tracks/25-lightgap-homecoming-a.mp3 |
| A | review/audio/music-audition-25/tracks/25-lightgap-homecoming-b.mp3 |
| A | review/audio/music-audition-25/validation.json |
| A | review/audio/music-audition-26/listening-decisions.json |
| A | review/audio/music-audition-26/provenance.json |
| A | review/audio/music-audition-26/raw/26-windowglow-a.mp3 |
| A | review/audio/music-audition-26/raw/26-windowglow-b.mp3 |
| A | review/audio/music-audition-26/requests.json |
| A | review/audio/music-audition-26/tracks/26-windowglow-a.mp3 |
| A | review/audio/music-audition-26/tracks/26-windowglow-b.mp3 |
| A | review/audio/music-audition-26/validation.json |
| A | review/audio/music-audition-27-28/listening-decisions.json |
| A | review/audio/music-audition-27-28/provenance.json |
| A | review/audio/music-audition-27-28/raw/27-captain-says-it-doesnt-count-a.mp3 |
| A | review/audio/music-audition-27-28/raw/27-captain-says-it-doesnt-count-b.mp3 |
| A | review/audio/music-audition-27-28/raw/28-one-light-on-the-fox-a.mp3 |
| A | review/audio/music-audition-27-28/raw/28-one-light-on-the-fox-b.mp3 |
| A | review/audio/music-audition-27-28/requests.json |
| A | review/audio/music-audition-27-28/tracks/27-captain-says-it-doesnt-count-a.mp3 |
| A | review/audio/music-audition-27-28/tracks/27-captain-says-it-doesnt-count-b.mp3 |
| A | review/audio/music-audition-27-28/tracks/28-one-light-on-the-fox-a.mp3 |
| A | review/audio/music-audition-27-28/tracks/28-one-light-on-the-fox-b.mp3 |
| A | review/audio/music-audition-27-28/validation.json |
| A | review/audio/music-audition-27-28/歌词与编排.md |
| A | review/audio/music-audition-29/listening-decisions.json |
| A | review/audio/music-audition-29/provenance.json |
| A | review/audio/music-audition-29/raw/29-channel-takeover-a.mp3 |
| A | review/audio/music-audition-29/raw/29-channel-takeover-b.mp3 |
| A | review/audio/music-audition-29/requests.json |
| A | review/audio/music-audition-29/tracks/29-channel-takeover-a.mp3 |
| A | review/audio/music-audition-29/tracks/29-channel-takeover-b.mp3 |
| A | review/audio/music-audition-29/validation.json |
| A | review/audio/music-audition-29/歌词与编排.md |
| A | review/audio/music-audition-30/listening-decisions.json |
| A | review/audio/music-audition-30/provenance.json |
| A | review/audio/music-audition-30/raw/30-channel-takeover-homecoming-a.mp3 |
| A | review/audio/music-audition-30/raw/30-channel-takeover-homecoming-b.mp3 |
| A | review/audio/music-audition-30/requests.json |
| A | review/audio/music-audition-30/tracks/30-channel-takeover-homecoming-a.mp3 |
| A | review/audio/music-audition-30/tracks/30-channel-takeover-homecoming-b.mp3 |
| A | review/audio/music-audition-30/validation.json |
| A | review/audio/music-audition-30/试听说明.md |
| A | review/audio/music-audition-31/provenance.json |
| A | review/audio/music-audition-31/raw/31-channel-takeover-vocal-priority-a.mp3 |
| A | review/audio/music-audition-31/raw/31-channel-takeover-vocal-priority-b.mp3 |
| A | review/audio/music-audition-31/requests.json |
| A | review/audio/music-audition-31/tracks/31-channel-takeover-vocal-priority-a.mp3 |
| A | review/audio/music-audition-31/tracks/31-channel-takeover-vocal-priority-b.mp3 |
| A | review/audio/music-audition-31/validation.json |
| A | review/audio/music-audition-32/requests.json |
| A | review/audio/music-audition-32/tracks/32-r1-voice-first-a.mp3 |
| A | review/audio/music-audition-32/tracks/32-r1-voice-first-b.mp3 |
| A | review/audio/music-audition-32/tracks/32-r2-best-employee-a.mp3 |
| A | review/audio/music-audition-32/tracks/32-r2-best-employee-b.mp3 |
| A | review/audio/music-audition-32/tracks/32-r3-best-employee-space-a.mp3 |
| A | review/audio/music-audition-32/tracks/32-r3-best-employee-space-b.mp3 |
| A | review/audio/music-audition-32/歌词与编排.md |
| A | review/audio/prompt-research-2026-10-14/mivo-input.json |
| A | review/audio/prompt-research-2026-10-14/提示词调研.md |
| A | review/audio/vocal-direction-2026-10-14.md |
| A | shared/assets/manta/manta.glb |
| A | shared/assets/rat/rat.glb |
| A | shared/assets/roach/roach.glb |
| M | shared/assets/ui/prefabs/fox.jpg |
| A | shared/assets/ui/prefabs/manta.jpg |
| A | shared/assets/ui/prefabs/rat.jpg |
| A | shared/assets/ui/prefabs/roach.jpg |
| M | shared/build/foxData.js |
| A | shared/build/mantaData.js |
| M | shared/build/prefab.js |
| A | shared/build/ratData.js |
| A | shared/build/roachData.js |
| M | shared/controls/touchControls.js |
| M | shared/drive/vehicleSpec.js |
| M | shared/parts/decorVehicles.js |
| M | shared/parts/defs.js |
| A | shared/parts/mantaData.js |
| A | shared/parts/ratData.js |
| A | shared/parts/roachData.js |
| M | shared/scene/hangarLayout.js |
| M | shared/scene/hangarTextures.js |
| M | shared/scene/textures.js |
| M | shared/ui/home.js |
| M | shared/ui/perfMeter.js |
| M | shared/ui/prefabStats.js |
| M | shared/ui/shell.js |
| M | shared/ui/workshop.js |
| M | three/index.html |
| M | three/manifest.webmanifest |
| M | three/src/main.js |
| M | tools/bp-glb.mjs |
| A | tools/decor-check.mjs |
| M | tools/fox.mjs |
| A | tools/manta-glb.mjs |
| A | tools/manta.mjs |
| M | tools/mega-mech-glb.mjs |
| M | tools/prepare-scorpion.mjs |
| A | tools/rat-glb.mjs |
| A | tools/rat.mjs |
| A | tools/roach-glb.mjs |
| A | tools/roach.mjs |
| M | tools/site-build.mjs |
| A | tools/weapon-glb.mjs |
