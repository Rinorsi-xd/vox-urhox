# G3 / G4 当前交付记录

## 当前工作位置（恢复先读）

- 16:06受控4291实验已结束，**FAIL/OOM**，报告`evidence/boss-wing-web-phone-landscape-d6764c9c-concurrency1-lifetime.json/log`已落盘，37项检查通过后在第二次陨坑失败。完整自然片尾8句/4panel/红章/自动回厅及原feather操作已完成。此次下载323/323完成、两组arrayBytes=67,109,584、cache202,301,202后请求堆1,730,871,296，固定堆1,719,533,568无法增长；并发1没有解决OOM。末次真实WasmFS580,417,308字节，其中项目chunk356,323,328；XHR0，主realm OPFS0，但不能推断worker后端。最后Lua38,539KiB、JS堆242,160,619。OOM后F8键盘调用卡住，只关闭本路自建Chrome44092促成FAIL报告落盘，未碰用户Editor43020；wrapper已收尾。当前workerRealms只读诊断为本次启动后新增，本次报告不含该字段，不为它额外冷启动。root接手资源策略；本路停止新增生产/测试释放并发slot，由root新建字体/结构专属任务对照5173。
- 新统一候选`manifest-d6764c9c.json`，快照`.tmp/outgame-cached-1792051106196`，生产脚本`a7028dff4185d6a4915cd887f30231c54ac1429b71bde132310b3542ce193d81`。普通预览4289、默认并发QA4290；本路只在受控QA4291（`loadProfile=true/downloadConcurrency=1`，probe`eb60976f0cab4ad8244e094694cc5a940c6f69dadef84806cf82031eabb5a897`）运行一次20:9完整片尾→wing→crater，exec48747。即使受控实验通过也不能签收默认并发生产OOM；下面6d均为旧包证据。
- 15:49新增Boss HUD原CSS时序（在6d包之后，待下一统一包）：`BossHudMotion`恢复主血条.15s、尾条.8s/.25s延迟、黑边.5s原Bezier、Enter提示.6s延迟、跪地steps(2)闪动、大招淡入淡出及.9s双alpha白闪。`source-boss-hud-fixtures.mjs`读取冻结`BAR_CSS`并生成16时点/112黄金值；`boss-hud-native.json` **121/121功能PASS**、Lua/resource0，34条engine错误全为100ms帧尖峰，最高504.689ms，整体**性能FAIL**。三张damage/letter/ult实际截图均已打开检查；这是实际HUD渲染，不代表全Boss视觉逐像素验收。
- 6d同包20:9连续路线已结束，**FAIL/OOM**：37项检查后，完整自然片尾8句/4panel/章/自动回厅已完成，原feather实际操作通过，第二次陨坑在`download322/323`崩溃，尚未建新地形数组。报告`boss-wing-web-phone-landscape-6d18072e-real-ending-lifetime.json/log`完整保留。最后cache95,427,710字节、arrays0、Lua约33MB；WASM堆固定1,719,533,568字节，JS heap最后206MB。FS探针返回0文件，但接口可见性未确认，不能据此排除文件持有。不能用资源计数下降宣称OOM已修复，也不重复同包旧路线。
- 五关真实入口同6d已依次完成：s1..s5各 **3/3 PASS/errors0**，实际出战→剧情→原关卡→开始任务/实景呈现/live vehicle/退出arrays0，五个浏览器均退出；entry-only明确不是自然五关通关。证据分别为`evidence/story-natural-s1..s5-manifest-6d18072e-2026-10-15T07-*.*/result.json`，s1/s4/s5实际截图已查看，原三行任务横幅和地图均可见。
- 固定源：10月14日 `2b169a9964645f5f346a7158bcb14447f040814a`；最新统一Web候选`manifest-6d18072e`，普通4285 / 统一功能QA4287，生产指纹`7c5a7f028f4eb296c767a1c8bbaaefdb0aea5a20eed6d43b85832383f2acfb58`，快照`.tmp/outgame-cached-1792049068098`。QA4287探针`73e60e574fc59c47fd0929b7aceef21e305030bc0ab43fba773d719e3915eb02`仅修死亡只读probe空访问，实际结果待同包运行。下面8db/935均是旧包证据，不能套入新包。
- 最新功能通过：地图特效真实创建/两次释放 **15/15**；片尾真实Texture2D→NanoVG video桥接/红章/两次释放 **11/11**，Lua与资源错误0。两次分别203/22条100ms尖峰，整体**性能FAIL**；不覆盖旧FAIL。
- 仍失败：8db的20:9 story5→wing→crater连续进图再次OOM；自然片尾8句/4panel/章/自动回厅与wing进入返回已观察，第二次陨坑加载失败。完整五关自然通关、完整自然Boss与真机性能尚未关闭。
- 生产增量已冻结交root打包：地图烟尘/天空材质幂等Dispose、片尾nvgDeleteVideo正确配对；Story接原SalvageExplosion，保留1086节点/原容量，34次构造checkpoint及取消归属。普通Mission原安装/失败/复活/援军/任务完成/选择/情报/夺点/护送检查点cue补齐，Boss共用Mission原radio池避免双倍音源预算。
- `story-explosion-native.json` **495/495功能PASS**、Lua/resource0；33条engine错误全部100ms帧尖峰，整体**性能FAIL**。含冻结原Boss7场景101爆炸位置、15死亡条件/距离、结算/片尾冻结时钟、真实池/取消与Mission cue。前两次QA AfterStep stub缺enemyPositions/host字段的FAIL报告保留，最终没有为此修改生产。
- 最新增量（8db之后）：首关原货舱两盏警报灯/两真实PointLight、原脉冲与exit关闭时机已补；直接执行冻结StoryView的180帧夹具，`story-alarm-native.json` **1085/1085功能PASS**，Lua/resource0，487.745ms启动尖峰使整体性能FAIL。灯强度保留源900，未主张跨引擎光度/视觉已完全验收。
- 后续释放增量：MissionView清掉捕获session的onLand；Boss移除unit覆写闭包并清Mission/session/world引用；Mission与BossView幂等断开父级/native引用。CraterWorld/EnginePitWorld派生Dispose在Base之前检查disposed；首关外Boss货车明确关闭警报。已为真实Boss回厅增加5项引用/幂等断言，待root原生联合验证，不把静态修复当OOM关闭。
- 15:06真实Boss增量回归 **FAIL**：100项通过后玩家死亡/重生路径读取失效Body的`native=nil`，`physics/Body:50`；原报告保留`boss-native-body-invalid-2026-10-15.json`。与g5真实无尽死亡段复现一致，已交root共享物理所有权处理，当前带coroutine traceback复验，不能冻结该清理增量。
- 同批补原三行剧情横幅：Mission/Boss/Capture/Convoy的kick/title/sub/kind/ms全字段、原collector圆号/计数、任务/敌人/阶段/首领文案与时长、三行字体/条带/进场slam+blur+wipe。黄金数据直接执行冻结源22个实际banner调用，并从原CSS提取Bezier生成11时点；待原生实际渲染/真实Mission事件回归，未按静态代码签收。
- 三行横幅增量实际回归`story-explosion-native.json` **514/514功能PASS**、Lua/resource0；50条100ms尖峰使整体**性能FAIL**。新增真实Mission六事件五字段/时长、11原CSS黄金时序和实际橙色像素渲染，`story-banner-native.png`已打开确认三行/圆号②/计数/徽章。首轮513未跑截图的QA注册覆盖报告保留`story-explosion-native-banner-render-not-run-2026-10-15.json`，不将其算实际渲染通过。root已修Reticle死亡读旧body，Boss实际整条生命周期复验中。
- 15:18共享Reticle修复后真实Boss生命周期 **112/112功能PASS**，Lua/resource/engine0（`boss-native.json`，20000ms仅功能门槛，不是性能合格）。原死亡/存档重生、三钻头/三飞机、Boss结束/片尾、实际Reload回厅与新增五项Mission/Boss/View父引用清空及重复Dispose均执行。本路仍是明确QA推进阶段，不冒充自然Boss通关。代码冻结交root统一新包；下一步同包20:9原OOM连续路线一次与五关真实入口/自然操作。
- 下一动作：不重复大路线；先恢复8db OOM日志和查wasm/资源生命周期，再对五关完整Mission协议走自然路线定位阻塞，不以QA改阶段冒充通关。

### 8db 连续进图资源取证

- 原日志`boss-wing-web-phone-landscape-8db734ff-real-ending-lifetime.log`保留423条完整状态及一条截断状态；恢复报告只从原日志读取，不伪造未落盘的检查数。
- 初厅资源52.9MB；story回厅80.9MB（arrays0、Image0、JSON0、Sound7.77MB、Lua39.4MB）；wing回厅95.2MB（arrays0、Image0、JSON0、Sound17.43MB、Lua36.8MB）。再次陨坑最后资源200.1MB（arrays67.1MB、Models52.3MB、Sound17.43MB、Lua37.0MB）后OOM。
- 本路`Platform.IsDesktop=false`、`postPasses=0`，不能归因桌面29pass链。数组两次回零，不据此宣称数组泄漏；资源缓存统计不等于完整wasm堆，Texture2DBytes0也不能证明动态纹理不存在。
- 实时读取4283的Runtime脚本确认固定共享wasm初始/最大均1719533568字节，`abortOnCannotGrowMemory`直接抛OOM。新增纯浏览器`web-memory-probe.cjs`只读HEAPU8与FS文件占用/是否在wasm缓冲，并在下一复验请求扩堆时记录requested/heap/stack；没有更改引擎堆上限或玩法。

### 6d 下载 OOM 只读取证补充

- 实际Runtime使用WasmFS：`FS`没有`root`，旧MEMFS递归没有遍历任何文件，之前0文件必须视为诊断无效。已把只读tool改为`FS.readdir`+`FS.lstat`，不使用会复制整文件的`FS.readFile`或`FS.analyzePath`；500ms/30000节点有界并明确报告截断。不能由WasmFS文件逻辑大小直接判断后端内存，`fileBytesInWasm`保留null。
- 实际下载桥`fetchXHR`保留`Fetch.xhrs.allocated[id]`里的XHR，responseType为arraybuffer。完成回调`saveResponseAndStatus`通过`_realloc(ptrLen)`及`HEAPU8.set`将响应复制到堆，释放点是`_emscripten_fetch_free(id)`；静态代码不能证明C++调用是否及时释放。新增只读XHR数量/响应字节/URL统计，待后续既定五关入口采样；没有改引擎释放函数。
- WasmFS的`FS_writeFile`还会临时`_malloc(len)`、调用`__wasmfs_write_file`、再free，故响应buffer/下载buffer/文件后端可能同时占用。实际全量文件、流式OPFS后端和下载峰值需分别计数，不能把cache的95MB当作完整堆。
- 6d manifest的`assets_pak=0`，不是项目单一总pak解包。启动真实日志下载3428文件/118.5MB；Crater源资源表540项约170,971,943字节，EnginePit371项约86,129,356字节，均不含未知官方Box尺寸。最大Crater文件为`texture-2.png`21,561,575字节、`mesh-280.bin`10,569,956字节；旧路线没有成功请求URL时间线，不能断言最终322/323具体是哪项。
- 用户代码可调接口已在`.emmylua/DownloadManager.d.lua`确认：`SetConcurrency`、`SetStreamThreshold`、`SetCompressionEnabled`、`GetDefaultDirectory`。本路只读未修改它们。WASM下stream不自动等于物理磁盘，只有实际OPFS后端证据才可下结论；不能盲删全局缓存或关压缩掩盖问题。root负责共享资源策略，后续只用新不可变候选重验，不重复6d冷启动。
- 已复用既定s4/s5入口拿到真实WasmFS完整扫描，约18ms、无截断/FS错误。s4初厅FS296,845,598字节→陨坑532,249,120字节，项目`/home/web_user/update/127.0.0.1_4287/game-dist/assets/chunk.vdat`从80,437,248→311,996,416字节；s5初厅296,775,979→主引擎坑460,042,048字节，项目chunk从80,474,112→240,955,392字节。另引擎chunk76,025,856字节、libs chunk3,555,328字节、bundled约94MB。两个稳定点XHR0，不代表下载峰值没有重复buffer。s1..s3旧probe的0文件仍保留并标为无效FS诊断，不覆盖旧证据。
- 实际`.project/settings.json/resources.json`只有boot预载和default全引用，没有下载并发/Chunk/OPFS后端配置；两schema没有cache持久化或chunk evict开关。缓存实际`ResourceCacheExtensions.lua`只有下载/取消/观察/负缓存资源重载，没有chunk释放。可生产使用的最小范围是受控下载峰值、已解析资源显式释放、经源哈希确认的重复内容去重；不能从公开API编造chunk压缩/回收。若大chunk后端仍为内存，需要平台提供后端/预算接口证据，不删除仍被resolver索引引用的整个chunk。

## 本路总计划 ID 实际状态（10月15日 16:00）

以下是本路参与的验收 ID，列出已有生产与证据以及剩余项。分项功能通过不自动关闭完整 ID，旧包只证明对应旧包；所有100ms性能失败继续保留。

| ID | 当前已实现及实测 | 必须继续验收的 OPEN 项 |
| --- | --- | --- |
| W03 | 原AimAssist移植；直接执行原函数336黄金场景，`aim-assist-native.json`功能PASS；root已接真实鼠标/触屏倍率 | 最新统一包实际多武器/移动目标/墙遮挡/队友/触屏软锁定及源视觉全组合 |
| W06 / W07（本路Boss/敌人与分类部分） | 原Boss护盾/穿透/永久节点/毁车特殊规则；原EnemyRules195源组合已进共享1069检查；Boss实际死亡重生保持损坏、引用释放112项 | 共享逐块破坏/全部掉件/全部武器冷却恢复仍由root汇总；完整自然Boss战斗及损坏画面 |
| W08 | 原狙击红蓝线/充能/遮挡裁剪/枪口与命中光点、SniperThreat双箭头已接；原生shader及实际Web组件已运行 | 全阶位/充能阈值/2–4px屏幕宽/1000m终点/敌我朝向/遮挡的专门自然实战与画面对照，不能据普通准星图关闭 |
| W09（本路剧情/Boss FX） | 原普通Mission与Boss爆炸、采集器落地、spawn/flee stomp、警报灯、Boss预警/火线/半球/飞机/导弹/逃生舱；`story-explosion-native.json`514、`story-alarm-native.json`1085、`story-view-native.json`452功能通过 | 全武器FX由root汇总；最新包Boss全状态动画/地面坡面/暂停退出的自然截图与性能 |
| M01（本路地图） | 陨坑与独立EnginePit原场景/道路/出生/碰撞/材质；6d五个剧情真实入口各3/3通过、错误0 | 打捞/大厅/仓库由对应owner汇总；全源地图清单同构建资产审计与所有入口覆盖 |
| M02 | EnginePit实际地面射线/顶棚分类，原机翼四档实际渲染20项/5865飞控黄金；四足Boss真实装配2227零件/4脚 | 自然轮式/履带/机甲/飞机/巨车驾驶全部坡道、舰厅与净空；不同物理引擎的量测差异仍OPEN |
| M03 | Boundary物理侧墙与各地图接入；旧包Web实际4墙组件存在 | 所有地图角落/高速/转轴外伸/巨车/飞行的真实阻挡和源位置一致，禁止只用组件计数关闭 |
| M04 | 原蜂窝墙渐显/距离警告/扫带/接触环/贴地光已接，6d第四关入口实际截图明确可见蜂窝；原生实际子几何隐藏/恢复通过 | 全边界/拐角的40/12/6m逐距离A/B及接触动画；目前不是源逐像素验收 |
| M05 | Boundary顶部几何与源260m软天花板已接，原生顶部子几何显隐通过 | 实际飞机/推进器/机甲到顶接触及视觉与阻挡一致；不能用源码存在关闭 |
| M06（本路地图材质） | 原shader hooks、地形数组、EnginePit烘焙/雾/天空；多次Web编译与资源0错误 | 固定机位源A/B和目标设备；按用户要求不在其他系统未完成时反复调灯光 |
| M07 | 原采集器/货车/警报/甲板/烟风尘/BossFX；`engine-pit-deck-native.json`6050、map-effect-lifetime15功能通过 | 其他owner的大厅设备/商人/天车需汇总；全事件视觉/遮挡/自然运行与持续性能 |
| M08 | 可读XML有静态实体；动态由Mission/Boss/Deck等模块持有，退出幂等已实测 | 原编辑器操作与对应runtime实体/碰撞证据仍OPEN；不触用户Editor PID43020 |
| B02 | 完整源通用driver五角色65状态11700帧23455黄金；钻头driver144；旧8d真实PC/20:9自然AI各12项，真实移动/交火/受伤 | 当前统一包多地图完整自然对战/卡住率/全部导弹策略及真机性能 |
| B06（本路威胁） | SniperThreat、任务/Boss HUD真实状态与死亡路径早退已接；BossHudMotion新增121功能通过/实际3截图 | 共享竞技HUD各字段/战绩Tab由root汇总；全部敌我威胁自然触发、源字体/布局逐状态验收 |
| B08（本路自然AI证据） | 旧包真实多AI移动/60秒自然交火与返回已完成，未改血/传送/杀敌 | 三竞技模式各完整赢/输/重开/再入、死后观看/暂停/失焦；本路证据不冒充完整一局 |
| S04 | 第一关规则与原事件/安装/情报/collector/警报/失败重试cue；6d真实入口3/3 | 完整九步自然成功/失败重试/退出续接/奖励；当前自动驾驶尝试不得写成通关 |
| S05 | 第二至四关冻结10/14重导、选择/护送检查点/夺点/守卫/撤退/原三行横幅；6d各入口3/3；旧cbeb剧情指引PC21/20:9 20功能通过 | 二三四关各完整自然成功/损毁/选择/奖励/券与存档；旧指引含QA定位，不冒充自然通关 |
| S06 | 独立EnginePit、FOX2227原件/四足、完整阶段/护盾节点/招式/钻头/飞机/盟友/结尾；Boss实际生命周期112项，6d实际Web后半37项直到后续换图OOM | 自然Boss全三阶段/所有招式镜头/胜负/结算解锁及原HUD视觉；QA推进阶段仍明确标记 |
| S07 | 原version6片尾真实Mission.StartEpilogue已在6d走8句/4panel/红章/自动回厅；原五关配音尚未制作，因此保留原字幕；照片桥接释放11功能通过 | 一次播放真实账号存档门控/退出重入、源仅3D纪念照及全页视觉；不把无配音当迁移丢失 |
| S08 | 原目标/距离/敌菱形/离屏箭头、三行banner/选项/情报/安装/评价/通讯字体；732 marker源规则进1069共享检查、514 banner/事件功能通过 | 所有实际任务状态画面A/B、PC/20:9完整操作与自然通关后的HUD状态 |
| S09 | 6d完整自然片尾→wing实际操作已走通；后续第二次陨坑下载322/323 **OOM/FAIL**，原报告完整保存 | 连续全篇/进度选择/音频不断裂/所有地图反复进入释放及目标设备；OOM未关闭 |

S01/S02归g4开篇/教程，W01/W02/W04/W05、B01/B03/B04/B05/B07及共享装配/战斗HUD归root主线，S03考场来源由总计划登记；本表没有把未接手项隐去或当已关闭。

## 10月15日接续：完整片尾与连续进图 OOM

- `boss-wing-web-pc-935b3961-real-ending.json`：PC **40/40 功能 PASS**、运行错误0；真实 Boss 结尾触发 Mission.StartEpilogue，46.524秒不跳过自然播放，8句原字幕、4panel、驳回章、自动回厅，随后 feather 飞行及陨坑边界和返回均完成。Boss 战斗阶段仍由 QA 推进，不等于自然完整三阶段战斗。
- 同935的20:9已看到8句/4panel/章/自然回厅，但 story5→wing→crater 连续路线最终 `Aborted(OOM)`，整条路线 **FAIL**。原日志和 SHA 保留，`boss-wing-web-phone-landscape-935b3961-real-ending-oom-recovered.json`从373条原状态恢复全部时间线；不是重放或通过报告。
- OOM 前资源取证：首厅52.9MB，story回厅80.5MB，wing回厅93.5MB；两个回厅的arrayBytes均已归零、Lua约33MB。再次陨坑最终resourceBytes195.7MB（arrays67.1MB/Models50.2MB）后OOM，不能仅凭此声称旧地形数组没有释放。
- 实际片尾章截图发现旧panel没有淡出：NanoVG内层`nvgGlobalAlpha(enter)`覆盖外层pageOut；现改`screenAlpha*fade*enter`并使stamp/finish保持旧页alpha0。合同拟声字恢复源1.65秒延迟。`epilogue-stamp-native.json` **7/7 功能 PASS**、Lua/resource0，1条100ms启动尖峰使整体性能FAIL；实际截图已核为暗底/红章，无旧漫画和教程叠层。新增像素断言同时要求红章确实存在，旧boot遮罩无效截图不当作签收。
- 已修真实地图FX生命周期缺口：CraterEffects原仅Remove根节点、未Dispose自建烟尘材质；CraterDust未Dispose自建两批材质和几何；EnginePit sky clone和Crater sky/glow clones未显式释放。现在幂等Dispose并清掉scene/layout/owner/CPU mask引用，EnginePitDeck清掉weak registry及场景节点。效果数量/材质/参数不变。
- 同时发现片尾照片桥接生命周期确定错误：`nvgCreateVideo(Texture2D)`却用`nvgDeleteImage`释放；按引擎`scene-to-nanovg.md`改为`nvgDeleteVideo`并清除capture/shot引用。照片纹理由Boss所有权继续释放，片尾不重复Dispose。该修复是OOM候选原因之一，还需真实连续路径复验才能关闭OOM。
- 新`verify-map-effect-lifetime.ps1`已实际载入两原场景、创建和更新原FX再连续两次Dispose，**15/15功能PASS**；`epilogue-stamp-native.json`扩为真实Texture2D/3帧panel桥接、红章与两次Dispose，**11/11功能PASS**。分别203/22条100ms尖峰使总体性能FAIL，Lua/资源错误0。连续20:9 OOM必须用下一不可变包原路线重跑关闭，不能降低阈值或跳过第二张图。

## 10月15日 13:50 接续：甲板与完整片尾

- 沿用冻结10月14日基线，不重开G0。`EnginePitDeck`恢复原可塌甲板接口：实际3个完整支撑体、18个fallen备用碰撞体，真实完整/残骸子模型显隐、睡眠刚体唤醒、幂等collapse及reset。源没有调用collapse的Boss位置，不自行增加触发。
- 原导出遍历跳过hidden nodes且编译跳过disabled碰撞，现保留。EnginePit现171模型、26材质、194碰撞、989节点；原168个模型逐个二进制不变。新增三个原fallen mesh和隐藏root，不扰动旧mesh编号。
- `EnginePitDust` / `DeckDust.shader`按冻结`airFx.buildSmoke`恢复8处/.9秒/420有界粒子池，单batch；60帧直接执行原buildSmoke夹具，147项真实contains矩形边界。`engine-pit-deck-native.json` **6050/6050功能PASS**、Lua/resource错误0；4条100ms尖峰使整体报告仍 **性能FAIL**。先前LoadXML接口、RNG起点和射线命中测试box的失败报告均保留；实际首帧RNG2174022687来自源THREE构造消耗，不放宽容差。
- 已打开`engine-pit-deck-native.png`，确见原坑/倒塌几何与dust，但同进程大厅UI叠加，不能作干净场景画面签收；已改QA隐藏原UI，补图待下次空闲原生窗口。
- 片尾真实根因：`StoryComms keepOpen`保留最后字幕，旧`Talking()`永久true阻止下一句。现按源queue/当前字幕age超过length推进，保留末卡又能自然播完。原第五关开头明确“配音还没做、董事长不配音”，不擅自造音频。
- Epilogue panel label/sfx改原GameFont，合同标题/批准章/驳回章改VoxIndustrial；Typography资源显式进入Dependencies，g4扩原字体219字形、保持字形轮廓/advance。
- 生产代码已向root报告freeze。统一`manifest-935b3961`、快照`.tmp/outgame-cached-1792043283252`、脚本`494022f184eb6e207d03086817785d92f28e15fa9d0ea764518ae02bc8c38f7e`，QA4278/普通4277。PC和20:9完整scope/Boss/不跳过自然片尾Web正在执行，未套用旧cbeb包通过项。
- 完整自然片尾检查走真实Boss结尾→Mission.StartEpilogue，不使用F12代替：进入后不按跳过、不写时钟/阶段/HP，采样8原字幕、4panel、驳回章、自动返回。前段Boss阶段由QA推进，仍不能称自然完整三阶段战斗；旧F12仅首格检查保留标签。

### 后续取证与源边线增量

- 935b第一次PC/20:9开镜probe仍报231中10模型visible，失败完整保留。root查明probe原在Update采样，武器动画临时enabled而实际PostUpdate会隐藏；生产未改，QA4279沿用同935不可变快照，probe改在真实PostUpdate之后取证。两端SCOPE_ONLY **13/13 PASS**、错误0，开镜真实231模型visible0、退镜恢复原mask，samplePhase明确post-update。旧FAIL不是静默删除或生产代码绕过。
- 原flow19/19 PASS只证明原后半，未走真实片尾：Boss长Enter后马上离开，rules尚未finished，旧工具没断言路线实际触发。现必须等真实finished再退场，并强制8句/4panel/stamp。新的完整检查单次900ms反馈采样落在无反馈帧而停，两端失败保留；自然片尾拆为flow-only继续，不重复已PASS13项相机。
- 下一生产delta：导入器恢复原LineSegments positions/material，`MissionView`实际LINE_LIST CustomGeometry，保留beacon白色outline不被Objective染色；spawn/flee两入口接原posY-1/.8 stomp。导入仍73原模型，源顶点未重建为近似线。
- `story-view-native.json`最新 **452/452功能PASS**，Lua/resource0，1条100ms尖峰使整体性能FAIL。首轮451/452是QA新beacon rig默认原hidden而断言可见；保留`story-view-native-outline-initial-hidden-failed.json`，显式show原rig后通过。增量已报告root freeze，不属于935包Web已验。

更新：2026-10-15。本文件是持续进度记录，后续恢复工作先读本文件与 `FULL_PARITY_PLAN_2026_10_14.md`，不要重新从 G0 开始。

## 固定基线

- 迁移分支：`codex/h5-2026-10-14`。
- H5 源提交：`2b169a9964645f5f346a7158bcb14447f040814a`。
- 冻结源目录：`.tmp/outgame-source-2026-10-14T10-09-50-505Z`。
- 哈希清单：`docs/migration/outgame-baseline.json`。导入与黄金对照均检查源 SHA256，不使用仍在改动中的原仓库 HEAD。
- 本批负责人：子 agent `g3_g4_battle_story`；共享入口/物理/车辆/HUD 接线由主 agent 维护。

## 已实现内容

| 系统 | 本批内容 | 验收状态 |
| --- | --- | --- |
| 边界视觉 | 原版六边形墙、顶盖、距离淡入、碰壁警告与波纹 shader；陨坑视觉半径 301.5 m、物理边界另由地图保持 260 m | 原生与 Web shader 编译通过；Web 视觉半径外截图未见墙，距离淡入和碰壁自然表现未关闭 |
| 狙击识别 | 红/蓝瞄准线、蓄力阈值、发射口与命中光点、遮挡裁剪、敌方双箭头方向提示 | 原生 shader 编译通过；多武器实战待做 |
| 第五关地图 | 接原版 EnginePit 场景、道路、地面碰撞、顶棚与出生点；原版 2 个目标 | 原生真实地面射线与顶棚判定通过 |
| FOX 模型 | 导入原版 2227 零件九尾狐，不替换为通用靶车；使用原版 mech5 四足控制与命中区域 | 实际引擎装配、四足和弱点命中通过 |
| FOX 伤害 | DPS 预算、护盾 45/55/65/75/100%、穿透、四永久能量节点、跪下 ×3/驾驶舱 ×4、单次 18% 上限、起身 20 s 保护 | 16 个原版 `onHit` 黄金场景及原生流程通过 |
| FOX 战斗 | 三阶段、踩踏、横扫、火线、跳砸、导弹、三架轰炸机、钻头车、三名合同工、顶棚避大招 | 原生节点→跪下→复活保持伤害→钻头兵→轰炸机→死亡流程通过；自然玩家完整战斗待做 |
| FOX 画面 | 原版几何工厂导出 20 模型；预警环/扇形/火线、弱点、护盾、尾巴光、导弹、轰炸机、逃生舱和卡车 | 原生画面已见实际模型；运镜/预警全状态逐帧对照待做 |
| FOX 死亡 | 禁止普通碰撞伤害拆散 Boss；死亡立即清掉 drill 标签敌人；保留其他单位；演出/Enter 跳过/退出释放 | 原生生命周期通过 |
| 片尾 | 源 version 6 漫画面板/董事长抠图/合同/驳回盖章/通讯/点击/Enter/Esc、存档一次播放门控 | 页面生命周期与首格完整淡入通过；最新人物采样裁剪修复待截图复验 |
| 片尾图片 | 源 WebP 离线无损转 PNG，避免原生 NanoVG 不支持 WebP | 原生资源零错误 |
| FOX 运动态 | 原版局部 Y 跪下/瘫倒、局部 X 前倾、顶棚下跳砸重定位、跳跃落地锁定、径向伤害衰减与冲量 | 已接线；107 项生产入口功能回归通过；逐帧视觉对照待做 |
| 钻头车 | Boss 生成原版 drill 专用驾驶器，保持原版无故事关卡自爆钩子 | 源版驾驶黄金对照 144/144 通过；Boss 三车生成回归通过 |
| 机翼飞控 G1 补项 | 原版 wingControl 气动力、失速、键盘飞行、悬停辅助、襟翼/减速板、力矩分配、遥测与喷气反推 | 实际引擎源码黄金对照 5865/5865 通过；整体性能门槛未通过 |
| 机翼骨架 G1 补项 | 原版 flap/sweep/vane/ring 层级和弹簧动画、发光、30 点有界翼尖尾迹 | 实际四档机翼装配/骨架/飞控/尾迹 20/20 通过；整体性能门槛未通过；不等同画面 1:1 验收 |

## 本批证据

- `tools/migration/import-g3-g4-source.mjs`：实际 level5、FOX、片尾剧本与图片导入，保留来源哈希和 PNG 派生哈希。
- `tools/migration/import-boss-view.mjs`：执行冻结源几何工厂，20 模型、11 材质、148856 字节模型导出。
- `tools/migration/source-boss-fixtures.mjs`：直接执行冻结 `FoxBoss.onHit`，16 场景；不是 Lua 实现自己生成期望值。
- `tools/migration/verify-boss-native.ps1`：启动生产 `app:EnterTrial('story5')`、原版地图加载路径及真实车辆/物理，运行 `check-boss-native.lua`。
- 最新运行 `docs/migration/evidence/boss-native.json`：**107 / 107 PASS**，Lua/resource/engine 错误均 **0**。
- `docs/migration/evidence/boss-native.png`：实际四足九尾狐与原版引擎坑画面，已打开检查。
- `docs/migration/evidence/epilogue-native.png` 已改为等待完整淡入：实际原版蓝色办公室与董事长抠图可见；已修复人物框外纹理边缘重复采样，最新裁剪待独立截图复验。
- 首次四足真实运行发现 `Body.applyTorqueImpulse` 缺失，已由主 agent 修复，随后完整运行通过；没有删除失败断言。
- `tools/migration/source-wing-fixtures.mjs`、`source-wing-fixtures.json`、`check-wing-control.lua`：直接执行源版 81 个失速系数、16 类 1920 帧升力/力矩/输入状态，以及 8 类喷气正推/反推。`wing-golden-native.json` **5865/5865 功能断言通过**，Lua/resource/engine 错误 0；启动约 483 ms 与同步黄金循环约 170 ms 超过 100 ms，报告总体为 **FAIL**，未提高门槛掩盖。
- `check-wing-render.lua`、`wing-render-native.json`、`wing-render.png`：四档实际机翼生产 Vehicle/DriveView 装配，**20/20 功能断言通过**，Lua/resource/engine 错误 0；启动和同步 QA 模拟循环超 100 ms，报告总体为 **FAIL**。截图已检查有实际翼面和发光，不能代替源版构图/全动画验收。
- Boss 流程 QA 显式固定 `HasFocus`，避免并发原生窗口造成 OS 失焦冻结剧情；生产逻辑未改。Boss wrapper 的 20000 ms 门槛仅用于功能回归，不能作为性能合格证据。
- `tools/migration/check-boss-wing-web.cjs`：4266 同一不可变包 `manifest-9100f4af`、脚本指纹 `1f1676cc4a983c6581279834ff77eccdc32220b233db16cffd9fce3bc24ae641`，PC 1920x1080 与横屏 2048x922 各 **19/19 PASS**。实际第五关、2227 零件/四足、弱点命中、三钻头敌人与三轰炸机、源片尾首格、返回释放、84 零件 feather 四飞控面/键盘与遥测、陨坑边界组件与 shader 均运行。Lua/engine/shader/game asset 错误 **0**；每端另有 **4 个缓存引擎 windows.7z 回退 404**，已完整保留，未计为游戏资源错误。
- 截图 `boss-wing-web-pc-fox.png` 已见近距离 FOX；片尾 PC/20:9 `boss-wing-web-*-epilogue.png` 已见蓝色办公室与正确董事长 cutout，人物框外灰条消失。当前 FOX 开场截图仍处于腾空/头顶裁切状态，边界截图无显著六边墙，不把这些照片当作全构图/边界触发表现通过。
- 新 `combat/EnemyDriverMath/Nav/Tactics/Think/Motion` 与生产 `EnemyDriver.lua` 替换原 135 行简化规则：源响应曲线、RNG、目标横向跟枪滞后、掩体撤退、狙击换位、hover 迂回、横移/变向/边缘保护、物理路网重接、坡道车道、队友避让、卡死与翻正、导弹蓄能/切组/齐射。`source-enemy-fixtures.mjs` 直接执行冻结 `shared/ai/driver.js`（SHA256 `c524a6f0ec0f80d002d46ca6425d66dec39140eeb4a99a593e811025c8fc2af6`）。首轮 20 场景/3600 帧 **7255/7255 功能断言 PASS**；扩展五角色 x 13 状态共 **65 场景/11700 帧、23455/23455 PASS**，包括导弹齐射/蓄能/切组、护盾、队友避让、翻正、卡死、瘫痪与出击坪。源夹具每帧深拷贝，避免原 JS 后续 shift 改写历史 route。Lua/resource 错误 0；报告总体性能 **FAIL**，最新 100ms 超时37条（含失焦节流和同步夹具），不提高门槛。
- `Mission`、Boss 盟友已接第四返回值 `DriverActions.Apply` 的源重置/翻正顺序与真实 salvo；Boss 盟友改直接把原弱点 pos + unit 喂给决定层，移除事后强改 aim 与强制全组齐射。共享竞技/无尽/打捞接线由 root 负责，钻头继承第四返回由 G5 负责。
- 新 `combat/AimAssist.lua`：冻结源 `shared/combat/aimAssist.js`（SHA256 `845b1ae6fef3110b6536ab276bcbb9e14a46b04443d8b0f980e7d15cee3481db`）暴露格子软锁定、正对目标只减速、速度缩角、遮挡、前四候选和近墙拒绝，root 接 1.8 倍瞄准镜/2.2 倍触屏及实际控制。`source-aim-fixtures.mjs` 直接调用原函数，三速度 x 四偏移 x 四倍率 x 七状态 **336/336 原生黄金 PASS**；Lua/resource 0，整体仍因38条100ms尖峰 FAIL。
- `check-ai-runtime.lua` / `ai-runtime-native.json`：生产异步进入竞技试车后自然运行 30 秒，不传送敌人、不赋值血量、不杀敌；**6/6 功能 PASS**。真实固定步7505次 AI 决定、五辆 AI 位移>3m、5837帧真实 fire、玩家 Life 由1自然降至约0.25，出现 approach/snipe/reposition/unstick。`ai-runtime-traces.json` 逐秒保留实际坐标/生命；截图已看见真实敌方光束与玩家零件损坏。Lua/resource 0；总体100ms性能 **FAIL** 134条，不代表帧率合格。截图有鼠标释放提示，不能作为完整HUD视觉签收。
- `story/EnemyRules.lua` 与 Mission 已补冻结源 `_doomed`：无武器/无动力摧毁核心，狐狐座驾逃跑，不把共享 hull 再按 55%/35% 提前摧毁；补 `hullMin` 供准星显示离真正摧毁阈值的剩余量。`source-story-enemy-fixtures.mjs` 直接执行冻结源192组合，加目标和真实API适配 **195项**。`EnemyDriverMath.Life` 改读 Core/Integrity，避免把 HUD 共享 hull Life 错用于原版 AI 撤退。root 公共集成最新 **1069/1069 PASS，Lua/resource 0**，含这195项。
- `story/MarkerRules.lua` / MissionRules / MissionHud 已补原护送被拦截时指向敌人、坚守近敌指引、对话无目标、最近存活敌人、各玩法3.5/6/9/10/12/24m标记高度、其余敌人红菱形、离屏箭头和Boss近距隐藏。`source-story-marker-fixtures.mjs` 直接执行原 `_target` / `_marker` / `_project` 与 KINDS；270状态 + 192投影，共 **732项**，已包含于上述1069/1069公共PASS。
- MissionHud / MissionResult / MissionChoice 原先误用 SmileySans，已按冻结 `storyHud.css` 的 `var(--display)` 改 VoxNum/VoxTitle 对应 `vox-display`，正文段落仍用源 body 字体；距离按原 Math.round / km 显示。当前统一Web `manifest-8d52110f`、QA4269收入这些生产修改，真实自然AI/任务指引截图进行中，尚未将其写为视觉PASS。
- 甲板接口继续源核查：原 EnginePit 的注释说Boss跳砸踩塌，但冻结全仓没有调用 `deck.collapse()`；不擅自为Boss增加源中未触发的玩法。地图本身动态API完整迁移仍待补。

## 尚未关闭的验收

1. 同一 Web 构建实际进入第五关，确认所有 shader、PNG、源模型下载与 HUD 层次。
2. 片尾全页视觉对照、完整自然播放、一次播放存档门控、退出重入；不得以 Esc 生命周期测试替代。
3. FOX 跪下/瘫倒/大招前倾与浮起的源版 display lean 已接线，仍需运镜/动画逐帧画面对照。
4. 当前纪念照片使用呈现帧截图，包含 HUD；原 H5 只截 3D，仍需只截 3D 的实现或视觉验收。
5. 跳砸落点在顶棚下时的原版露天道路节点重定向已实现，需增加直接命中屋檐边缘的专项实际场景检查。
6. 原版 drill 专用驾驶策略已接线并通过 144 项源版对照，仍需自然战斗寻路表现检查。
7. Battle `RecordDamage` 对 Boss 护盾/穿透反馈标记的源版显示，需共享战斗反馈接线。
8. 实际战斗自然走过三个阶段、盟友复活、狙击遮挡、所有预警与最终完整片尾，尚未人工试玩。
9. FOX 2227 零件首次实际装配存在秒级 CPU 峰值；加载界面应保持呈现并分帧建车，主 agent 处理加载性能，不能宣称首次无冻结。
10. 20:9 / 16:9 / PC 宽屏与移动真机帧率、持续温升尚未测量，不能以桌面验证替代。
11. 冻结源 `shared/story/radio.js` 的短提示音已交 G4 接线并完成62/62原生检查，仍待最新统一 Web 包听感/时序；BossHud 尚未全量 CSS 逐像素对照。
12. 完整 AI/AimAssist 的源夹具和原生自然交战已验证，最新统一 Web 构建中真实触屏/鼠标软锁定、自然多车导航/所有导弹策略尚未实测；不能把旧9100f4af包的19项结果套用到新AI。

本文件记录模块实现与实测边界，**不代表 G3 或 G4 全量 1:1 已验收关闭**。开篇/教程另见 `G4_OPENING_PROGRESS.md`，无尽另见 `G5_ENDLESS_PROGRESS.md`。

## 03:04 同包真实 Web 自然检查

- 不重开 G0。QA4269 / 普通4270 的 `manifest-8d52110f.json`：`check-natural-ai-web.cjs` 实际点击出战、歼灭战、开始匹配，真实鼠标接管或 CDP 触屏摇杆，手动前进12秒，然后自然战斗60秒。没有传送/改血/杀敌/推进回合/加速模拟。PC **12/12 PASS**、20:9真实触屏模拟 **12/12 PASS**，Lua/shader/browser/game resource 错误0。PC五AI位移120.7-294.7m、触屏204.5-300.2m，出现 approach/seek-vantage/unstick/push/strafe/backoff；真实AI造成伤害，PC tankmom Life1→.773、Ironfern1→.286；触屏 driftwood1→.551、敌方零件收藏家1→.145，428次真实命中。退出返回实际大厅并释放地形数组。
- `check-story-guidance-web.cjs` 实际点击剧情模式、04偷家、开始任务；仅用QA F4将真实玩家放到第一个原目标点，不杀敌、不改阶段。PC **17/17 PASS**、20:9真实触屏模拟 **16/16 PASS**，三个采集器实际绘制、三名守卫自然生成、目标变成最近存活守卫、离屏提示与返回资源释放均运行，错误0。不是完整自然驾驶通关，更不是五关总验收。
- 四路每端有4个引擎 `cached-engine-source/.../assets@windows.7z` 缓存回退404，报告单独保留，不计作游戏资源成功或删除。
- 先前首帧Yoga尚未计算新菜单布局造成QA取不到模式按钮，两失败报告保存为 `natural-ai-web-pc-layout-race.json`、`story-guidance-web-phone-landscape-layout-race.json`；测试改等实际正尺寸可点击按钮。另保留30秒原地自然运行无伤害失败 `natural-ai-web-pc-parked-30s.json/png`，没有把这份失败报告改成通过。
- 加载性能仍 **FAIL**：PC大厅58.186秒/竞技98.187秒，20:9大厅53.627秒/竞技98.333秒；剧情PC大厅53.155秒/进图69.912秒，20:9大厅58.257秒/进图70.154秒。20:9自然战斗采样最慢p95/max约100ms。这是桌面Chrome模拟，不能签收手机/M1帧率和温升。
- 已打开实际自然交战截图，见武器光束、零件受损/碎片和触屏界面；任务截图见原通讯立绘和最近敌人菱形，边界出生处首次有明确蜂窝墙视觉证据。任务敌标图片仍有大的蓝色信标挡住中央。后续真实StaticModel检查原17/18失败，根因已确认：UrhoX `enabledEffective` 只看直接父节点，`root.enabled=false`没有禁用子模型。失败报告保留`story-view-native-hide-failed.json`；当前信标/Boss复合预警/飞机/逃生舱/边界改用`NodeVisibility`的`SetDeepEnabled(false)`与`ResetDeepEnabled()`，保持原隐藏子节点掩码，增量实际检查等待执行。
- 下一包生产增量仅 `render/MissionView.lua`、`ui/BossHud.lua`：补capture原红色信标，信标/圈恢复THREE原线性色（原导出材质已经是线性，不能用sRGB/255覆盖）；安装圈内信标按原fadeTo=.25、.08平滑更新outer/inner/gem；Boss大招按棚外/棚内显示原动态避难提示。`check-story-view.lua`验证真实材质/几何关闭/淡化，尚未运行，这些增量不属于8d52110f已验结果。

## 03:45 源遗漏修复增量（未套用旧包验收）

- `Level2..4.json`仍标旧10/13源提交`9086244`。已重新执行冻结10/14四关数据导入，按显式映射翻译原函数条件/动作，更新每关真正source SHA256。原level3提示改为“慢慢修车”，2/3/4及MissionResult统计标题改原`WRECKED`。不覆盖冻结源，不用工作区HEAD替代基线。
- 原`import-story-source.mjs`把`glowSprite`直接替换空Group，导致情报/采集器/运输车光晕完全缺失。导入器现保留真实线性色、opacity、size和节点索引；`MissionView`用一个64上限的billboard批次及源0/.25/1径向渐变恢复。原采集器HSL状态灯、喷火抖动、一次落地dust/chips、运输车速度/正弦警灯、情报每帧`.86`及共享材质引用次数淡化也恢复。`StoryStomp`使用现有粒子预算，Mission落地接`stompV-=2.2`，镜头由root公共接入。
- Boss导出原先`ff3b46`代替真实ring/sector的`ff3b30`、lane的`ff4a2a`；原透明预警/护盾统一错用Mission additive。现分原普通alpha与真正additive glow，BossGlow按源0/.3/1渐变。恢复线性色、原560m半球及ground-30m/平方蓄力和末秒闪烁、火线两倍进度ease/opacity、jump合计进度、独立橙色shock ease、原160cm导弹cone/raid capsule与原亮白/深色、屏幕1px尾迹和原光晕尺度。`Boss/View.json`22源模型，新增shader和模型均列入Dependencies。不是调整大厅或地图灯光。
- `source-story-fx-fixtures.mjs`直接执行冻结`StoryView.update`，普通/instant采集器共96帧，记录真实HSL/落地/钻头/展开/上行光柱期望；新增真实模型显隐和源几何/材质检查待原生执行。新数据/生产功能不属于旧8d/1f已验结果。
- 发现上一批Web工具的身份字段读全局`.tmp/outgame-prepare-cached.json`，并发root更新准备文件时会与实际QA4269服务不一致。旧PC guidance报告的build/manifest标注不可靠，保留原文件并明确纠正，不把它计作1f包验收；实际端口/日志/截图保留。两个工具已改运行时请求该服务的`/identity.json`，下一统一包重验固定完整身份。

- 最新`story-view-native.json` **445/445功能断言PASS**：信标实际子StaticModel关闭/恢复原隐藏mask、Boundary实际墙/顶CustomGeometry显隐、Boss复合ring/sector/pod显隐、大招半球/平方alpha、火线ease/opacity、独立shock、实际bomb/cone模型切换、线性色、四关基线身份、96源采集器帧对照、真实光晕billboard及有界15dust/6chips均完成。Lua0、resource0；45条engine错误全部是100ms帧尖峰，max452.853ms，**报告整体性能FAIL**，未提升阈值。
- 首次新检查427/427已运行断言通过后，真正Glows绘制触发Lua错误：collector/truck根`userData.glow`其实是Object3D引用，被误导出为sprite参数。导入现仅接受`color`数组metadata，修后445项完整执行。原失败保留`story-view-native-glow-metadata-failed.json`，不删除、不声称原报告全流程通过。

唯一下一动作：root固定生产新包后用该端口`identity.json`重验PC/20:9指引真实子几何显隐/原光晕和Boss新材质；自然完整五关/Boss三阶段/全片尾和真机性能仍未关闭，不重做基线盘点。

## 03:36 新统一包剧情实测

- QA4275，`manifest-cbebfb9c.json`、`.tmp/outgame-cached-1792006200803`、脚本指纹`f452252cd01467addcd597031b8ee650e071a60b87987438b6fbeabf42fc3f99`。报告从运行服务`identity.json`直接记录身份，不再读并发更新的全局准备文件。
- 实际出战→剧情→04偷家→开始任务：PC **21/21 PASS**、20:9 CDP触屏 **20/20 PASS**。实际信标StaticModel起初可见，遭遇三守卫后全部子模型可见数为0；实际3个采集器各输出原光晕billboard，最近敌人target/marker生效，返回原界面并释放地形数组。只用F4定位实际玩家到第一个原目标，不杀敌、不改战斗阶段，仍不是完整自然驾驶通关。
- Lua/shader/browser/game asset错误0，各端4个缓存引擎7z回退404单独记录。PC大厅58.925s/任务75.096s、20:9大厅57.396s/任务72.831s，加载性能仍 **FAIL**，桌面模拟不是手机真机证据。
- `story-guidance-web-*-cbebfb9c-enemy-guide.png`两端实际画面已打开检查：中央旧80m信标已消失，采集器的源上行光柱保留，原通讯/旗/敌标和武器光束实际可见。不凭“有UI”关闭所有字体/HUD逐像素验收。
- 同包Boss新shader与22模型实际生产装配均进入，两端源FOX2227零件/四足、真实自身武器输入与镜头反馈前8项通过，但 **完整检查FAIL**：真实开镜时`scope=true`、`camera.firstPerson=true`，231个玩家StaticModel仍有10个可见，两端一致。`boss-wing-web-*-cbebfb9c.json`失败保留，后续raid/结尾未执行，不能声明新Boss全流程Web通过。root追查公共相机与武器动画对子节点的重新启用；本批不自行重复修改共享模块。
