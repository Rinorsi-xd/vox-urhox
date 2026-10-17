# 2026-10-16 按逐帧热点优化：候选与新包实测

## 最新归因：首用shader等待与TimeStep漏报

fb3/4479的30秒实际驾驶开火CDP采样已结束，runner57343 exit0/PASS/CLOSED，16功能检查、运行错误0；原始`evidence/performance-uninstrumented-match-1792163190043/`。MainLoop两次长帧174.132/171.315ms，线程CPU记录128.812/156.769ms；GL程序状态查询同步等待38.888/9.056ms为各自长帧子段，不可相加。它们发生于输入后约929/1269ms，输入期间11条shader成功日志支持首用预热遗漏。不是GPU硬件计时，也不能把无符号WASM函数索引映射成猜测的Lua函数。详见`PERF_COMBAT_CDP_2026_10_16.md`。

该次QA FrameStats最大72.685ms，却存在上述174ms浏览器实卡。FrameStats收集Update TimeStep，不能代替真实墙钟长帧判断；原始PASS只签功能及数据约束，不签无卡顿。CDP有额外开销，且最后车辆抵墙，不与无trace运行计算性能收益。当前证据仍不足以保证整场不会更卡；持续低帧重点为车辆固定步树，进入/首用尖峰另查shader等待，845/TapTap长期30FPS保持未通过。

## 接续候选 fb3e73b7（最新，匹配功能通过，持续30FPS未通过）

冻结 `.tmp/outgame-cached-1792161165387` / `manifest-fb3e73b7.json`，540 Lua，指纹 `9d14c2d8aedb4173918046b11906fc1bc2e5fb3cc72449332c4c576d59693498`；H5 b2760649和UrhoX父提交f94827b2不变。工作区/冻结/包Lua逐字节和普通4477/QA4478实际HTTP身份/manifest/main载荷一致检查通过。用户4471保持旧包，4475仍为此前c4包，不会自动更新。

新增三项：真实Glow绘制与实际首教程说话头像在不透明加载页内呈现后复用；GC mode-entry/collector-step/target retirement独立计时（不改调度）；WeaponSystem.Integrate移除每弹每步step临时表（不改射线、命中、RNG）。离线与Native证据详见 `PERF_HANGAR_FX_WARMUP_2026_10_16.md`、`PERF_COMMS_WARMUP_2026_10_16.md`、`PERF_WEAPONS_2026_10_16.md`。

普通4477的真实启动CPU采样/trace完成，`evidence/startup-cpu-1792161290569/result.json`为PASS，运行错误0。实际Glow VS/PS与CommsPortrait VS/PS均在LoadingFlow Closed之前；当前139条编译在前、4条在后。Closed第1486行，后四条仍为Hangar/Surface INSTANCED shadow/depth/SPOTLIGHT/RECTLIGHT VS（1487/1492/1494/1496）。截图ready.png已实看，正常机库/车辆/教程头像可见。只证明这两项真实编译次序修复，不宣称整体冷启动提速或画面1:1验收；trace自身有扰动，后close仍有约1018ms长帧，未清零。

六车Native无wrapper ABBA六车开火模拟循环2165/2131ms→2085/1991ms（均值约-5.1%），17武器3958/3760ms→3916/3612ms（约-2.5%）；不含整帧渲染/音频/UI，不是FPS收益。不开火对照397/408→420/427ms反向约5%波动，提示共享机器噪声；不得掩盖。三场景各2400步44项状态/射线/命中/冲量/爆炸/RNG精确比较和18边界检查通过。

同包QA4478匹配驾驶、开火和返厅已完成，744项功能检查、735直接明细帧检查通过，运行错误0。分析的是同一原始会话内全部753个已记录live帧，与runner检查窗口不同：累计间隔33990ms，平均45.139ms（约22.15FPS）、P50 41ms、P95 77ms、P99 94ms、最大251ms；已测Lua平均29.219ms，每帧固定步平均2.67065。753帧全部有分段明细，sampleDrops、解析错误、传输重复为0；657帧超过33.33ms，24帧超过80ms，**尚未稳定30FPS**。

同包剧情第一关公开入口30秒驾驶开火/暂停/返厅已补测：`evidence/performance-route-story-1792163005528/`，1783检查/1775直接明细帧PASS，运行错误0；active与returned已实看，返厅无live trial且车辆/弹丸/特效归零。实际原始会话`session-63a5a37b1ee844649a1ea889`单独分析：step2共1669帧，平均17.663ms/P95 20ms/Lua6.718ms/1.055步；step0/1分别66/62帧，最大369/435ms，加载activate最大2546ms。不是五关/自然通关，也不是与匹配同负载对照。第一轮误加仅竞技适用的baked-minimap门禁，`performance-route-story-1792162800863/`原FAIL保留；现在脚本启动前拒绝此无效组合，未更改生产。

本窗口可确认的持续负荷是战斗固定步模拟大树，计时均为scope墙钟而非精确线程CPU。`trial.Tick`平均26.103ms，内层`combat.BeforeStep`13.941ms，其中包括`vehicle.Step`8.919ms和`ai.Step`2.147ms；`physics.Step`平均4.035ms属于另一子树。`vehicle.Step`的self仅0.729ms，包含的子段有步态1.863ms、悬挂采样1.446ms、悬挂施力1.432ms、接触控制0.950ms、腿命中盒0.790ms。**不能把Trial、BeforeStep、Vehicle及其腿/悬挂子段重复相加**，也不能把Lua范围的平均耗时称为整帧CPU耗时。每帧多步会重复这些模拟工作，但现有数据不足以把所有剩余时间归给AI或某个单一函数。

新增GC分段定位到第4203帧：完整间隔68ms、wall67ms、Lua53ms、0个固定步，其中`gc.EnterIncremental`self49ms；外层`gc.Step`、`retirement.Update`和`main.Update`包含同一次49ms，不能相加。实际状态日志已核对发生于暂停/返回确认附近，不能作为持续驾驶热点。可以确认切换到incremental入口存在一次暂停，不能据此认定GC解释了持续22FPS：本窗口仅观察到该入口1次，均摊约0.065ms/帧。返回还有73ms模式恢复及33ms再次进入，见`PERF_GC_ROUTE_READONLY_2026_10_16.md`，尚未修改GC调度。

最大尖峰仍未闭环：第3495帧251ms，wall250ms、Lua28ms，wall内222ms未归因；第3489帧197ms，wall196ms、Lua20ms，176ms未归因；第3502帧124ms，wall38ms、Lua25ms，其中86ms在EndFrame之后。第4168帧AI scope出现49ms、第4198帧稳定器scope出现42ms，也不能仅凭scope墙钟认定为对应算法计算，可夹带GC或调度暂停。需要浏览器CPU/GPU trace进一步细分，残差不是GPU时间，也不证明后台场景未卸载。

本包与旧c4/6d的历史插桩帧数、驾驶/交火状态和窗口时长不同，不能由那些异窗口宣称整场改善或恶化。现已另完成关闭监控、相同1600x900/六车歼灭战/30秒W与开火输入的串行旧新对照：旧c4保留51窗口626帧，新fb3保留56窗口719帧；窗口P50超过33.33ms分别49/51与46/56。新包功能返厅14检查PASS、错误0；旧包驾驶窗口完整，但返厅最后QA状态截断使整体FAIL，原结果保留。此次有改善迹象，但实际行驶终点和墙体遮挡不同、随机状态和共享机器干扰未锁定，不能把窗口分位数合并成全局FPS，也不能宣称稳定收益或排除回归。见`PERF_UNINSTRUMENTED_COMPARE_2026_10_16.md`；原始`evidence/performance-uninstrumented-match-1792161914060/`与`evidence/performance-uninstrumented-match-1792162312741/`。局部Native ABBA只证明其限定模拟循环的结果，不代替Web整帧或845/TapTap长期30FPS。未提交/推送。

当前证据：`evidence/performance-route-match-1792161375245/result.json`、同目录`timings.json`及逐帧CSV；原始`evidence/performance-live/2026-10-16T14-34-01-126Z-53292-cb6dd3/session-39edb72b58eef00336881a10.jsonl`。本次只读复核重新解析原JSONL，753帧均值、分段及4203帧与汇总一致，未另跑GPU或性能基准。

## 历史候选6d09f056及c4d2c399（以下保留原证据）

状态：**工作区候选已整合，新 Web 包匹配/剧情功能路线通过；持续性能目标未通过**。本轮从现有 G0–G6 清单接续，不重开 G0，不表示整套迁移完成。以下实际路线结果对应 `manifest-6d09f056.json`，不包含后续的小地图重新烘焙。

基线：UrhoX `1016/main@f94827b26fc12b707e6d6904d093e16358caaf41`；H5 对照保持 `2026-10-15@b276064942ae09c0227ec28d4cfda1d5ff006455`。本轮没有为了提帧降低 60Hz、车数、射线数量、碰撞或表现精度。

## 为什么做这一批

上一包六车真实匹配的 126 帧短窗口：完整间隔平均 54.55ms，已测 Lua 34.07ms，Vehicle.Step 13.43ms（包含子段），Bullet 4.83ms、AI 1.89ms，平均每帧补跑 3.07 个固定步。车辆子段 self 平均包括步态 3.24ms、腿控制 1.90ms、悬挂施力 1.92ms、悬挂采样 1.83ms、腿命中盒 1.72ms。因此本轮优先减少车辆更新临时分配，同时补加载期间未归因段。

这些是桌面插桩短窗口，用于选择优化对象，既不是当前新候选的收益，也不是骁龙845或完整战斗验收。包含父子段不可重复相加；帧间隔减 Lua 不等于 GPU 时间。

## 工作区交付内容

| 生产文件 | 本轮变化 | 已有验证 / 边界 |
|---|---|---|
| `scripts/drive/RaySuspension.lua` | 标量点积/归一化、直接生成冲量和侧向接触点；共用单次接触的 point 转换；模块级分母函数替代逐轮闭包 | 原求力、采样、施加冲量顺序和常量保留；真实 Native ABBA 对照 |
| `scripts/drive/LegHitboxes.lua` | 每腿共用 yaw；常量关节映射；保留运算分组，移除每段中心变换的4个中间向量表 | 每段仍按原频率更新；真实 Native 对照及全部24安装朝向的实际命中模块对比 |
| `scripts/diagnostics/PerformanceMonitor.lua` | 已关闭 scope token 跨帧复用；仍活动的 yield scope 独立持有 token | 当前交接记录54项行为检查、537 Lua语法通过；不能宣称监控无开销 |
| `scripts/diagnostics/PerformanceBindings.lua` | 补首场景 Install/HomeView/GroundDisplay、大厅/面板/反射、闲置武器表现、缩略图请求/读取/回读分段 | 实际 monitor/bindings 模块83项行为检查及旧代码负控；新包启动已采到实际分段，仍有引擎/浏览器未归因长任务 |
| `scripts/app/LoadingFlow.lua` | Web 大厅预热前 `UpdateGrid(0)` 暴露首帧实际显示物；恢复全部 drawable mask 后，按当前相机准备并排队实际反射，继续使用原有揭幕帧门槛 | 专用真实模块/引擎替身检查通过；新包可揭幕，但揭幕后仍出现8条shader编译日志，不能判预热完整 |

`LegGait.lua` 的静息世界坐标缓存与 `LegControl.lua` 的常量列表微候选未显示稳定收益，已撤回，二者保持基线原样。未为等待后台资源增加固定延时或要求任意后台任务全部归零。

工具包括 `perf-leg-*`、`perf-suspension-*`、`verify-performance-home-bindings.py`、`trace-performance-startup-web.cjs`、`check-loading-hangar-warmup.lua`、`verify-loading-hangar-warmup.py` 及既有监控/加载检查增量。这些是验证工具，不是额外玩法入口。

## Native 车辆等价与局部收益

### 悬挂

真实 Native beta.40，隔离固定基线，四个串行进程 baseline/candidate/candidate/baseline。六辆真实 T3 车辆包含普通轮、履带轮和腿；另测真实原生运动平台上直接提供转子轮坐标的四轮车。

- 等价过程每场景900步，每步将全部可序列化车辆/轮状态与遥测写入二进制数字摘要，保留300/600/900步原始快照。射线参数/结果、冲量参数、车辆分母及平台速度另有独立摘要。
- 四轮运行的摘要、原始快照、调用数、车型元数据及后续32个随机数一致，120项比较通过。六车场景46337射线/15726命中；转子运动地面4500射线/1596命中，未靠减少查询取得收益。
- 计时每场景600步预热、3600步计时。六车 Sample 汇总484/503ms→468/466ms，Apply 380/366ms→298/287ms；Apply 平均降低约21.6%。六车整个模拟步汇总4057/4160ms→4023/3969ms，平均降低约2.7%。
- 转子运动地面 Apply 104/90ms→79/76ms，但整个模拟步455/446ms→459/467ms，平均回退约2.8%，Sample 增加。明确不能称所有车型整体变快。

这是 Lua/Bullet 模拟循环，不包含渲染、AI、开火、音频、HUD或地图加载。运动平台质量为0的kinematic，未覆盖非零动态地面惯量；转子坐标由探针提供，不覆盖完整 RotorMotion 装配链。整数毫秒逐次计时和共享机器调度有扰动。

详见 `G1_PERF_SUSPENSION_2026_10_16.md`、`evidence/perf-suspension-2026-10-16/`。

### 腿命中盒

七轮真实 Native，六车、180步预热、2400步模拟；每轮20个快照包含六车运动/遥测、脚位置/目标/模式/支撑力、全部命中盒中心/姿态/尺寸。所有快照、后续32个随机数及调用数完全一致。每轮 Raycast 122208、IK Solve 33840、Vehicle.Step 14400、Leg/Gait Step各4800。

- 基线命中盒分段462/456/571ms；最终仅命中盒候选413/371ms。相对基线均值约降低21%，不将其套用成整个车辆或整帧降幅。
- 独立固定姿态120000次 Update：基线3686ms、最终2812/2697ms。该段只测变换/分配工作，不推进物理，不是游戏帧率。
- 实际 LegIK/Rotations/LegHitboxes/VehicleRay 模块，真实leg3/4/5资源，24安装朝向×24目标/刀片姿态及每段三轴射线，共22464项精确姿态与命中比较通过。
- 完整循环耗时受热机/调度波动影响，未证实稳定整场提升。步态缓存未保留。

详见 `PERF_LEG_HITBOX_2026_10_16.md`、`evidence/perf-leg-f94827b2/`。

## 最新普通4471启动证据

4471保持旧监控包 `manifest-6bafddc3`，没有自动包含以上新候选。旧包用户复现记录只能支持定位，不能签收新代码。

最近会话 `20261016-212517-1155755179.0` 的已查记录持续约24分钟，全部上下文为大厅，`sceneIsTrial=false`、`units=0`；没有新增用户战斗证据。服务状态接口确认日志实际落盘，检查时队列/拒收/写入错误为0。

| 帧 | 完整间隔 / wall / 已测Lua | 能确定的工作 |
|---|---|---|
| 17 | 1206 / 1196 / 133ms | 场景激活，loader.Commit132ms（self131ms），其余1063ms未归因；浏览器对应1196ms主线程longtask |
| 40 | 754 / 753 / 0ms | 预热201/300，浏览器对应753ms主线程longtask，尚不能细分到具体引擎调用 |
| 253 | 479 / 477 / 12ms | 已揭幕大厅；约465ms未归因 |
| 254 | 273 / 271 / 3ms | 已揭幕、记录7个后台资源任务；数量本身不证明隐藏地图常驻或泄漏 |
| 75382 | 439 / 437 / 2ms | 大厅偶发尖峰，约435ms未归因；不能解释为车辆/AI开销 |

来源：`evidence/performance-live/2026-10-16T12-54-33-528Z-52192-81e9d0/session-e28f2adf1d77bcb5bfee1cc9.jsonl`；浏览器对应 `session-544cf516ac4042d2ab3b6b40.jsonl`。源日志仍可能增长，以上为已检查选段，非整会话最终汇总。

现有流程已确认：加载期间大厅/HUD正常 Update 被挡住，首次卡片/缩略图请求和实际反射可能在揭幕后才出现。因此增加实际分段并让加载预热包含首帧显示/反射；没有依据直接认定AI是启动主因，也没有依据认定某张隐藏战斗地图没有卸载。

细节见 `PERF_LOADING_STARTUP_2026_10_16.md`。监控原有帧格式、F6/F10、落盘方式及历史同包匹配/剧情验证见 `PERFORMANCE_MONITOR_2026_10_16.md`。本轮监控token复用尚无确定运行时开销降幅，不写“零开销”。

## 新 Web 包真实路线结果

包为 `manifest-6d09f056.json`，H5源提交 `b276064942ae09c0227ec28d4cfda1d5ff006455`，UrhoX构建父提交 `f94827b26fc12b707e6d6904d093e16358caaf41`。537份工作区Lua、冻结副本与包内Lua逐字节一致，脚本指纹 `c479abcceac1674bd76f8d2ee965823cdd2de21cf00af39d114b766e6499e5f2`。这只确认测试包身份，不代表整个脏工作区或所有资源验收完成。

普通启动CPU trace在4473；匹配和剧情公开入口在4474。未替换用户4471旧包。两条路线均完成驾驶/开火操作、实际逐帧阶段采集及返回大厅，运行错误列表为空。返回时 `units/vehicles/projectiles=0`，`sceneIsTrial=false`，构建场景与地图预览均未保留；这些计数不等同于完整资源泄漏验收。

| 实际窗口 | 帧数 | 完整间隔平均 / P50 / P95 / 最大 | 已测Lua平均 | 固定步/帧平均 |
|---|---:|---|---:|---:|
| 六车匹配，全部已记录live帧 | 499 | 47.73 / 42 / 81 / 258ms | 30.86ms | 2.78 |
| 剧情s1，全部已记录step0–2帧 | 544 | 30.06 / 23 / 62 / 606ms | 10.56ms | 1.60 |
| 剧情s1，step2单独窗口 | 458 | 24.92 / 22 / 35 / 294ms | 10.18ms | 1.47 |

主表按session/frame去重，只包含对应游戏状态，排除加载和退场覆盖。匹配记录的车数为6、零件939；剧情为1车、209零件。桌面debug/插桩、共享机器、短路线的结果不能换算为骁龙845帧率，也不能与旧包126帧窗口直接作整场优化收益对照。匹配当前平均间隔约对应21FPS，**尚未稳定30FPS**；剧情step2的P95也超过33.3ms。

runner的功能检查窗口与主表不同：匹配帧3630–4078共449帧，其中prep9帧、live440帧，平均48.26ms、P95 81ms、Lua31.35ms；剧情帧1936–2485共550帧，其中加载exit-cover13帧、exit-reveal43帧、step0共45帧、step1共41帧、step2共408帧，平均29.29ms、P95 55ms、Lua9.89ms。不能把这两个混合检查窗口称为纯战斗FPS。功能检查分别457项和558项通过；逐帧细节覆盖分别449和550帧。

匹配499帧内主要已测阶段：Vehicle.Step包含子段9.03ms/帧、Bullet4.18ms、AI2.67ms；self包括步态1.92ms、武器1.87ms、环境1.86ms、特效1.78ms、玩家表现1.51ms、悬挂采样1.39ms、悬挂施力1.38ms。包含关系不能相加。每帧平均补跑2.78个固定步，说明持续模拟预算仍不足，当前没有单一AI热点能解释全部负载。

另有已测Lua解释不了的大尖峰：匹配3667帧间隔258ms、wall256ms、Lua28ms；剧情2038帧间隔606ms、wall604ms、Lua11ms。剧情2050帧则明确测到storyView.Update48ms（当帧间隔216ms、Lua63ms）。这些需要分别追查引擎/浏览器长任务与故事表现更新，不能统称GPU或全部归因车辆。

普通启动4473的CDP采样与trace也有明显开销，不作为冷启动速度基准。此次135条shader编译日志在揭幕前，仍有8条在揭幕后；采样栈出现 `_emscripten_glGetProgramiv`，支持继续检查shader链接/状态查询链，但采样累计时间不等同于单次同步调用耗时。最长已记录启动帧3522ms（wall3517ms、Lua729ms）。现阶段预热覆盖和启动长冻结仍未关闭。

证据：
- `evidence/perf-targeted-2026-10-16/final-package-check.json`：包与源指纹。
- `evidence/startup-cpu-1792158804264/`：4473启动result、CPU profile、trace、runtime日志及截图。
- `evidence/performance-route-match-1792158953166/result.json`：六车匹配功能路线、collector和返厅上下文。
- `evidence/performance-route-story-1792159244967/result.json`：剧情s1短路线；不代表全部剧情通关。
- `evidence/performance-live/2026-10-16T13-53-05-375Z-51956-847a5a/session-b4ed20837a80853ca43c9d91.jsonl`：匹配原始逐帧日志。
- 同目录 `session-4f511d620ca23b8572dafb3f.jsonl`：剧情原始逐帧日志。两条路线的collector队列、丢弃、解析/发送错误及落盘错误均为0。

## 小地图过期缓存：实际重烘与另包复测

`6d09f056` 匹配日志包含 `Stale minimap input scene/Crater.lua`，回退现场捕获。prepare阶段记录约19944ms帧，已测Lua约182ms，残差不是独立GPU计时，不能据此把全部时间归给某个readback调用。过期由此前require提升改变三个签名脚本造成，不能只改元数据签名。

beta40第一次烘焙因向安装目录ResCache写缓存失败；原失败证据 `.tmp/match-map-bake-2026-10-16T14-07-28-206Z` 保留。runner改为项目内隔离Runtime副本，记录实际EXE及依赖SHA，第二次真实重烘完成。归档 `evidence/minimap-bake-2026-10-16T14-10-35-243Z/` 含请求、实际图像、参数、Runtime身份、原始日志和validation；1147输入、六项Native图像/生命周期断言、103缓存/校验检查通过。root实看1024图像。Native整体validation仍因帧尖峰FAIL，最大17332.9ms；这不是实战性能通过。

另包 `manifest-c4d2c399`，冻结 `.tmp/outgame-cached-1792159907197`，Lua指纹与6d候选相同。普通4475/QA4476的实际HTTP与537Lua逐字节检查通过。真实匹配进入、驾驶开火、返回大厅136检查通过，127直接明细帧；运行错误0，收集器600条已发送、0丢弃/解析/发送错误，关闭时1条仍排队，未宣称尾帧全部落盘。root实看active.png小地图及returned.png。

实际捕获对象 `baked=true, ready=true, gate=false, bakePending=false`，现场相机/worker/scene均不存在，生产Take后已释放。返厅units/vehicles/projectiles/effects均0。证据 `evidence/performance-route-match-1792159967175/` 含result、图像、逐帧timings及CSV；新短窗166个live帧平均46.06ms、P95 90ms、Lua27.78ms、2.61步/帧。加载activate仍出现4318ms长帧。该短窗与旧499帧场景/时长不匹配，不能计算整体提速；小地图缓存失效功能项关闭，Shader预热与持续CPU/30FPS继续OPEN。普通4471旧复现包未替换，未提交/推送。

## 新包验收记录

| 项目 | 状态 / 待填证据 |
|---|---|
| 工作区Lua、冻结源、包载荷一致 | PASS：537份Lua逐字节相同；manifest与脚本SHA见上文。后续小地图重新烘焙不属于此包，需另包验证 |
| 普通新包HTTP与身份 | PASS：4473普通启动、4474公开路线的identity均为6d09f056；未替换4471 |
| 新包启动与反射预热 | OPEN：真实入口已录CPU/trace/截图且可揭幕；仍有启动长冻结及揭幕后8条shader编译日志 |
| 新包六车匹配驾驶/开火/返厅 | 功能路线PASS；性能OPEN：499个live帧平均47.73ms/P95 81ms，不满足稳定30FPS |
| 新包剧情接管/驾驶/开火 | s1短路线PASS；性能与全剧情OPEN：step2共458帧平均24.92ms/P95 35ms，且存在294–606ms尖峰 |
| 关闭监控的完整场景前后对照 | PENDING：固定阵容、分辨率、操作路线和时长 |
| Git整合/同步 | PENDING：实际提交和远端SHA；构建不会随Git推送自动更新 |

## 仍开放的验收

- 骁龙845在TapTap内长期稳定30FPS：尚无该设备证据，需最终发布方式、连续战斗/发热后帧时间与内存验证。
- Web首次进场、开火、破坏、多车交火、退场/再进的完整帧耗时与长时间内存稳定。
- 启动未归因主线程长任务的引擎/浏览器CPU归因；渲染线程/GPU时间不能从当前残差推算。
- G0–G6原有未关闭项，包括完整自然剧情、各模式、模型/物理/界面一致性和真机横屏回归，沿用原清单。本轮局部优化或Git收口不关闭它们。
