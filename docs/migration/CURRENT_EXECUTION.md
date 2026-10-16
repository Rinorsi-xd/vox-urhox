# 当前迁移执行位置

## 2026-10-16 最新交接：飞机响应与私有 GitHub 同步

- 当前仍为 `1016`；H5 基线实核 `2026-10-15@b276064942ae09c0227ec28d4cfda1d5ff006455`。用户明确要求完成后上传、清理分支；本轮已获同步授权，下文“不自动推送”是此前历史状态。
- 1016整合基线 d910f11d 已上传私有 GitHub。飞机后续修复见 `G1_FLIGHT_RESPONSE_1016.md`：真实 Bullet/Rapier 对照定位重心、惯量与阻尼差异，恢复机翼和推进器角响应，不凭感受改升力参数。
- 534 Lua 编译通过；16组真实物理轨迹平均姿态误差 3.6393°→0.2547°、平均位置误差0.7066→0.1461米；无翼raceCar共240步逐字段零差异。不是地图碰撞、主观操控或手机性能验收。
- 最终 `main` 与 `1016` 同步到本轮提交；已清理四个历史远端分支，旧复现快照保留为 `archive/engine-handoff-2026-10-15-706d` 标签。实际远端SHA以本轮推送后ls-remote核验为准。
- 旧缓存Web包没有因Git推送自动更新；Web同步方需从新提交重构建。G0–G6其余开放项和骁龙845长期30FPS仍保留，不因本轮Git整理标为完成。

## 2026-10-16 当前交接：1016 协作基线（以下旧包记录只作历史）

- 用户要求本批优化与问题验证后整合 Git，提供 Web 同步基线。当前工作分支为 `1016`，H5 对照仍为实核 `2026-10-15@b276064942ae09c0227ec28d4cfda1d5ff006455`；不重启 G0，不把本批范围冒称全迁移完成。
- 本批包括已有 require 提取/地形采样/出生预建等候选，新增玩家损伤修复增量显示、射线与螺旋采样分配优化、炮管范围缓存、巨型车两次蓝图解析分帧、扫描线移除、ESC 统一暂停入口、打捞同价顺序，以及用户最后追加的高分辨率剧情/片尾通讯尺寸问题。
- 三组 Native CPU/等价探针在整合后重新运行 PASS；全 533 Lua 语法门禁 PASS。原始记录与可重跑脚本显式入库，见 `PERF_1016_HANDOFF.md`。桌面 Native mobile 画质两段 60 秒实战 P95 为 74/88ms，仍不稳定；骁龙845/TapTap长期30FPS未验收。
- 4453 仍是旧 `8b6203a3` 包，不能验证新改动。Web 同步应重新构建 `1016` 并记录提交与 manifest；不自动发布/推送。
- 新本地候选已构建 `manifest-c66ba2e1.json`，533Lua/指纹 `fbcd24baa69cf166534ff3d648d7b816966d4f3d75ce8c6907a6678656e30b59`；普通4461、QA4462。全Lua工作区/冻结源/包字节一致及真实HTTP载荷PASS。预提交构建identity父SHA仍48ef，详见handoff解释，不能当远端已同步或Web实战通过。
- 已合并本地10/13、10/14、10/15分支清理；孤立历史引擎快照保存在 `archive/engine-handoff-2026-10-15-706d` 标签，禁止把其465 Lua旧树合并回生产。
- 此处与 `PERF_1016_HANDOFF.md` 是当前接续入口；下文“当前”“本次”等标题均为历史过程，不覆盖本节。

## 本次交接：固定优化验收包，不扩大范围

- 用户当前要求仍为“先把我说的优化合并我去验收一下”。重新实际请求普通4453：HTML、identity、manifest与main载荷均200；manifest/main与冻结8b6203a3包实际字节一致，529 Lua、非QA。验收地址保持4453，不以新功能候选替换。
- 固定包已包含线性采样/anisotropy1、地形FLOW_CONTROL及导出器、敌车显示预建、导航距离缓存和此前换车分帧。已有Web短刷敌功能证据；长加载、OOM和持续性能仍OPEN，没有本轮新增commit/push。
- 下节f9状态已过期：统一审计为151报告；建造第二轮Web已结束，71项PASS_WITH_OPEN、运行错误0。数量Web已结束，21项后发现鼠标移出数字框仍触发滚轮，原FAIL保留；SalvageQuantity局部修正已冻结，200项离线检查通过，尚待新包Web复验。
- MissionRules死亡安装进度窄修已冻结，相关检查实际重跑通过；受击表现子线仍在离线验证。两者均不属于8b验收包。当前没有测试GPU进程，旧S3的RUNNING存盘已用interruption.json注明中断，勿据此重启或误签。

## 当前 goal 接续：f9b98d5f 三线功能合包实测

- 上一轮优化验收交接属于进展：实际HTTP再次核验、固定8b入口、终止后台GPU并保留中断边界。不是重启G0。当前继续10/15全G0-G6目标，不同步main、不推送。
- 新候选 `.tmp/outgame-cached-1792142468868` / `manifest-f9b98d5f.json` / fingerprint `610b70d42e72a44cec092b93f7491825d7a2de85b749df956fbdb78ec8675182`：531 Lua。普通4457/session18507，QA4458/session36280；实际HTTP身份/manifest/main字节PASS。8b/4453继续固定供用户验收。
- 只比8b新增/修改7份生产Lua：BuildSession、BuildInput、SalvagePage、SalvagePaint、新SalvageQuantity、MissionHud、新MissionPrompt；资源内容0变化。实际统一审计PASS、148份注册报告关联无漂移；新功能结果不能借8b旧Web签收。
- G2输入523源消费/2旧包负控；G5数量与检视184项/23源场景/6负控；G4提示771项/60源场景/9死亡边界/6负控及独立Chrome CSS真实采样。提示补CSS反向淡出缩时，并按源死亡期间保留prompt快照；不改任务规则。报告分别G2_BUILD_INPUT_CONSUMER、G5_QUANTITY_INSPECT、G4_STORY_FEEDBACK_2026_10_16.md。
- 实际建造首轮Web session4317已exit1/CLOSED：30项操作断言通过后，第二次拉伸入口超时，运行错误0、截断探针JSON1；原失败完整保留 `evidence/build-input-web-manifest-f9b98d5f-2026-10-16T09-22-25-443Z/`，root实看entered/failure图。子线正在区分工具与生产状态，不签整条通过。
- 当前唯一agent GPU为quantity实测 session71657，证据 `evidence/salvage-quantity-web-manifest-f9b98d5f-2026-10-16T09-24-47-762Z/`；公开匿名独立会话，仅使用源testFill库存，不用真实账号。未回结果不得签交易、布局、长按或性能通过。
- 下一批只读核实受击镜头震、水平受击箭头、反应堆命中反馈及死亡任务时序，现阶段不改生产，避免当前同包实测漂移。仍保留完整自然剧情/搜撤/无尽、长冻结/OOM、真实账号和真机性能OPEN。

## 最新用户验收交接：优化包保持 8b6203a3

- 最新请求是“先把我说的优化合并我去验收一下”。本轮重新实核普通4453返回200，普通4453与QA4456的HTTP身份、manifest、main实际字节检查PASS；线性过滤、anisotropy1、terrain FLOW_CONTROL及导出器保留再次独立核对通过。用户验收入口仍为4453，不重复构建、提交或推送。
- 为释放用户验收时的GPU，主动Ctrl+C结束第三关长测runner session57663（exit1）。该次测试未完成，不签通关、内存稳定或性能通过；原result.json中RUNNING为中断前存盘，详见同目录interruption.json，禁止恢复后误认仍运行。
- G2输入和G5数量/检视的新生产改动不属于8b包；G5已冻结，G3/G4提示仍在开发。后续另行整合，不让同一验收URL内容漂移。

## 当前接续：验收版保持，继续 G2 / G3-G4 / G5 三线功能

- 上一轮已完成用户“先合优化验收”：8b6203a3 / 普通4453继续有效。当前是active goal继续全部G0-G6，**没有新同步main请求**；历史“同步更新main”为已执行旧请求，不能在恢复后当作最新指令、停止开发或重复推送。
- 源10/15分支当前实核仍b276064942ae09c0227ec28d4cfda1d5ff006455。G2 BuildSession/BuildInput滚轮与鼠标源行为修正已冻结，523实际源消费/旧8b两组负控及124/541/607关联检查通过，尚未加入8b不可变包。
- G5独占SalvagePage/SalvagePaint/新SalvageQuantity，补商人数值输入/滚轮/400ms后70ms加速重复及整备检查页售卖；实际源182检查/23场景/6负控通过，待最终交叉审冻结。G3/G4独占MissionHud/新MissionPrompt，补源install/capture/dead提示，正在实现，不为同步main擅停。
- 长局调查未证实渲染Lua所有权泄漏：当前/旧2797各30轮3车生命周期回基线，旧末230秒缓存稳定；QA全状态累计68.4MB占日志99.27%，是已确认的观测负担但不是OOM唯一根因。详见G3_LONG_BATTLE_MEMORY_2026_10_16.md。
- root仅QA新增显式--story-route投影，完整story/驾驶/相机/目标/内存不变，只保留启用的battle计时子集并停自动重复输出。192实际状态Lua投影14216断言/2负控通过，序列字节减少48.9%；不进入普通游戏包，不签OOM解决。旧完整模式与F8/F13/F14仍保留。
- 当前唯一agent GPU为8b第三关自然长测：QA4456/server session36964，runner session57663，证据 `evidence/story-natural-s3-manifest-8b6203a3-2026-10-16T09-04-35-981Z/`，600秒自然命令，未开启F15，无跳过/改血/改时/代杀。共享用户机器，不能拿它签隔离性能。未回结果不得签通关或内存稳定。

## 当前验收版：8b6203a3，按用户要求先合优化

- 用户最新要求“先把我说的优化合并我去验收一下”。已整合当前工作区并生成不可变包 `.tmp/outgame-cached-1792140646894` / `manifest-8b6203a3.json`，529 Lua，fingerprint `093567d5747f4e2a4e121ff4cbadd4e992e1a0da1c79d880b43c10d2ec5f5bfb`。普通4453/session86618，QA4454/session34070；HTTP实际身份/manifest/main字节检查PASS。没有新增commit/push，也未变更main提交。
- 包含线性过滤/anisotropy1、terrain FLOW_CONTROL及导出器保留、敌车最多8台纯显示预建和原时点消费、AI导航纯距离缓存；同时包含此前换车分帧、打捞加载/库存反馈/Debug候选。后者不是此次新增目标，已完成工作一并保留。
- 原生小地图已真实重烘，1147输入，6项渲染功能断言PASS、Lua/资源错误0；完整validation因长帧仍FAIL，最大2094.46ms，不签性能改善。与旧2797长测尾段有GPU重叠，且编辑器runtime同时在用户环境运行，不用这次烘焙帧时间比较优化收益。检查器仅新增FLOW_CONTROL精确差异及EOL归一化断言，实际再跑PASS。
- 敌车预建3780断言/9生命周期/5真实Mission场景/5负控PASS，相关21报告实际重跑；导航36436检查/3负控及实际EnemyDriver序列一致性PASS。GPU首用shader、内存及持续帧率仍待实测。
- 旧2797第四关自然长测session49828已exit1/CLOSED：6阶段，最终Aborted(OOM)、F8超时，不能签完整关卡或稳定；保留 `evidence/story-natural-s4-manifest-279727d3-2026-10-16T08-35-25-117Z/result.json`。这是旧包，不能推断新包已修复OOM。
- 新包短首刷检查session73171已exit0/CLOSED，证据 `evidence/story-natural-s4-manifest-8b6203a3-2026-10-16T08-52-36-826Z/`：3检查PASS、错误0，真实0→3敌及12123ms观察、正常返厅arrayBytes0。root实看entered/first-spawn-window两图；Web日志实际编译FLOW_CONTROL地形PS。F15测首刷VehicleView.Rebuild为0次，DriveView.New3次合计2ms、CombatView.Consume最高8ms；Tick全窗口峰94ms，不签整局不卡、GPU提速或内存稳定。首次场地下载63.5s、scene9.8s、collision6.6s，长加载仍保留。
- 最终统一审计PASS：529Lua、146报告，关联freshness零漂移；实际HTTP身份及载荷PASS。普通4453已打开供用户验收，本地候选整合完成，不再重启G0或扩大本轮范围。

## 当前接续：地形 FLOW_CONTROL、出生预建、导航与库存反馈并线

- 上一轮是有效进展：279727d3线性采样/打捞加载/Debug真实Web验证完成，不重开G0。最新用户要求在`assets/Crater/material-1.xml`第3行加`<shader psdefines="FLOW_CONTROL" />`，已精确加入；导出器同步terrain分支，XML与Python AST检查通过。详见`G6_TERRAIN_FLOW_CONTROL_2026_10_16.md`。尚不属于2797旧冻结包，未以旧包签shader/GPU性能或更新旧小地图捕获签名。
- 当前唯一GPU为2797/QA4452第四关自然完整路线，root exec session49828，证据`evidence/story-natural-s4-manifest-279727d3-2026-10-16T08-35-25-117Z/`；780秒驾驶命令时限，F15计时真实启用。尚在运行，不能签完成。
- G3出生预建线独占SpawnViewCache/CombatView/DriveView/VehicleView/PartRig；root接Mission/TrialSession：加载阶段有限8台纯显示预建，按源事件原时点取出绑定，缺失/耗尽回退原路径；物理/伤害/武器系统不提前。候选待真实模块等价与生命周期检查及新包测量。
- G1/G3持续开销线独占EnemyDriverNav：每次查询缓存纯距离/heuristic，不改jitter次数顺序/寻路tie/碰撞结果。G5独占SalvagePage/SalvageItem补全车库缺口红边、真实loose道具及原数量格式；各线尚未统一冻结/构建，不能套2797结果。
- 找到并实核此前bb6e第五关结果为PASS：真实射击Boss死亡、四次跪地、S评价、自然片尾出现及回厅arrayBytes0、0运行错误。文件`evidence/story-natural-s5-manifest-bb6e7933-2026-10-16T05-40-34-475Z/result.json`；仍需实看其画面及逐页片尾证据，不借此签新片尾动效或全视觉/音频/性能。

## 当前接续：打捞入口、换车、库存与 Debug，并改线性采样

- 用户最新追加：显式各向异性改普通线性。陨坑 albedo/nra 数组 XML 改 trilinear，标牌/贴花 shader 改 filter_linear_mipmap，导出器同步；全局默认 FILTER_TRILINEAR、anisotropy=1，并在 Stop 恢复引擎原值。像素输入改变，必须真实重烘小地图，禁止只更新输入签名。
- root 补 app.LobbyLoading：大厅→打捞仓库独立源加载页、六项实际准备、逐项呈现帧门槛；不是实际出击地图加载，也不覆盖改装返回。仓库分批搭建并延迟激活，shader 预热只做一次；取消与迟到回调有代际隔离。等待新包 Web 验证。
- HomeVehicleSwitch 改台下协程装配，保存/回滚完成才升起；逐零件检查点可让帧，单零件和最终表面提交仍不可切，不能许诺每帧硬 3ms。实际 CPU 事务与旧实现负控通过，Web待测。
- 打捞库存：缺 draft 不再覆盖 slot1，按已有 active/有效车位恢复；新旧仓库赠品区分。出发前恢复原版超库存禁用提示，保留真实总库存限制。已知1120轻方块大车超过999是合法缺口，不得直接绕过。用户旧会话具体库存尚未取证。
- Debug 整套原来未迁移，新增用户调试面板/动作由独立子线实现，local Web 显式 -vox-debug=1；引擎保留的 -debug 参数会在 Lua 前触发启动错误，已避开。QA F8继续只读探针，非发布默认全开，不能说原版全部Debug能力已闭环。
- 当前仍为 main@48ef15f2 后未提交候选，不重复同步/推送。此前 188b 证据仅历史包；下一包冻结、审计、真实点击/截图后再给入口。

- 最新冻结 `.tmp/outgame-cached-1792139145715` / `manifest-279727d3.json` / fingerprint `0a623324f52c2694050d3bc8a19110970b0feea9fcb498f814cdc7e7e80789e8`：528 Lua、HTTP及统一审计PASS。普通4451、QA4452。真实Web打捞入口/六项准备/新会话起步车出击/Debug初始化8检查PASS、运行及资源错误0；入口耗时17,244ms，不能称加载提速或流畅度通过。证据 `evidence/lobby-loading-manifest-279727d3-2026-10-16T08-27-38-171Z/`，root已实看tablet加载页与Debug打开截图；PC首次截图落在黑色转场，修正工具为reveal后再拍，待补证。
- 线性过滤已独立只读复核，scripts/assets显式各向异性覆盖无残留。实际小地图重烘及限制见 `G3_MINIMAP_LINEAR_BAKE_2026_10_16.md`，native捕获功能6检查通过，但仍有3次>100ms长帧，最大164.48ms，不签性能通过。用户旧账号库存与自然完整流程继续OPEN。
- PC转场截图已补证：`evidence/lobby-loading-manifest-279727d3-2026-10-16T08-31-18-690Z/`，工具等待真实loading阶段且pageFrames>=2后截图，7检查PASS、错误0、16,794ms。root实看loading-pc.png为完整六行加载页，前一轮黑图是reveal前截帧，不能作为加载页视觉故障证据。最新用户采样改动已合入4451候选；没有提交或推送。

## 当前接续：188b 首刷归因完成；下一包补反馈与地图缓存

- 新包 `manifest-188b9f11.json` / `.tmp/outgame-cached-1792137130284` / fingerprint `559ce27637b23d125c678d8f56b4265baf52a3e2292a7440f5abca94d183e180` 已合入 CarUnit 等价减少排序/空修复；普通4447/session78841、QA4448/session64570，HTTP身份和实际main字节审计通过。后续候选已继续改动工作区，因此该包不能称与当前工作区全部一致。
- S4首刷短诊断 session6922 已exit0/CLOSED：6检查、运行错误0、真实F15/0→3敌/12,409ms窗口/正常返厅arrayBytes0。root实看首刷截图；Tick峰151ms，其中同一嵌套装配窗口122ms、三次VehicleView.Rebuild共120ms，定位到显示装配。后续415Tick平均14.45ms、固定步1.89/Tick；非完整关卡或真机性能验收。详见 `G3_FIRST_SPAWN_WEB_2026_10_16.md`。
- 下一包：击杀积分原CSS缓动/连破色/阴影与bump实际浏览器优先级；小地图缓存生命周期签名分类修正（1146真实像素输入和原图不变）；打捞超时原文与演出统计计时。各子线独占文件，完成后再统一构建，不能借188b签新功能。
- 修正上一节候选描述：打捞“源已关闭旧引导”的初判被校验SHA后的实际JS执行推翻，已撤回生产和旧检查改动，保留正确原目标算法。新报告 `G5_EXIT_CONTRACT_2026_10_16.md` 记录误判与反证。共享回归工具的历史负控已固定真实9541修复前代码，不再依赖移动HEAD。

## 当前接续：main 已同步；战斗开销与 G5 恢复并行收尾

- GitHub `backup/main` 与本地 `main` 已实际同步到 `48ef15f2c9c95c400f91ee6e34309399d02b3733`，提交时间 `2026-10-16 15:35:59 +0800`；最新 `git ls-remote` 再次确认相同 SHA。下方同步前状态为历史，不再代表待推送。后续尚在验证的优化不自动推送。
- eb4f 首次匹配真实流程已 exit0/CLOSED：15 检查、144 样本、运行错误0，公开匹配入口、首次 DSP voice SoundSource 播放、prep→live、设置音量修改/恢复、正常返厅通过。证据 `evidence/match-radio-web-manifest-eb4f7ad2-post-main-2026-10-16T07-46-08-324Z/`；root 已看 live 实图。没有声部跨过设置操作，故在播增益即时变化仍未观测；不签可闻连续性或性能稳定。
- QA 首刷敌计时已冻结：实际 `ConsumeWorldEvents→CombatView.Consume→DriveView.New→VehicleView.Rebuild`，附最多五单位 driver/rotor/weapon，默认关闭；45 检查/8 负控及关联回归通过。新观测须新 QA 服务与 HTTP 身份审计，不借旧153ms运行签归因。报告 `G3_FIRST_SPAWN_CPU_TIMING_2026_10_16.md`。
- G5 实际模块云恢复离线链61检查/5负控通过，覆盖无尽检查点、清文件新会话恢复、打捞结算幂等/失败回滚、在途版本、坏记录、墓碑和账号切换。受控 SDK 不等于真实账号，后者及自然成功撤离仍 OPEN。报告 `G5_CLOUD_RECOVERY_2026_10_16.md`。
- 当前并线：CarUnit 等价减少预算/核心重复排序与满车空修复；QA 首刷敌短诊断正常返厅；修正部分回归工具负控依赖 HEAD 的过期边界。冻结后统一合包，再实测首刷与持续负载。G0–G6 总目标保留，不重开 G0、不把局部测试当完整1:1交付。

## 当前接续：按用户明确要求同步 main

- 用户最新明确要求“同步更新一下main分支”，取代下文等待稳定才同步的条件；本轮整理最新迁移集成内容提交到本地main并推送GitHub backup/main。此同步不代表稳定版、完整1:1迁移或性能验收通过。
- 同步前main及GitHub实核均为9541dc59，候选为manifest-eb4f7ad2；本轮重新实际执行统一审计PASS，524Lua及132报告/779关联零漂移，git diff --check通过。
- 提交包含当前源码、必要新增音频/字体/图像及meta、迁移工具与交接说明；临时缓存/构建/大体积运行证据按既有gitignore留在本地。运行入口scripts/main.lua；H5基线仍2026-10-15/b276064942ae09c0227ec28d4cfda1d5ff006455。
- 已知阻断继续保留：首次刷敌153ms长帧、长加载/音频连续性、旧S3 OOM未关闭、S3/S4完整通关及同包五关回归、完整视觉与移动真机性能。详见DEPARTMENT_HANDOFF_STATUS_2026_10_16.md。下方“不提交/不推送”为历史事实，不再是本轮约束。

## 当前同步要求：稳定后更新 main 给其他部门

- 用户最新授权取代历史的绝对“不上传”限制：当前版本趋于稳定后更新 main 供部门同步；稳定条件未成立前不将候选标成稳定交付。
- 本轮实际核对：本地当前已经 `main@9541dc59ef2f281cafa5126762a57550189e04dc`；`git ls-remote backup refs/heads/main` 确认 GitHub main 同一提交。最新迁移在未提交工作区，1682文件（195 tracked修改、1487 untracked、0 staged），不能说其他部门拉main可拿到eb4f。
- 最新候选 `manifest-eb4f7ad2` 已通过构建、统一载荷/报告关联及HTTP检查；尚无该构建自然全流程/可闻音频验证。历史开篇650ms长帧与1015ms音频间隙、S3旧WASM OOM及严重战斗慢帧仍未关闭；S3/S4完整自然胜利及同构建五关回归未完成。因此本轮判定不满足稳定同步条件，没有新增commit或push。
- eb4f S4自然 session65800已exit1/CLOSED：INCOMPLETE，1324样本/9阶段/5入口与返厅检查通过/错误0；540秒指令期限内完成A/B夺点、反扑与涂鸦，12真实击杀/8死亡，C未完成。正常返厅arrayBytes0、实际大厅环境音恢复；root已看entered/deadline实图。不能签整关成功，也不能把超时判为第三处生产关卡故障。此次GPU已结束。
- F15真实测得首次0→3敌Tick峰153ms；t45.267→128.383持续窗口Tick均29.37ms、BeforeStep15.30ms、World3.91ms（含Space3.18，不相加），4987固定步/1789Tick约2.79追赶步。首刷敌装配与持续控制/武器负载分开处理，不称物理单独根因。详见 `G3_EB4F_S4_RUNTIME_STABILITY_2026_10_16.md`。
- `DEPARTMENT_HANDOFF_STATUS_2026_10_16.md` 已整理候选身份、必要新增资源、实际引擎缓存版本与QA恢复边界。后续先核首刷敌同步装配路径/持续BeforeStep开销、首次匹配声音和S3/S4剩余自然成功；关闭稳定阻断再整理更新main，排除临时构建与大体积调试产物。不重开G0，不用CPU报告代签稳定。

## 当前接续：大厅环境音减半，后半剧情继续

- 用户新增要求大厅环境音降低：`GameAmbience` 仅对 `amb_hangar` 乘以0.5（原始目标0.14→0.07，约-6dB）；保留原素材配置、淡入淡出与音效设置联动。本轮合包前实际重跑环境音检查，不借旧包签新增音量。
- 本轮新包 `.tmp/outgame-cached-1792130289040` / `manifest-eb4f7ad2.json` / fingerprint `70f6957345a9c29a803744d5bdbe0a9e1707cc484862ba3b1b81e92661ad1960` 已构建。普通4445/session77807，QA4446/session28944；实际HTTP身份/manifest/main载荷审计PASS。统一审计524 Lua、132报告/779关联/0漂移，资源内容无变化；环境音480源case/102检查/4负控PASS。相对41f只有GameAmbience、BattleFlow、BattleController、LoadingFlow四份生产内容变化。
- 用户IAB仍停留旧4422；尝试只读实看返回0-width无法截图，未强行重载或改其游戏进度。已提供4445新版链接，未宣称新包可闻/自然通关或不卡。下一步串行S4自然路线及匹配声音实测，QA可用F15细分CPU计时。
- 旧bb6e S5自然 session29924 已exit0/CLOSED：8检查PASS、运行错误0，真实Boss三阶段/4节点/4次跪地、0死亡、S级结算；完整43秒结局、自然片尾18/18阶段与正常返厅均已观测。证据 `evidence/story-natural-s5-manifest-bb6e7933-2026-10-16T05-40-34-475Z/`。这是旧包功能证据，不签41f新盖章动效、逐页画面或可闻连续性。Update常100–160ms，性能仍OPEN。
- 下一包同时纳入已冻结BattleFlow/BattleController/LoadingFlow准备边界；F15 QA计时已冻结。新包完成审计后继续S4及匹配音频验证，不重播前半替代后半。

## 当前接续：41f38aac 声音生命周期与片尾动效合包

- 本节覆盖下方历史，不重开 G0、不提交上传。10/15 源 HEAD 本轮再次实核仍为 `b276064942ae09c0227ec28d4cfda1d5ff006455`。最新生产冻结 `.tmp/outgame-cached-1792129688087` / `manifest-41f38aac.json` / fingerprint `684b238024fae0c6ade0f0e10f4c0ae761cfac2d863c18babc5387d2cb245d12`，524 Lua。普通4443/session66368，QA4444/session9684（QA observer 正在更新，须更新后重启并实际HTTP审计）。
- 实际统一审计 PASS：524/524 Lua 载荷、130 报告/767 关联/0 drift、99资源/11字体/12voice；相对 bb6e 只有5个生产脚本内容变化，资源内容0变化。证据 `evidence/unified-snapshot-manifest-41f38aac-audit.json`、`snapshot-manifest-41f38aac-delta.json`。后续生产若变，不借此签当前工作区。
- 已合入：StoryPageVoice/UiSound 下载完成回调仅记录结果，在各自 Update 限量后台准备；玩家死亡仍保留伤害声音和延后爆炸，暂停/退出照常停；片尾批准章按原1.6秒延时/.22秒缩放/.15秒透明度渐入，最终驳回章保留到原800ms退出结束。字幕与原素材未删。实际旧bb6e负控及直接关联回归已执行。报告 `G4_AUDIO_COMPLETION_BOUNDARY_2026_10_16.md`、`G3_FEEDBACK_DEATH_LIFECYCLE_2026_10_16.md`、`G4_EPILOGUE_STAMP_MOTION_2026_10_16.md`。新合包尚无自然/可闻/视觉签收。
- 明确撤回错误候选：原 H5 的 kill_confirm 确实经 MATCH_FLOW_LIVE 进入 duck；当前保留原规则，没有取消击杀压音。先前只读结论不成立，已用实际冻结源 cue registry 核正。
- 当前唯一 GPU 仍为**旧bb6e** S5自然 session29924/QA4442：进入Boss真实第二阶段，已观测节点伤害/断节点及多次跪地，尚未通关；源规则未改。不能用旧GPU签41f片尾修复。证据 `evidence/story-natural-s5-manifest-bb6e7933-2026-10-16T05-40-34-475Z/`，720秒自然驾驶上限，待最终回结果。
- 下一候选（不属于41f）：native_check_repair 处理 BattleFlow 首次事件仍同步准备 Sound 的遗漏，涉及原音频资源准备、加载期checkpoint及匹配ready边界；g1_parts_current 仅QA新增F15显式开启的Trial细分CPU计时，默认关，不碰生产。两者完成后再统一核包，不覆盖既有自然证据。
- bb6e S3实际entry-only6项PASS、正常返厅/arrayBytes0，root已看图。原331 shader全保留、新增的非实例unlit VS/FS在9e5d及46ba旧日志中已出现，不能归因本次分组；严格331比较器原FAIL保留。预热429→315组但scene15.719s/combat16.779s，未证明加速。完整S3、修正路线后的S4、S5及片尾、长冻结/音频连续性、全视觉1:1和移动真机仍OPEN。

## 当前接续：bb6e7933 预热去重与 Boss 漏段修复合包

- 本节覆盖下方历史，不重开 G0、不提交上传。源仍为 10/15 `b276064942ae09c0227ec28d4cfda1d5ff006455`。最新 `.tmp/outgame-cached-1792128891583` / `manifest-bb6e7933.json` / fingerprint `ffee59b78c0707d7267ecaf7fe733d295f5ef13ace30e3b288af398a62703ec1`，524 Lua。普通 4441/session7180、QA 4442/session27920；HTTP 实际身份/manifest/main 已 PASS，统一审计另由 native_check_repair 实际执行。
- 新生产增量：TrialSession 只在当前 Boss 演出内 fresh Enter 长按才跳过，普通战斗不再遗留 skip 跳过整段结局；Boss 登场/阶段补回源 camera trauma。H5 自身陈旧 holdAt 跨阶段复用的两个边界已明确记录当前保守差异，不伪称所有历史输入 1:1。报告 `G4_BOSS_AUTHORED_IMPACTS_2026_10_16.md`。
- bb6e 实际统一审计已 PASS：524/524 Lua 实际载荷、127 报告/747 关联/0 drift，99 资源、11 字体、12 voice。证据 `evidence/unified-snapshot-manifest-bb6e7933-audit.json`；相对 46ba 仅 4 个生产脚本内容变化，资源内容无变化，metadata 单独列出。该审计不替代自然剧情或可闻/视觉验收。
- bb6e S3 entry-only/session51183 已 exit0/CLOSED：6 检查、运行错误0、真实进场及正常返厅 arrayBytes0；F14 实际采样 9771 节点/7670 组件。root 已看 entered.png。CombatWarmup 实际 429→315 组、224 eligible/205 rejected/0 errors、161 帧；本轮 scene15.719s/combat16.779s，未证明加载提速。原331个 shader path+defines 全部保留，新增2个同 unlit 的非实例 VS/FS；严格331比较器 FAIL 原样保留，不能写成完全同集通过。证据 `evidence/story-natural-s3-manifest-bb6e7933-2026-10-16T05-37-43-890Z/`。此路线不射击、不通关。
- 当前唯一 GPU 为 bb6e S5 自然整关 session29924/QA4442，证据 `evidence/story-natural-s5-manifest-bb6e7933-2026-10-16T05-40-34-475Z/`，720 秒驾驶上限、正常输入，不跳演出/改血量/注入成功。结果未回不得签 Boss/片尾通过；之后继续修正入口后的 S4，不能回头反复代验前半。
- 本轮后续候选分工（尚不属于 bb6e）：g1_parts_current 独占 Epilogue/EpilogueMotion 补批准章原渐入及最终驳回章退出；continuity_targeted 独占 StoryPageVoice/UiSound，下载回调只标记后再 Update 准备；native_check_repair 独立只读核首次驾驶反馈/声音配置与新增 shader。root 串行 GPU，保留既有字幕，不提交上传。候选必须重新合包后再给用户，不能用 bb6e 实测签新改动。
- CombatWarmup 首次全隐藏、后续仅隐藏上批露出列表；完整已知 StaticModel 材质/顶点布局才合并预热代表，未知 API/LOD/骨骼等保留原路径，同模型实例原子组及单实例隔离保留。合成检查不能代替 GPU shader 集覆盖。报告 `G3_COMBAT_WARMUP_MASK_WORK_2026_10_16.md` / `G3_COMBAT_WARMUP_SIGNATURE_2026_10_16.md`。正在实际 S3 入口比较全部原 331 shader path+defines；未回结果不签提速或视觉通过。
- 46ba S3 公开驾驶/真实选项 2 已执行，原 pc.json FAIL 保留。F13 实际 full180 投递成功；失败来自截图期间自动 F8 覆盖全局 state，已采三个冻结样本重放有 312 唯一帧、15 held/69 exited。工具改为冻结样本合并，11 检查/6 负控通过。该轮未执行返厅，不补签整条 PASS。
- 46ba S4 自然 session76867 已 exit1/CLOSED：540 秒限时、1762 样本、0 运行错、未出 A/go，正常返厅 arrayBytes0，环境音正确。root 已看 stage-2/deadline 实图，翻车停在护栏旁。只读精算确认 103041 个高度与源完全相同、车辆轮尺寸/源护栏相同、出生不重叠；真正自动输入问题是最近路点 bEt 的自由直连穿 Hull230 且跨 28.26 度沟，非原 nav 边。QA 新入口筛查选择平坦 bP，并保持原图/目标/Dijkstra；生产地图/物理未因此修改。新 S4 自然通关仍 OPEN。
- 新 QA probe `af35046c...`：F8 只小型 Lua 池计数，F14 才当次场景节点/组件统计。natural 工具在阶段截图前明确请求并立即冻结 F14 样本，15 秒超时，不每帧遍历。不能把 heap capacity 当 allocator 已用内存，也不能签旧 OOM 已修。
- 仍 OPEN：S3-S5 自然完整关卡/Boss/片尾、长冻结/音频连续性、全视觉 1:1、无尽/打捞完整自然成功及真机性能。首关 S、第二关 B 的真实通关证据保留。用户现有标签待最终实看后切新普通包。

## 当前接续：46ba9168 已合包，串行后续剧情验收

- 本节覆盖下方历史，不重开 G0、不提交上传。源仍为 10/15 `b276064942ae09c0227ec28d4cfda1d5ff006455`。最新 `.tmp/outgame-cached-1792127759340` / `manifest-46ba9168.json` / fingerprint `7d30cbc7d7dc91121e45a9c520f5b3a3ba3320d5b99dc8a8df45f4aba5de1c1f`。普通 4439/session94466，QA 4440/session45174；HTTP 实际身份及载荷已通过。
- 本包包含完整本关语音闭包、默认 wave/遭遇战标签、签约盖章与闸门冲击、电视切断原 1800Hz 低通。相关检查与旧实现负控已实际执行；它们不是可闻、自然通关或性能验收。523 Lua 实际载荷身份一致，关联报告已实际补跑，最终统一审计由 native_check_repair 收尾。
- QA 默认状态仅输出最后一个演出样本，F13 才请求完整 180 帧历史。实际浏览器键投递仍由当前 story-presentation session33640 验证；不能把日志缩小称生产 OOM 已修。
- Boss 自然输入主工具已完成接线，含 cockpit/braced、非攻击阶段释放输入、返厅前捕获 completedCampaign 及 F8 15 秒超时；旧文“尚未接线”已过时。自然 S5/Boss/片尾仍未验收。
- 当前唯一 GPU：46ba / QA4440，公开 S3 入口、驾驶到 gate、实际选项 2、退场返厅，证据 `story-presentation-manifest-46ba9168-2026-10-16T05-17-47-979Z/`。结果未回不得签 PASS。完成后直接推进 S4、S5 自然路线，不反复重播前半代替后续。
- 并行线：continuity_targeted 定位场景/战斗预热长等待；g1_parts_current 对照 S4/S5 后半演出漏项；native_check_repair 完成本包统一审计。生产修改先报文件所有权，root 串行 GPU。
- 首关 S、第二关 B 完整自然通关的既有证据保留。S3 旧 OOM、长冻结/音频连续性、全视觉 1:1、S3-S5 自然通关、无尽/打捞完整自然成功及移动真机仍 OPEN。用户标签尚未切新普通包，需实看后更新。

## 当前接续：82d01bdc语音分关合包；9e5d第三关OOM失败已关闭

- 本节覆盖下方历史，不重开G0、不提交上传。继续10/15 b276基线；最新冻结 `.tmp/outgame-cached-1792126975801` / `manifest-82d01bdc.json` / fingerprint `ad213bcecaa6bc9bcdabc527cfd1a63d2e0fef28951b4dfbf740f982afd14822`。普通4437/session82980，QA4438/session18753；HTTP实际身份/manifest/main通过。仅StoryComms/Mission两份生产Lua内容变化，资源内容无增量。
- 语音按本关完整文本闭包阻塞预载，涵盖深层选项、失败重试、复活、S/A/B结算；S1实际Quote默认三句纳入，S5独立Boss/片尾保留，无参调用仍全量。2950检查、两份实际旧9e5d负控、15关联真实重跑与独立只读交叉审通过。尚未用Web测新包时长，不能许诺解决35秒下载。窄报告 `G4_STORY_VOICE_SCOPE_2026_10_16.md`。
- 9e5d第三关session47979已FAIL/CLOSED，不再进行中。真实5杀、6次守点失败、1607样本，游戏约335.48秒出现WASM_OOM，heap1719533568/request1766825984。OOM后键盘await挂住，root核进程树后仅结束本轮测试Chrome37844及子进程；最后工具退出1。原始日志/result保留，不把终止后的keyboard错误当OOM根因。证据 `story-natural-s3-manifest-9e5d7ed6-2026-10-16T04-55-04-396Z/`。不能签S3通关或稳定。
- S3能量/波次/AI参数与冻结H5一致；约3敌进入70m圈可30.3秒耗尽，不能单凭站中心自动操作失败更改玩法。确定差异为未显式tag的beats缺H5默认wave，下一包MissionRules窄修及关联检查正在完成，不属于82d。
- OOM只读线：尾100状态资源缓存恒定、Lua内存波动下降，暂不支持车辆死亡泄漏；两次失败均积累大量F8日志，默认重复180帧presentation使日志巨大。正在减轻QA观测负担；尚未证明原生OOM调用归因，也不能宣布生产OOM修复。
- 下一批并行：原签约盖章/闸门冲击缺失补齐；默认wave标记；QA紧凑快照/完整演出按需采样。后两关Boss弱点输入helper已CPU39检查/6负控，probe已补真实cockpit/braced；打捞probe已补原倒计时和store回读。主自然工具文件apply_patch写入异常，Boss主工具接线尚未完成，不能签自然Boss。
- 已有首关S级、第二关B级、完整开篇功能通过证据保留；长冻结/音频连续性、全演出1:1、自然S3–S5/片尾、无尽/打捞完整自然成功、账号/真机性能仍OPEN。统一审计因下一包生产在工作区变动可FAIL，不能把82d称当前工作区全一致；下一批冻结后重新构建和真实重跑。

## 当前接续：9e5d7ed6已合包，第三关守区实战复验中

- 本节覆盖下方历史，不重开G0、不提交上传。基线H5 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`，目标HEAD9541保留脏工作区。
- 最新冻结 `.tmp/outgame-cached-1792126166169` / `manifest-9e5d7ed6.json` / fingerprint `e6a0d7e8cbc0c4c2aec583ec4d26bb0bfbc5459dd31915eadc441e93454f27e3`。普通4435/session20383/PID59640，QA4436/session28037/PID65452。523实际Lua载荷、115报告646关联零漂移、HTTP实际身份PASS。相对848f仅HangarApp/EndlessSession两份生产Lua变动、资源内容无增量。
- 本包新增：StoryComms下载回调只标记、Tick每帧准备一条语音；MissionView原守点静态圈/夺点完整圈及新目标归零；BossRules强制起身清预警标记；BossView逃生舱原XYZ摇摆/绝对尾焰尺寸/小运接替隐藏。四份窄报告均已登记统一审计。174、3186、1333、11684项CPU源对照及实际旧包负控通过；关联报告已实际重跑。它们不代表本包完整可闻/可见验收。
- 第三关自然路线session45189已结束exit1/CLOSED，证据 `story-natural-s3-manifest-848f4d10-2026-10-16T04-35-05-101Z/`。480秒指令期限、1070样本、运行错误0、5入口/环境音/返厅释放检查通过，但最终仍hold、8次失败重试、0击杀，整体INCOMPLETE。root已看stage-3/deadline实图，不能签第三关通关。工具反复出圈追88米外敌车、瞄准误差常见5–15度；world.stats.hits混有敌人打玩家且护盾/共享Hull不会立即掉件，不能凭hits断言玩家伤害有效或生产损伤坏。
- 本批已合入：HangarApp预热PostUpdate窄守卫；EndlessSession休整检查点写失败显示H5原文warn、成功静默、保留ok/err。684帧序列检查/旧包负控及10关联报告、50存档检查/4旧包负控及4关联报告均实际重跑PASS，另独立只读审无生产回归。工具补更快公开鼠标闭环与S3守区策略（最终40检查/6负控、原65导航/7负控），不改HP/任务时钟/条件。
- 新包第一次session73352已FAIL/CLOSED，证据 `story-natural-s3-manifest-9e5d7ed6-2026-10-16T04-51-10-350Z/`：实际gate/parley/hold后工具把空Lua表JSON对象当数组，报targets.filter不可调用；运行错误0、3入口/环境音检查，保留原失败。已修工具Array.isArray边界并加真实空对象输入/对应负控，不改生产、不重构建。该次预热post-update采样warm计数1和3时，AimLines.count=1且enabled/glowEnabled=true，常规对局恢复count0；旧包同位置被清零的缺陷已观察修正，但采样不等于逐帧GPU/首次开火性能验收。sceneMs14892/combatMs17421，预热时长未改善。
- 当前唯一GPU为同包第二次S3自然复验session47979，证据 `story-natural-s3-manifest-9e5d7ed6-2026-10-16T04-55-04-396Z/`，480秒期限/公开输入，结果未回不签通关，不并发GPU；现有用户标签仍4422，待此轮结束切4435。
- 加载仍慢：本轮download35.495秒、scene预热14.855秒、combat预热17.113秒。全五关156条语音中S3完整文本闭包41条，其余115条/3,482,486字节属于静态gate裁剪候选；未改生产，未证明全部115条实际传输，不许诺解决35秒。见 `STORY_S3_VOICE_DEPENDENCY_AUDIT_2026_10_16.md`。画面悬空白0未定位，不能冒认H5原样，也不阻塞玩法。
- 6a第二关实际完整送达/结算与匹配音频通过事实见下一节，不回头复跑首关代替后续。仍OPEN：长冻结/音频连续性、全演出1:1、自然S3-S5/片尾、无尽打捞完整自然通关、旧OOM与移动真机性能。

## 当前接续：S2自然通关已完成；后续关卡修复统一合包中

- 本节覆盖下方历史，不重开G0、不提交上传。H5分支/HEAD本轮已实核仍为 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`。
- 6a包S2自然护送session35096已结束exit0/CLOSED：14检查/运行错误0，真实两个非默认选择、完整456.868米路线、CP3/3、8杀、2死亡、2次运输失败后按原规则重试，最终HP36.24%、B级并正常返厅/地形数组0。root已看result.png。证据 `story-natural-s2-manifest-6a53673c-2026-10-16T04-20-20-834Z/`；送达325.58秒，实际结算353.77秒。新helper只离线重放792样本，8检查确认原评级与实际血量；不能写成新导航跑过Web，三拨刷敌身份仍OPEN。
- 后续候选独立推进，不重复开篇前半：MissionView按原hold/capture环进度；BossRules强制起身复位预警；BossView逃生舱原摇摆/尾焰；StoryComms旧Web下载回调只记标记、后续Tick每帧准备一条语音。它们尚不属于6a包，不借6a结果签收。
- StoryComms实际Lua/ResourceGate 174检查PASS，真实6a旧实现负控复现回调重入，5关联报告已真实重跑；只读交叉审查未发现旧owner/Shutdown/重播回归。原2秒语音等待和真实解码失败、可闻连续性仍未关闭。
- 6a匹配v5的15检查/162样本PASS仍有效；下方写待回的条目是历史。主线程GPU目前空闲，待本批候选冻结后统一构建并串行第三关真实路线，不重跑首关代替后续。
- 最新已构建普通4431/QA4432仍为6a；用户旧4422标签尚未切本批新包。长冻结/音频连续性、全视觉1:1、自然S3-S5与片尾、无尽/打捞完整自然通关、移动真机性能均OPEN。

## 当前接续：6a53673c 通讯展开与剧情尺寸；后续关卡接续

- 本节覆盖下方历史，不重开G0、不提交上传。源已再次实核为10/15 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`；目标HEAD仍9541，保留工作区修改。
- 最新冻结 `.tmp/outgame-cached-1792123715225` / `manifest-6a53673c.json` / fingerprint `05959776b33768b532a12325d973661b2c0b3ced24f3a7a35dc439168ffa4655`。普通4431/session2887/PID49188，QA4432/session47940/PID15364。523实际Lua载荷、109报告608关联零漂移及HTTP实际身份PASS。相对45f仅 `story/Mission.lua` 和 `ui/IntroPage.lua` 内容变化，无资源增量。
- IntroPage.Comms恢复原84vh容器、240ms/对白延迟70ms再200ms展开、源缓动及完成撤裁剪；保留字幕/音频时钟。6415检查/385实际绘制案例、4个实际45f负控PASS，7关联报告实际重跑PASS。见 `G4_COMMS_UNFOLD_2026_10_16.md`；尚无本包GPU通讯画面验收。
- Mission.CarSize恢复同零件数换root重新量测、未就绪时按原蓝图格尺寸回退，避免大车交互距离错误。真实H5/Lua 10535检查、45f旧实现30帧差异负控，10关联报告6664检查实际重跑PASS。见 `G4_STORY_CAR_SIZE_2026_10_16.md`；不修改任务半径、物理或成功判定。
- 45f匹配v3/session3284已FAIL/CLOSED：8项实际声轨/增益/按句下载/prep到live通过，203样本、运行错误0；设置点击没有到达按钮，实际引擎光标仍在中心。旧报告未记录DOM锁，异步解锁归因是源码及坐标支持的推断。6a匹配v4/session34753亦FAIL/CLOSED：10检查/208样本、运行错误0，实际设置页及voice滑杆最大/恢复通过；失败仅恢复对局后用旧未捕获快照跳过Escape，随后捕获导致退出等待超时。checker补每次点击后fresh dump、恢复后真实Lua ready+DOM锁确认再Escape，26负控PASS。当前唯一GPU为6a匹配v5/session29561，结果待回，不借部分通过签整条通过。
- 第二关自然验收工具已补双非默认选项、运输行程/CP/血量/结算观察，最终75检查13负控PASS；尚未运行Web。交叉审查确认敌人计数跨三个窗口不能证明三拨刷敌身份，最终工具已把窗口计数降为诊断、三拨身份始终OPEN，并加入单残敌反例；不能强制原版未要求的十杀。首关35b自然S级通过证据继续有效，不从头重复。
- 6a匹配v5/session29561已结束exit0/CLOSED：15检查/162实际样本、运行/HTTP错误0；真实voice轨播放、按句最多四轨、原增益、prep到live、公开声音页最大/恢复、恢复真实接管后正常退出、返局外battle/radio移除且arrayBytes0均PASS。证据 `match-radio-web-manifest-6a53673c-v5-2026-10-16T04-16-30-993Z/`，root已看audio-settings及returned截图。调音时同一语音轨已结束，liveGainChanged=false，故不签正在发声时增益变化或可闻1:1。
- 当前唯一GPU为S2自然护送session35096/QA4432，证据 `story-natural-s2-manifest-6a53673c-2026-10-16T04-20-20-834Z/`，720秒自然指令上限、不改时钟/血量/任务判定；结果未回不得签S2通过。用户现有预览标签尚未切新包；等串行实测完成再更新。全视觉1:1、自然S2-S5/片尾、开场与回厅长冻结、RMS嘴型/全局声源池以及移动真机性能仍OPEN。下方45f/35b记录仅为各自包历史，不覆盖本节。

## 当前接续：45f10158 音频合包；首关自然通关已验收

- 本节覆盖下方历史，不重开G0、不提交上传。H5已重新核对为10/15 `b276064942ae09c0227ec28d4cfda1d5ff006455`。
- 最新 `.tmp/outgame-cached-1792122576512` / `manifest-45f10158.json` / fingerprint `621a6488256e11cbb83d421a9dffb699905c64ea004db64a55257cc45292ddca`。普通4429/session44323/PID52656，QA4430/session39869/PID62488。523实际Lua、107报告596关联零漂移、HTTP载荷PASS。相对35b仅6个生产Lua及350资源内容变化：驾驶尾音/独立声部、通讯回调下一帧准备、声音设置排除多余duck、按句无线电DSP。349条DSP轨全量实际payload/hash通过且无boot/blocking预载，不一次下载70MB。
- 中间包edd94237真实试车session93054已FAIL/CLOSED：大厅home.dialog=false被面板判断错误索引而Lua报错，未交用户；45f仅GameMusicState增加table类型守卫，新增false/nil输入矩阵后70/851/611/160实际重跑PASS。保留失败报告，不覆盖为通过。
- 35b完整首关session4158已结束exit0/CLOSED，证据 `story-natural-s1-manifest-35b14da3-2026-10-16T03-36-09-867Z/`：7检查/运行错误0、11阶段，真实3击杀/情报3/采集器3/0死亡、约6:16完成S级并正常返厅，地形数组0，厅→陨坑→厅实际环境音通过。root已看result.png。该包与edd94237任务/物理代码一致，但本次不验新声音候选，不代表自然五关或像素1:1/流畅通过。旧410秒OOM保留；本次WASM heap约1.72GB未增长，不等于内存已优化。
- 最小Web下载实验session38101已结束exit0/CLOSED：`sound-callback-download-2026-10-16T03-45-26-320Z/`。无游戏/场景/UI/声音播放，仅原ResourceGate下载原两音频；生命周期PASS，100ms响应门槛FAIL，max410ms；原MP3 2.63MB的XHR onload404.285ms、WAV 1.87MB为272.540ms。可复现无场景也卡的下载路径，尚不能断言确切native锁/解码所有者。
- 最小prepare对照session80111已结束exit0/CLOSED：`sound-callback-prepare-2026-10-16T03-46-42-803Z/`。生命周期PASS/响应FAIL，max409ms；两onload403.120/274.350ms，Lua纯标记callback均0ms（1ms时钟分辨率）、下一Update后排队1/0ms。后延cache仍不能消除下载完成处理的冻结，原生内部所有者未明。完整对比见 `G0_RETURN_DOWNLOAD_CALLBACK_PROBE_2026_10_16.md`。
- 45f真实PC试车session88067已结束exit0/CLOSED，8项PASS/错误0，证据 `driving-audio-web-pc-manifest-45f10158-driving-loops.json`。真实W移动、idle/load声部Hz/增益、释放停声、返回释放和再进入均通过，root已看load.png。不签125ms听感或手机性能。
- 45f公开匹配前两次检查session40206/99361均FAIL/CLOSED、运行错误0：前者未兼容Lua空表的JSON对象，后者未等按钮布局完成即点击。保留失败报告。检查器已增加严格有效布局等待及真实voice轨播放断言，20项CPU负控PASS。当前唯一GPU为第三轮session3284/QA4430，tag manifest-45f10158-v3，结果待回；之后才更新用户普通预览。不要并发GPU或借CPU报告签可闻/性能验收。
- 后续并行从本段继续：native_check_repair核S2-S5任务尺寸缓存及实际范围判断；g1_parts_current核工资条后的演出遗漏；continuity_targeted补第二关自然路线工具。它们属于45f之后的候选，不得拿45f结果签新代码。不重播已过开场前半替代后续进度。
- 驾驶源对照7717检查/7负控、无线电2225/116句/6负控、声音面板70/两类负控及相关851/611/160实际重跑PASS。仍OPEN：开场/返厅长冻结与音频连续性、全局声源池/压缩、完整五关及自然片尾、全部视觉1:1、移动真机持续性能。下一步继续后续功能验收，不能再把已过开场前半反复跑作全部进度。

## 历史：35b14da3 已冻结；回厅归因实测中，驾驶声音下一候选

- 本段覆盖下方历史，继续G0-G6，不重开G0，不提交上传。H5仍固定10/15 `b276064942ae09c0227ec28d4cfda1d5ff006455`。
- 最新冻结 `.tmp/outgame-cached-1792120761228` / `manifest-35b14da3.json` / fingerprint `c4a4000bf69965adce81a8512618b3e67af2a6aa186454483625b48e37b6aaf0`。普通4425/session64257/PID55084，QA4426/session63337/PID62884。522实际Lua、统一审计577关联零漂移及HTTP身份PASS；只证明内容一致。aace仍在4422，用户标签尚未切最终包。
- 相对aace新增6生产Lua和1字形资源内容变化：源NO/Bang字形、描边/五层阴影/动画、真实ASCII感叹号、标签原数字字体；六张招募卡重叠退出及disclaimer镜头继续。24份关联检查已在最终ComicText冻结后真实复跑PASS；漫画3160检查/5负控，招募4593检查/774绘制帧/24镜头案例PASS，不替代GPU像素或完整自然播放。
- 35b回厅实测session5758已结束exit1/CLOSED：`intro-return-web-1600x900-manifest-35b14da3-return-profile`，公开广告Escape→真实通讯选项3/v07→三比例登记签名→闸门→大厅32功能PASS/错误0；连续性FAIL，RAF450.330ms/2冻结、音频474.900ms/2候选。root已看4:3登记实图。CDP441ms任务约404ms为network-callback链，345ms任务约312ms同链，hotspot是get_now/now/未命名WASM；声音实际路径hangar-04及amb_hangar_a，另25资源组尚待区分。LuaMusic4ms/Ambience1ms，不将网络回调链直接定性为唯一声音/锁根因。窄报告`G4_RETURN_CALLBACK_PROFILE_2026_10_16.md`。
- No/Bang原生最后一次`comic-impact-native-2026-10-16T03-32-42-913Z`，60/60功能断言、Lua0/资源0、8PNG均生成；整体FAIL为截图逐像素readback/scan的8个>100ms尖峰，不能借夹具开销签生产性能。root已看前次同生产两PNG。第一次误跑完整main超时、第二次字体/Stop依赖错误均保留；不再反复修夹具求PASS。
- 下一候选：DrivingAudio已冻结ab998edb（7717真实源JS→Lua检查/12场景234动作/7负控，相关context851PASS）；root修StoryCommsCues回调只置标记，下一Update查cache/排队/建source，冻结87ea2449（540检查/7负控，非原生锁验收）。g1_parts_current独占MatchVoice/MatchRadioDSP原Radio音频图烘焙与按需下载/后台准备，不一次下载全部轨；continuity只读审其生命周期，native只做小型回调Web实验。新候选不属于35b，不借旧包验收。
- 当前唯一GPU：session4158，35b/QA4426，真实首关完整路线（`story-natural-s1-manifest-35b14da3-2026-10-16T03-36-09-867Z`），非entry/log-only。工具最长观察480秒，游戏时钟/血量/阶段未改；目标是继续日志以后/east/结算，结果未回不得签PASS。它不验下一批声音生产候选。完成后才串行最小Web回调与新音频包公开试车。
- 现有真实结论继续有效：2928完整开篇72功能PASS但650.515ms长帧/1015.035ms音频回调间隙FAIL；aace首关真实三杀/日志拾取8PASS与第五关进出6PASS，不等于完整五关；片尾11功能PASS但247.095ms预热超过100ms整体FAIL；首关旧410秒OOM、完整演出1:1、全局声音DSP/池、持续性能和移动真机仍OPEN。

## 历史：2928 完整开篇功能通过、连续性失败；后半演出与混音合包

- 新QA4424/session85771/PID360仍用aace生产，仅只读probe更新到`ecbfd68345f978d7999267ca1694d2f703b6869c7a8562426e57697bed5a6434`，增加实际声音请求路径/下载回调及后台准备观察墙钟（不是native内部EndLoad时间）。71项工具/17计时+2负控/47转场+5接线实际PASS。HTTP4422/4424同包PASS。旧4423探针不适合新增字段；已确认身份后关闭4391–4421中本会话遗留服务，当前用户4422不受影响。
- 首关自然日志拾取已结束session41777/exit0：aace/QA4424，`story-natural-s1-manifest-aaceac89-2026-10-16T03-09-07-314Z`，8项PASS/运行错误0；真实越过poster、安装2采集器、击杀3侦察车（非超时退兵）、生成目标、实拾日志intel2→3、推进east、返厅arrayBytes0。root已看log-picked.png。只改工具减速保留转向，未改游戏物理/判定/360秒时限；此前410秒OOM证据保留，本轮约275秒路线不等于长期OOM已关闭或全关通关。
- 后半演出/混音合包已构建 aaceac89：`.tmp/outgame-cached-1792119610798`，fingerprint `26b077447d0bc5da0d057e7bd43a9eaf72fef340dd8ddd8647404e6031c018fd`，普通4422/session60377/PID8548，QA4423/session64524/PID62768。521实际Lua/HTTP身份PASS；102份报告560关联零漂移PASS。相对2928仅7个生产Lua内容变化、资源内容0变化；标题退出与disclaimer相机尚不在此包。
- aace第五关真实入口与返厅已结束session64577/exit0：`story-natural-s5-manifest-aaceac89-2026-10-16T03-02-04-558Z`，6项PASS/错误0，实际接管、地图/HUD显示、厅→陨坑→厅环境音和返厅arrayBytes0。root已看entered图；不是自然Boss击杀/片尾全程/第五关通关。
- Boss抓帧原生第三轮已通过：`boss-scene-capture-native-2026-10-16T03-01-19-906Z`，20/20、零错误、exit0、输入无漂移；root实际查看红3D/绿UI对照。两张PNG已归档本轮目录。前两轮失败保留；不代表完整陨坑后处理取景或自然S5。
- 片尾严格原生第二轮结束：`epilogue-stamp-native-2026-10-16T03-04-37-230Z`，11/11功能断言PASS，Lua/资源错误0；整体FAIL仅启动frame25 247.095ms超过100ms门槛，不降低门槛。root已看stamp.png；不能签性能或自然完整片尾通过。
- 下一候选并行：g1_parts_current独占IntroPromo/新RecruitTitles与IntroShots/OpeningHost，补源招募卡重叠退场和disclaimer镜头延续，未纳入aace；native_check_repair仅补只读probe声音路径/后台准备观察墙钟，不改生产音频；continuity_targeted只读首关路线/OOM。不重播前半代替后续玩法。
- 第一批已冻结 `manifest-29283a2f.json` / `.tmp/outgame-cached-1792118750001` / fingerprint `04e72d665495dbb5e221d9c18c1ddda35dfb72bf7b048247884bacfa02cfb9ce`，普通4420/session74317/PID60076，QA4421/session41315/PID60176。519实际Lua与HTTP身份PASS；99报告536关联零漂移。统一审计总体FAIL仅因下一批Epilogue候选已在工作区改变，与冻结包不同，不能称当前工作区=此包；最初另有audit工具哈希漂移，实际重跑50项后已消除。
- 2928实际第三关进出已结束session40175/exit0：`story-natural-s3-manifest-29283a2f-2026-10-16T02-47-11-798Z`，6项PASS、错误0。root已看entered图，原两数组各33554792字节，返厅arrayBytes0；环境音实际playing厅→陨坑→厅。对80e98精确331shader路径/defines全部一致，无增减；loader.Update最大764→391ms，App765→392ms。总下载/装配时长基本没变，不能签进图快/不卡。`story-loader-latest-comparison.json`保留完整对照，1条截断console状态计数剔除，完整入口/返厅仍严格断言；TimeStep的100ms上限不能当真实帧冻结。
- 2928完整自然开篇 session30584 已结束 exit1/CLOSED：`intro-natural-web-1600x900-manifest-29283a2f-full`，72功能检查PASS、运行错误0；真实W行驶55.973m、LMB伤害/反馈、工资条、后半漫画、三比例签约及回厅通过。root已看射击反馈、盖章工资条和4:3登记图。整体连续性FAIL：RAF最大650.515ms、gate长任务623ms；音频2204次回调、2177次非零、最大间隙1015.035ms/12个候选。不能签1:1或不卡，不再无目的重播整段开篇。
- Boss抓帧首轮原生20/20像素断言通过，但默认DDS/字体及SDK启动依赖报错，整体验证FAIL，不能签通过。continuity修独立fixture依赖；root当前串行运行严格片尾11断言验证session85244，结果待回。
- 第二批正在生产（不属于2928）：continuity_targeted独占BossView/StoryBoss/BossSceneCapture补源8秒避障回收/跟车/战报抓帧；native_check_repair独占Epilogue/EpilogueMotion补旧页淡出退役及砸页震动；g1_parts_current独占MatchVoice/MvpMusic补确证的播报duck与MVP音量/总线。root仅串行GPU，后续合第二包并审计。
- 固定源仍为 10/15 `b276064942ae09c0227ec28d4cfda1d5ff006455`，不重开 G0，不提交、不上传。下方历史不能覆盖本段。
- 当前已构建 d5da：`.tmp/outgame-cached-1792117688715` / `manifest-d5da34be.json`，普通4414、QA4415，519实际Lua，统一审计95报告/513关联/漂移0。用户标签仍在旧4409，待下一批真实验收后更新。
- 80e98公开漫画前三格→通讯→签约→4:3/16:10/20:9复验已结束：session13131 exit0/CLOSED，30检查、运行错误0，root已看漫画fine和4:3登记终端截图；中间Escape跳广告，不是完整自然开场或连续性通过。
- MissionTimers真实原生20/20、错误0/exit0已过，证据`story-mission-timers-native-2026-10-16T02-25-33-471Z`。不代替自然五关。
- d5da公开试车课程复验 FAIL：`practice-course-web-manifest-d5da34be-2026-10-16T02-33-27-644Z`，按钮/提示/捕获恢复均实际通过，但大蝎子山坡出生被弹高、抓墙入口W移动不足。原H5相同大车课程CPU也复现重叠/弹高，正在核AABB；不降低阈值、不签课程或返厅通过。
- 下一批生产分工：native_check_repair 已冻结 SceneLoader 后台纹理数组准备候选6439e69c，正在补原whoosh/error及公开UI触发；continuity_targeted补剧情触屏交互；g1_parts_current只读课程重叠与漫画漏音核对；root负责合包、串行Web和可见结果。所有影响报告必须真实重跑。
- 数组独立Web：同步排队701/743ms，后台1/0ms；后台首349ms跨下载边界、其中348ms在排队前，实际ready帧58/34ms。只能证明窄接口可行，未签完整场景不卡。报告`G0_ARRAY_BACKGROUND_WEB_EXPERIMENT_2026_10_16.md`；新包必须再跑S3进出、实际数组/331shader集/画面。
- 全视觉1:1、自然五关/成功搜撤、冷启动和音频连续性、首关长路线OOM与移动真机仍OPEN。保留完整G1–G6，不靠反复开屏替代后续玩法。

## 历史：80e98合包与真实音频/剧情短验

- **最新包80e98已构建**：`.tmp/outgame-cached-1792117100400` / `manifest-80e98fd5.json` / fingerprint `d2aa939d461323a7541c0a4a27622eb4619a3b7049ef0c17c9588577b110af58`。普通4412/session98563/PID45440，QA4413/session86077/PID65776；519/519实际Lua、HTTP身份、94报告511关联零漂移全部PASS。相对49c15仅9Lua及5音频资源内容变化；初次audit因新环境音报告无统一输入映射FAIL已保留问题事实，checker修映射后实际重跑PASS。
- **80e98第三关短验已结束exit0**：session68806，`story-natural-s3-manifest-80e98fd5-2026-10-16T02-19-43-292Z`，6项PASS、错误0。真实大厅amb_hangar→任务接管amb_crater→返回amb_hangar，均实际SoundSource.playing、单声部、正常返回后arrayBytes0。root已看entered图；这不是听感、自然全关或连续性验收。实测loader.Update最大764ms、App765ms，Music4ms、Ambience1ms；数组冻结仍在，不能签性能修好。
- **当前唯一GPU测试**：session13131，QA4413，公开漫画自然前三画格→跳广告→通讯→登记签名→4:3/16:10/20:9响应式与回厅，tag `manifest-80e98fd5-comic-contract`；结果未回不得签通过。之后串行跑新MissionTimers原生20断言和数组异步独立实验。未切用户普通页，待本批验收。
- 49c15真实两条路线已结束：G5搜箱/放弃回厅9项PASS、错误0，证据`salvage-natural-manifest-49c15ba7-2026-10-16T02-05-39-908Z`；第三关进出3项PASS、错误0，证据`story-natural-s3-manifest-49c15ba7-2026-10-16T02-09-23-829Z`。root已看搜箱和第三关entered实图。不是自然撤离/全关通过。
- 第三关实际app实例计时已生效：Update1812次/max715ms，Music1812/max7ms，Gate1812/max1ms；download35.643s、activate32.967s，性能仍OPEN。715ms对应资源阶段nra纹理数组准备，651ms对应albedo，二者都在ReadScene之前；下包用更细loader/Install/Release/Flow计时确认。
- 最终probeSHA `d82996c9a89be40cc5a8d98098c61ea6757a6ba929021434edfe9609e83d9f0a`，含只读环境音状态和实际Update/Prepare计时。4411仍加载旧8852探针，不可借旧服务验收新字段。
- 本批候选：原4场景环境音已冻结（按需后台准备/原增益/失焦停播）；Mission墙钟定时已冻结，死玩家PARK分支正在窄修；G5金红货/残骸反馈已冻结；IntroComic画格说明换行2072项PASS。待统一构建后同包验收，不借旧包签新增生产。
- root串行GPU；g1_parts_current只重跑受影响报告，native_check_repair只读定位数组准备长帧，continuity_targeted独占Mission窄修。不提交、不上传，不重开G0。全部演出1:1、冷启动/音频连续性、自然全关/成功撤离及真机持续性能仍OPEN。

## 上一接续记录

- 仍对固定10/15 `b276064942ae09c0227ec28d4cfda1d5ff006455`，不重开G0、不提交上传。上一包49c15继续可用；工作区候选尚未构建，不能借旧包验收。
- 并行生产：continuity_targeted负责Mission/MissionRules/MissionTimers，恢复原墙钟选项/提问/失败重试及失败演出顺序；native_check_repair负责原4场景环境音及HangarApp接线；g1_parts_current负责打捞金红货震动/延迟广播/残骸实得与满仓提示。root负责合包、串行GPU及漫画fine原换行/画格局部层级。
- root已运行旧49c15真实G5搜箱/放弃回厅（session59494，证据`salvage-natural-manifest-49c15ba7-2026-10-16T02-05-39-908Z`），结果未回不签PASS。新QA4411/session33243使用同49c15、实际app/music/Gate方法计时已修，probeSHA8852a61dc633d66ddda044894aeeb38884d0785014fdc0c005c6d51f44e0e82f；待GPU空闲跑第三关短测，计数必须实际非零才归因。
- root候选IntroComic已将年假说明放回原leave画格，按源6%/3%边距、padding/line-height缓存换行，继承画格滑入/旋转/透明度并释放布局。2072项现有漫画实际Lua绘制回归通过；未GPU视觉验收，不签整段开场1:1。
- 全G0-G6目标保持，加载/音频连续性FAIL、自然全关/搜撤及真机OPEN。下文49c15交付事实继续有效，旧历史不能替代本候选验收。

## 当前唯一接续点：49c15 已交付预览，功能回归通过但长加载/音频连续性仍OPEN

- **本段覆盖下方历史状态**。H5 固定 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`，目标 main/9541，保留全部既有工作，不提交、不上传。
- **最新冻结包** `.tmp/outgame-cached-1792115578618` / `manifest-49c15ba7.json` / fingerprint `f1f1f38af56e349cbaba5d5ed246019221ca9cd785eaa81f5b995d258c378c6a`，普通4409/session27359/PID54584，QA4410/session96696/PID63652。517实际Lua、HTTP身份及统一审计90份报告/489关联/漂移0全部PASS。相对5487增加招募6处slam、私有loader5ms、Boss exposed墙钟延迟3文件；不借5487签新增音频/第五关自然表现。
- **session81359已结束exit0/CLOSED**：49c15 boot-only PASS/错误0，`evidence/intro-natural-web-1600x900-manifest-49c15ba7-budget5-boot`。开场boot100.375→92.556s、prepare16.846→11.243s/898→559恢复，仍慢且不是多轮受控A/B。预热401批全部完成，不签播放连续性。测试GPU空闲；用户IAB tab2已从4396导航到普通4409，root已通过实际截图确认新版大厅与教程对话显示，保留用户标签。
- **已完成前包5487** `.tmp/outgame-cached-1792114575097`，普通4407/QA4408，516实际Lua和统一审计 PASS/fixtureDrift0/471关联，旧报告全部实际重跑。
- **真实整段开场 session97575 已结束exit1/CLOSED**：`evidence/intro-natural-web-1600x900-manifest-54870f56-final`，72功能检查PASS、运行/HTTP错误0。实际W行驶55.354m、LMB命中/伤害数字/音效、工资条横移与冲击、两个展示停车、通讯共用时钟、三比例登记签约、门闸回厅通过。root看过伤害/漫画/工资条/4:3及20:9签约图。**连续性FAIL**：RAF P95=66.730ms/P99=100.085ms/max533.770ms（gate）；音频回调max567.205ms/2候选，sortie272.940ms前后非零，gate前后均零。混音max1.155ms。不得签不卡/音频听感/全视觉1:1。abort-only hook无OOM；不是首关长路线OOM已修。
- 本包相对5b8c包含9生产Lua变更，资源内容0变更；工资条镜头/冲击、靶车停车并跳过武器和FX、通讯时钟、Boss普通/紧急喊话、明确disabled预热过滤及阶段计时已收入。真实性能收益仍待测。
- **真实第三关entry-only session76087已结束exit0**：`evidence/story-natural-s3-manifest-54870f56-2026-10-16T01-45-47-991Z/`，3检查PASS/错误0，正常进场/退出。新预热532 drawables/2493 disabled/307 outside/67 batches，scene14.959s/恢复1.087s/Combat构造.030s/Combat17.165s；download34.628s/activate33.311s，仍慢。root已看entered.png；未验证整关通关。新旧遮罩内shader331/331完全同集（missing0/added0），阶段156/18/157→158/14/159，完整世界帧仍需保留。
- **49c15增量已合入**：OpeningHost私有prepare预算3→5正式89/2负控；招募六处原slam .75漏音正式262/旧包及音量负控；Boss exposed 2.6s墙钟延迟及离场/死亡取消正式163/4负控、相关回归9866通过。Boss真实Node/ScriptObject原生14/14/错误0/exit0，证据`story-boss-exposed-native-2026-10-16T01-52-10-325Z/`。不等于第五关自然演出/Web focus/听感通过。
- **仍OPEN**：冷启动约90秒、播放/回厅长帧和音频连续性、首关长路线OOM根因、自然全关/搜撤、全演出视觉1:1、手机持续性能。Boss延迟已合49c15并有原生小测，自然第五关与Web失焦仍待验收。
- **固定下一步与完整证据**见 `G4_OPENING_END_TO_END_2026_10_16.md`。下一次应直接测有效app实例的长帧归因与后续功能，不重开G0或再次重播已过的前半。

## 历史：后半演出候选与首关 OOM

- **本段覆盖下方历史状态**。源已重新实查：`2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`；目标 main/9541 保留所有未提交工作，不提交、不上传。
- **首关 session4559 已结束 FAIL/exit1，不再运行**：5b8c/QA4406，`evidence/story-natural-s1-manifest-5b8cf21c-2026-10-16T01-18-07-151Z/`。约409s仍停poster高地路点，intel1/collector0/kills0，随后`Aborted(OOM)`；测试Chrome和遗留Node已限定PID关闭。不能签三杀/日志掉落拾取。见 `G4_STORY_S1_OOM_2026_10_16.md` 和 `G3_STORY1_OOM_READONLY_2026_10_16.md`。最后163.6s资源/声音缓存稳定，Lua波动，OOM根因仍OPEN，不能凭静态猜测改物理/音频。
- **下一包生产候选**：工资条近景/2m/s跟车/FOV44（IntroShots、OpeningHost）；Boss普通/紧急喊话与once契约（StoryBoss）；通讯镜头跨contract/stamp/gate共用时钟、闸门推进回到源时点（IntroSession）；工资条激光冲击/root shake/相机trauma（IntroImpact、IntroPage、Session接线，g1最终验证中）；驾驶/飞弹展示靶车按源停车、停武器且保留无瞄准转子步进，瞄准点+1m（IntroBattle、OpeningHost）。源码对照与历史负控见本批窄报告，不能借5b8c签自然画面。
- **预热候选**：SceneWarmup跳过明确disabled物件，保留全部mask恢复及完整世界阴影帧；LoadingFlow拆解计时。152项/2负控、2308开场回归及59/7生命周期已过，真实禁用量/加载收益待新包短测，不声称冻结已消失。
- **root串行GPU下一步**：候选全冻结后统一构建与实际payload/HTTP身份核对；同包只跑一次改后完整开场（驾驶攻击反馈→后半镜头→三比例签约→闸门），再第三关entry短测读取预热阶段；更新用户IAB到新普通预览。旧5554 boot97s/音频连续性FAIL、全演出1:1/自然五关/手机持续性能均保持OPEN。

## 历史：5b8c 两条真实路线已过，后半演出修复与首关日志实驾

- **本段覆盖下方历史接续，不重开 G0**。5b8c普通4405/QA4406、515Lua身份与payload已核。源仍为10/15 b276；不提交不上传。
- **真实破坏 session97111 已结束PASS**：`evidence/destruction-web-2026-10-16T01-12-31-166Z/`，21检查、运行/HTTP错误0，公开鼠标射击逐块破坏并击毁赤焰GT，300分/实际kill_confirm/score_tick；62次Flush最大17ms。含抓图/探针开销的开火1400帧P95=33.410ms/P99=50.055ms/max=50.225ms，>100ms为0。本机单靶回归，不是因果A/B、全部预设破坏、混战或手机性能验收。
- **第三关自然选项 session56130 已结束PASS**：`evidence/story-presentation-manifest-5b8cf21c-2026-10-16T01-14-34-240Z/`，15检查、运行/HTTP错误0。公开出战→03围剿→真实W触发gate→原对白→按2选择→500ms确认/退场→正常T回厅；root看过实际选项图。不是第三关自然全胜或全剧情关闭。进场download34.938s/activate36.687s仍慢，预热专线只读分析中。
- **第一关日志自然重验正在 session4559**：同5b8c/QA4406，修复路点计时工具后公开键鼠操作，420s驾驶期限，`evidence/story-natural-s1-manifest-5b8cf21c-2026-10-16T01-18-07-151Z/`。只读F8，无改进度/传送/伤害注入，结果未回不签三杀/掉落/拾取。
- **下一包生产在做，不能借5b8c签收**：g1_parts_current独占IntroShots/OpeningHost补原工资条残骸近景/横移/FOV44，不动字幕或版式；continuity_targeted独占StoryBoss补BARKS频道分类及源urgent/once语义（已实际复现firstRise会误截前序字幕/音频）。root串行GPU，native_check_repair只读拆解已记录的第三关预热。全部演出1:1、冷启动/音频连续性、五关自然胜利及移动真机仍OPEN。

## 历史：5b8c 合包与原生检查

- **本段覆盖下方历史状态，不重开 G0**。冻结包 `.tmp/outgame-cached-1792113063203` / `manifest-5b8cf21c.json` / fingerprint `740b71aa69337fc6f797bef64581a30f97161d39d532435af53afaf4ce4ace23`，普通4405/session53756、QA4406/session77885。515实际Lua payload及HTTP身份通过；相对f56仅Blueprint.lua。证据 `evidence/5b8c-payload.json`、`evidence/http-snapshot-manifest-5b8cf21c-audit.json`。
- **当前真实射击破坏 session97111**：公开工坊选车→试车→正常N靶场→鼠标开火，观测实际伤害/碎块/命中光效/击杀积分/音效及帧时间。结果未回不得签通过；生产冻结，不借离线扫描量证明网页不卡。之后执行第三关公开驾驶/对白选项/正常返回。
- **真实原生剔除检查已PASS**：`evidence/objective-culling-native-2026-10-16T01-10-45-366Z/`，16/16断言、错误0、退出0，输入哈希未变。Camera.frustum/BoundingBox/CustomGeometry实际执行；不等于Web像素/整局性能通过。前两次空跑和退出码采集失败均保留，见 `G3_OBJECTIVE_CULLING_NATIVE_2026_10_16.md`。
- **Blueprint候选已入本包**：SHA `25abcd3130c3518b733a5745da374ff402c38e245d39debfb841b7f28b2e76cf`，f56实际完整损坏回归1924项等价；vanguard整表扫描20034→0、实际119条入边，scorpion10871→0、23条入边。详见 `G3_NEIGHBOR_REMOVAL_CACHE_2026_10_16.md`。这是操作量证据，网页收益待上项。
- **第一关自然工具已修，不改玩法**：每个路点独立重置进度与倒车，新增实际路由、目标、按键和支撑诊断；离线59项/5负控通过。旧ea91自然INCOMPLETE保留，尚未借工具修复宣称三侦察车/日志通过。5554冷启动97s、音频连续性FAIL和全演出/全关卡/移动真机仍OPEN。不提交、不上传。

## 历史：f56 原生剔除与破坏缓存候选

- **此段覆盖下方历史接续，不重开 G0**。本轮重新实查 H5 HEAD 为 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`；目标 HEAD `9541dc59ef2f281cafa5126762a57550189e04dc`，保留既有未提交工作。不提交、不上传。
- **最新冻结 f56e5c62**：`.tmp/outgame-cached-1792112558349` / `manifest-f56e5c62.json` / fingerprint `1a9137fbedda531557e518b1a59a25fab90e4baece5877eb813271333b3128f8`。普通4403/session50388/PID50556、QA4404/session85424/PID51364；515实际Lua及HTTP身份已核，证据 `evidence/f56e-payload-http.json`。相对ea91仅OpeningHost、StoryBoss、Endless.Edit、ObjectiveView四生产脚本。尚未借旧包结果签本包游戏验收。
- **ea91 教程毕业已关闭**：公开drive-first路线94检查、运行错误0、PASS/CLOSED；实际W/T返回、加两块209→211、保存实际车位及正常毕业。不等于自然第一关胜利、全演出1:1、流畅或移动端验收。
- **第一关自然日志路线已结束 INCOMPLETE**：session26896退出1，2检查、运行错误0；实际经过box→exit→poster→deck→bow，intel2/collectors1/deaths0/kills0，期限停在舰船侧面。正常回厅并释放地形数组；三侦察车击杀/日志掉落拾取未验收。证据 `evidence/story-natural-s1-manifest-ea91d004-2026-10-16T00-56-24-255Z/`。源坐标/桥面核查一致，自动路点切换未重置进度是工具缺陷，先修工具再复跑，不能改玩法强行通过。
- **原生剔除检查前次为无效验证**：`evidence/objective-culling-native-2026-10-16T01-05-42-701Z/` 虽标PASS，但断言总数0，回调未执行；不得签真实Camera/CustomGeometry通过。专线修复工具与严格计数后root串行重验。
- **下一包工作区候选，不属于f56**：Blueprint删除连接缓存改反向索引，待等价与损坏重建对照。continuity_targeted负责生产/离线，g1_parts_current负责自然剧情导航工具，native_check_repair负责原生验证入口；root负责合包和串行GPU。历史damage-before盒形夹具与当前未伤害车已有差异，旧失败保留，新增以f56为对照。
- **保留的阻塞**：5554冷启动97s、播放/回厅长帧和音频连续性FAIL未关闭；全演出视觉还原、自然后续关卡/搜撤、G1–G6与真机性能均不得笼统标完。下一步原生有效验收→冻结破坏候选→真实后半功能路线；不重播整套开屏来替代后续功能。

## 历史：ea91 教程毕业复验

- **本段覆盖下方历史接续，不重开 G0**。固定 H5 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`；不提交、不上传。
- **当前冻结包 ea91d004**：`.tmp/outgame-cached-1792111525141` / `manifest-ea91d004.json` / fingerprint `76e1187b27e5b47af79d01ea2e92270a97cc267cc9163ce0d3107b0e8f5b4c9d`。普通4401/session54367、QA4402/session1112；515实际Lua payload及HTTP身份已核，证据 `evidence/ea91-payload-http.json`。相对5554仅Mission/MissionRules、Endless.Audio、PartRig四脚本，包含原剧情出兵顺序/去重复成功音、无尽音频路由和履带内轮方向；不借5554签新代码。
- **完整教程v2 session38099 已结束 PASS/CLOSED**：94检查、运行错误0，真实首关W/T返回→debrief→背包→加2块（209→211）→保存实际车位→回大厅→原graduate语音→点击下一步正常毕业，record.done=true/skipped=false/replay=false。证据 `evidence/tutorial-drive-route-ea91d004-complete-public-v2/`，root实际查看结束大厅截图。功能只签PC先驾驶路线，不签自然首关胜利/像素1:1/音频质量/性能或另一条教程路线。v1 session36791的87检查后FAIL/CLOSED保留：实际已done但工具错误要求最终id变化；仅修工具，不改生产。
- **第一关自然战斗日志路线正在 session26896**：同包QA4402，`evidence/story-natural-s1-manifest-ea91d004-2026-10-16T00-56-24-255Z/`，实际公开剧情入口/鼠标键盘导航/三侦察车击杀/日志掉落拾取；F8只读，未注入HP/传送/完成，结果未回不签通过。
- **下一包4脚本已冻结，均不属于ea91验收**：ObjectiveView视锥外跳过几何重建（离线45/4负控/相关47回归）；OpeningHost隐藏hallActor跳过UpdateIdle（实际32、相关1199/3负控）；StoryBoss击倒清storyUntil立即接管对白（33源对照、2707回归）；Endless.Edit文字提交Enter消费/焦点守卫/数字键盘Enter（76/3负控、92回归）。ObjectiveView原生真实Camera.frustum/CustomGeometry短测已准备，等自然第一关释放GPU后执行，尚未打包。hover当前源120/120碰撞/尺寸对照PASS，历史夹具来自90862445而非当前b276，无生产修复。
- **当前并行工作**：G4后半关卡/Boss/片尾实际缺口；G5局内改装与结算库存闭环；已有长帧证据的最小性能修复。root串行GPU，教程完成后转搜撤/后续任务，不重复整套开屏。5554的boot97s与音频/长帧连续性FAIL继续保留，不签流畅或全面1:1。

## 历史：5554 完整开场验收

- **本段覆盖下方所有旧的“当前/下一步”状态，不重开 G0**。H5 固定 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`。不提交、不上传。
- **正在验收的冻结包 5554a836**：`.tmp/outgame-cached-1792110839635` / `manifest-5554a836.json` / fingerprint `ccf04f0aaa78129f42fc7476ad3de23bf9efc556e51aa2cc81ee71f59a1d3632`；普通4399/session76185，QA4400/session7239。515 Lua 实际 payload 独立核对一致。相对d011为12脚本、3资源内容变化，metadata另计。红鸽图、标题退场/爆碎、开场演员协作checkpoint、Space射线桥接复用、打捞遭遇/空投反馈已收入。
- **自然开场 session27529 已结束/CLOSED**：证据前缀 `evidence/intro-natural-web-1600x900-manifest-5554a836-checkpoints-visual`，66功能检查PASS、运行/HTTP错误0；真实W行驶41.635m、LMB伤害、命中数字/确认声音、后段漫画/工资条/装配/导弹、三比例登记/签名/闸门/教程交接通过。root看过真实伤害和漫画截图。**连续性FAIL**：boot97.001s，RAF P95 66.730/P99 116.735/max617.175ms（gate），音频callback最大667.710ms/15候选。演员分帧prepare最大177ms但总16.746s/897切片，不声称加载提速。退役craterDetached=true/pending=false/jobs0。不是自然实弹打完全部血量、全演出1:1、音频听感或手机性能通过；下一包优先教程后半，不重复整个开屏。
- **下一包工作区增量，不能借5554验收**：Mission.lua/MissionRules.lua已修结算重复成功音和原对白→横幅→出兵顺序；Endless/Audio.lua已修原feedback总线、增益截断和流程duck；g1仅修PartRig履带内轮旋转方向，完成后统一冻结。开屏生产停止扩展。
- **后续真实验收顺序**：教程公开drive-first→首关→正常返回→debrief→build/bag/真实place/save/leave→毕业；再接打捞自然搜撤和五关。已准备 `VOX_TUTORIAL_COMPLETE=1`，无跳步替代。原全篇、冷启动约90s、播放/回厅长帧、音频连续性、自然搜撤、全部G1-G6与真机性能未关闭项继续保留。

- **08:27 新批接续，不重开 G0**：旧d011两次boot-only网络诊断已PASS/CLOSED、错误0，boot90.367/89.616s；实测并发before8/after8，第二次不是参数优化。42.269/41.597s匹配资源请求窗口中22.153/21.463s没有匹配项目请求在途；不等于进程空闲或纯网络结论。见 `INTRO_D011_REQUEST_TIMING_2026_10_16.md`。root新网络工具不属于旧包验收。当前正在并行：g4原标题离场/红鸽碎片/工资条光效；g5已冻结遭遇/空投/三音效并接开场演员checkpoint与中途取消所有权；g1拒绝无稳定收益arm缓存，实测悬挂/射线分配候选。未合包，不借d011签新生产。下一步统一冻结→构建→自然开场及打捞真实路线；不提交上传。

- **当前最终小包d01102e0**：`.tmp/outgame-cached-1792108710605` / `manifest-d01102e0.json` / fp `87ecf48a00cf2c524965e5912e6add987151322bb61df29e63f1d132c0b42ce9`，普通4396/session17978、QA4397/session99435。相对d47只有IntroPage/IntroPromo/StoryPage三脚本内容变化，资源内容0变化；HTTP/delta实际PASS。**公开drive-first教程session15912已PASS/CLOSED，64检查/运行错误0**：真实首关接管/W短驶/T正常返回、两句复盘、leave、Esc退出剧情页、E进改装及bag配音通过；root已看bag实图。不是完整教程毕业、自然通关或性能验收。证据 `evidence/tutorial-drive-route-d01102e0-drive-route-20261016-v1/`。
- **d011自然全序列session65995已结束/CLOSED**：`evidence/intro-natural-web-1600x900-manifest-d01102e0-final-route`，QA4397；66功能检查PASS、运行/HTTP错误0，整体因连续性FAIL。真实W驾驶57.318m、LMB开火/真实敌伤/共享命中与伤害数字、后段漫画/工资条/装配/导弹/通讯/三比例登记/签名盖章/闸门/淡出/教程交接通过；不是自然实弹打完敌人全部血量、教程毕业或全剧情通关。boot→warm完成90.053s；播放RAF P95 66.730ms/P99 100.085ms/max550.425ms（hall-return）；音频callback最大590.100ms、10个延迟候选，mixer最大1.235ms。仍不签不卡或移动性能。公开教程64检查PASS已如上记录，两个真实路线同包完成，不再重跑旧包。
- **已交付预览4396**：root在当前用户标签tab2从旧4369实际导航到普通4396，加载后实际截图确认新版大厅与教程对话可见；自然测试浏览器已关闭。root实际查看最终包的伤害反馈、4:3登记与盖章工资条截图；独立视觉复核见`G1_D011_FINAL_SCREENSHOT_REVIEW_2026_10_16.md`。界面能放下不等于20:9小字号可读或全演出1:1。新版生命周期126检查/8负控、action-buttons1353及freshness0和独立514/514Lua/82报告445关联/drift0保持为各自范围证据。
- **固定下一接续，不重开G0**：优先拆解42.456s原始资源完成链与29.135s暖机；brief181个唯一shader不是重复编译，不能删除覆盖冒充优化。仅OpeningHost构造预算3→5ms是未实施A/B候选，不是已改善。播放驾驶负载/回厅长task、音频delivery间隙、红鸽/标题离场/协调动效/嘴型/DSP和20:9小字仍OPEN；详见`INTRO_D47_BOOT_READONLY_AUDIT_2026_10_16.md`与开场批次文档。生产冻结；不提交、不上传。

- **d47已结束，禁止当成教程全部通过**：自然session62654 CLOSED，66功能检查PASS/运行与HTTP错误0；连续性FAIL，boot-ready墙钟92.594s、播放RAF最大583.785ms、音频回调最大609.785ms/13候选。root看过真实射击反馈、工资条前景和4:3登记图。教程session1923同包51检查后再次`StoryPage:179 storyHolo=nil`，FAIL/CLOSED；首关驾驶与返回/debrief已到达，不签整条路线。根因进一步确认：`GarageHud.SetTab`先Leave隐藏旧页，随后`GarageLayout.Apply -> Visibility`按新tab把仍mounted的旧页重新显示；原48检查把Layout.Apply替为空函数，遗漏实际链。当前生产增加PageActive所有权门禁，保护Page.Render、CustomRenderChildren与晚到的拖拽/滚轮回调。g1补真实布局负控；同时收入已源对照的警告漏字与FORM字体修复，最终候选构建session12661进行中。不要复用d47自然结果签新包。

- **最新接续 d47ba6e2（覆盖下方旧包状态）**：H5 当前实查仍为 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`。冻结 `.tmp/outgame-cached-1792107779538` / `manifest-d47ba6e2.json` / fp `b483380e943d26d69a4a0ebfc5105cf7a92ea2f1a3d7736157a8376066e57318`；普通4394/session65269，QA4395/session83847。独立 emitted Lua514/514、HTTP、82报告444关联 drift0；action-buttons1353实际PASS，freshness FRESH。相对749只改6Lua与WeaponSounds，修StoryPage退出旧页渲染、空袭采样/倒数镜头/飞弹依赖、工资条前景层序与武器循环音包络。
- **d47真实自然验收正在执行**：session62654，`evidence/intro-natural-web-1600x900-manifest-d47ba6e2-functional-audio`，完整真实开火/后段/4:3、16:10、20:9签约/教程交接。结束前不能签功能或连续性PASS。下一步同包公开drive-first教程→首关→返回→debrief→编辑/背包；用户4369仍旧manifest14f59378，验证后切4394。生产冻结，不重开G0、不提交上传；上一包92s预热和长帧失败继续保留。

- **接续覆盖（当前真实状态）**：749 PC短测第三轮session93583已结束：8项PASS、运行/HTTP错误0、浏览器CLOSED；两次试车/真实W移动/松开与退场音源释放/本地与远端各一idle源通过，cold-hall39.164s。前两轮失败原样保留（旧音源计数断言、驾驶位移采样时机），不改写为通过。证据`evidence/driving-audio-web-pc-manifest-7493837a-body-package-v3`。这不是整段开场流畅或移动性能验收。
- **749教程真实FAIL/CLOSED**：session57875，QA4393 / manifest7493837a，51项后退出剧情页时`StoryPage:179 storyHolo=nil`。首关真实接管/W移动/T返回、debrief两句与leave配音均实际到达；整条路线未通过。错误根因是Key/点击在Rebuild后释放holo，旧mounted page还会Render一帧。root已在StoryPage.Leave同步hide、Create保存page，独立实际UI遍历回归由agent执行，待新包重验。独立checker SHA `e7f63d6419b30d6c5bcddac40989617711b21c340559af3112bae38bd45b7a6b`。输出`evidence/tutorial-drive-route-7493837a-drive-route-20261016-v1/`。普通4391仍749，用户4369仍旧包；GPU当前空闲。
- **下一候选与749隔离**：并行核实/最小修复空袭锁定期间移动车辆的光束落点时机、补开场导弹网格依赖、工资条lockon层序；独立核查全局音效剩余差异。root串行验收，不借749或989c签新代码，不扩装饰，不重开G0，不提交上传。

- **最新749窄性能包，短验中**：`.tmp/outgame-cached-1792106681145` / `manifest-7493837a.json` / fp `eb06729faf0f504a0b62523995b1b11cb847ae4cd7eba2559b4aeef862c3ecf0`，514Lua；相对989c只有Body.lua生产内容变化、0资源内容变化。严格zero-angular点速度短路，实际Lua旧缓存1,120,714/24悬挂场景、新对比935/56场景PASS；独立native84状态+6刷新序列/4190内部检查/0失败，微小非零旋转保留。预览工具另恢复确切同版本引擎/库7z路由，1244文件CRC+size、1239旧fallback字节一致，5原缺失manifest资源单列，18HTTP正负检查PASS。普通4391/session18097、QA4392/session56476，包与HTTP514/514通过。PC真实启动/两次试车/驾驶音频短测session39816正在执行，未回结果不签网页收益，不借989c自然全序列结果签新包。自然整段卡顿/地图预取92s问题仍OPEN。
- **下一条明确功能接续**：S02教程drive-first公开入口→真实首关接管→W短驶→T正常退回→debrief→leave→edit→E→bag。现有旧checker在build分支battle处双跳过；989c自然只证明教程交接，纯Luadrive-route不代替这条真实路线。g1正在补独立窄checker，root串行验；当前未确认生产故障，禁止先造修复。不重开G0、不提交上传。

- **989c自然全序列已结束，浏览器CLOSED**：66功能PASS/运行错误0，真实玩家射击打伤easy并触发原剧情击毁流程（Health先1→0.9051，再触发<.9门槛；Host随后脚本Kill余血，enemyHit=true/mine=true/Health0/kills1/kill_confirm1），不能表述为纯实弹自然打完全部血量。后段完整演出、4:3/16:10/20:9登记、签名盖章/闸门/700ms淡出/教程接管完成。连续性仍FAIL：boot→ready92.257s，RAF P9566.735/P99100.095/max767.25ms，1帧>250ms；audio callback max805.555ms/14候选、实际mix max1.875ms。751ms长task标记gate，尚未唯一归因。独占资源退役后array0/model19,875,047B/总资源102,109,375B。本轮boot新增覆盖与抓图不能声称缩短总预热；完整像素/演出1:1与移动真机仍OPEN。root已看真实射击伤害、4:3登记/工资条/格言图；g2确认工资条顶部lockon标签被电影黑边遮挡为P2层序差异，需修复，其他审图不代替完整视觉验收。证据`evidence/intro-natural-web-1600x900-manifest-989c7ba6-comic-promo-capture`。
- **下一实际重点**：固定sortie窗口540Tick/1582step，平均46.37ms/Tick；悬挂Sample+Apply占vehicle计时56.44%/Tick26.33%，腿/机甲控制未在此路线执行，不能据此改腿。继续只读核查Body/Space重复桥接及加载资源依赖后做最小候选，不重开G0、不重修已关闭GC、不扩装饰；保留全部原玩法/预热覆盖。普通预览4389，用户4369仍旧包。freshness复查发现QA工具报告关联的audit-unified-snapshot脚本有1处新漂移，需实际重跑该报告，不能沿用先前FRESH口述。

- **当前989c三线合包正在自然验收**：`.tmp/outgame-cached-1792105799832` / `manifest-989c7ba6.json` / fp `2253d618d9e28b4650dff8c70a4be8e58639f515814eed10540bba7ed0379df8`，514Lua。普通4389/session9160，QA4390/session4478，自然session48473/tag=`manifest-989c7ba6-comic-promo-capture`。新增原首机位预热（保留原七阶段）、年假格三帧GPU真实机库抓图、漫画层盒变换/独立震动/纸页淡入、四段montage与decided/mechanic闪光、hero缩放、motto黑幕/工资条红闪曲线。红鸽变色/随机碎片及全局pulse仍OPEN，前面进度口述红鸽已补不准确，以此更正。保留已批准字幕。独立实际payload514/514、HTTP身份已核。当前不借6cf签性能；本包未回结果不签通过。不重开G0、不提交上传。

- **6cf最终窄修自然已结束，浏览器CLOSED**：65功能PASS/运行错误0；真实射击击毁、所有后段演出、三比例登记/签名/闸门与教程接管通过。连续性仍FAIL：boot→ready87.821s，RAF P9566.735/P99100.125/max800.6ms/2次>250ms；audio callback max828.76ms/15候选，mix max1.38ms。最大782ms task在hall-return，另sortie-play302ms；不签不卡或移动性能。资源退役后array0/model19,875,047B/总资源102,314,798B，确认释放有效但整体性能未关闭。当前包fingerprint `3b911e3963c491a699c9b710b42f3311cd46047e18a8ce8bc353920bed84c49d`。下一批固定接战斗Tick持续负载、idyll首编与回厅长task，禁止重复修GC、重开G0或借功能PASS签性能。

- **最终窄修包6cf自然复验中**：`.tmp/outgame-cached-1792104742555` / `manifest-6cf48957.json`，511Lua，普通4387/session52871，QA4388/session9329；自然session90044/tag=`manifest-6cf48957-final-gc`。相对cb9仅CollectionCycle变化（1c015323…225e68e0）；GC22/runtime446/RT830/webmap124/QA48均实际PASS、freshness0。独立payload/HTTP511Lua、74报告407关联零漂移。未回结果不签通过。
- **cb9自然已结束，浏览器CLOSED**：65功能PASS/运行错误0，完整真实驾驶击毁、后段演出、三比例登记、签名盖章和教程接管完成；连续性FAIL，maxRAF433.645ms/2次>250ms，audio max473.32ms/14候选。通讯期间独占陨坑释放成功：资源253,755,186→101,322,943B、数组67,109,584→0B、模型83,351,733→19,875,047B。App pending/Host pending/retirement jobs均清空。CollectionCycle的package.loaded探针在WASM中未取到模块（false），不能编造epoch实测；上述实值足以证明本路线资源释放，不证明所有OOM修复。root看过真实漫画、工资条、伤害数字及20:9登记截图；完整演出像素/字体/流畅与真机仍OPEN。

- **cb9功能候选正在自然实跑**：`.tmp/outgame-cached-1792104485199` / `manifest-cb9f15ca.json` / fingerprint `c246c2ff821a5cdf7a929a3b6ba889c43cd1dbc3ee31e74e77a3f247539db6fd`，511Lua。普通4385/session90779/PID30536；QA4386/session72146/PID31596；自然session73728/tag=`manifest-cb9f15ca-shared-gc`。独立实际payload511/511、7509entries、74报告/406关联与HTTP/main/probe全部PASS。用户未切换，未出结果不签自然PASS。
- **下一候选仅Coordinator窄修**：真实Lua额外确认在终结器里Stop/同步升级时不能立刻切GC模式，及恢复模式自身会运行终结器；CollectionCycle把恢复请求延迟到外层操作退出、切换期间也禁止重入。g1固定回归已报两路径后停止扩边界；cb9旧源码/实跑/包审证据保持独立。其余生产冻结。

- **e41自然验收已结束 FAIL，浏览器 CLOSED**：59检查/运行错误0，功能与连续性均FAIL，gate前独占陨坑资源释放未完成。真实驾驶击毁mine=true、后段演出及三比例签名盖章已到达，不代表教程交接通过。boot→ready88.602s；RAF P9583.395/P99116.72/max350.275ms，2次>250ms；audio callback max389.3ms/24候选。资源253,756,090B/数组67,109,584B/模型83,351,733B未下降。旧probe的pending是Host字段，不能仅凭它区分App guard与GC等待；真实Lua5.4已独立复现分代step始终false的错误及双消费者丢完成信号。
- **当前修复接续**：root新增共享CollectionCycle epoch与生命周期fence，App/RT共用完成信号、恢复原GC模式；g1负责真实Lua历史负控及回归；g5补App guard/epoch探针；g2独立审图与代码。不重开G0、不提交上传，用户4369仍旧包，e41不交付为完成。

- **当前统一包e41f909a，自然验收中**：`.tmp/outgame-cached-1792103454037` / `manifest-e41f909a.json` / fingerprint `734bb1ce103fb7abf2a06811d3bafc5700b841417d511cf5d9937c4be1c18831`，510Lua。普通4383 PID46448/session56348，QA4384 PID65264/session28861；HTTP身份已核，probe `8447e628c38685e86f1b659cb1b44ad8823610ef8d6014d44f129856e7de79dc`。自然session21207/tag=`manifest-e41f909a-unified`，完整真实驾驶/开火/后段/三比例签名/教程，新增motto/选择退出/合同展开截图；仅OOM abort hook，不加CPU/FS扫描。未回结果不签通过。
- e41独立实际payload审计PASS：510/510Lua、7508entries、72报告/395关联零漂移；QA工具30PASS/freshness FRESH。生产冻结：Session c897536f…19514d（首boot Update并行两组raw请求，native仍audioReady&&sceneDownloaded）；Page ddf34c76…8046827d（原合同/motto/选择尾段/提示）；HangarApp 3c045877…7c6f1fb8（增量GC完成后扫缓存）。旧contract-cost和promo-motion因样式改变不再作为当前等价验收，原证据保留，替换为两份源对照实际绘制报告。嘴型/RMS波形、完整视差/协调pulse/漫画离场背景仍OPEN，不借离线PASS冒签。

- **接续更新，82a实跑已结束**：exec98129已结束、浏览器CLOSED；65功能PASS/运行错误0，连续性FAIL。真实驾驶击毁mine=true、全部后段、4:3/16:10/20:9登记、签名盖章、700ms淡出、音频尾段释放及教程接管完成。boot→ready89.325s；RAF P9566.73/P99100.09/max683.835ms，3次>250ms；audio callback max733.64ms/10候选。本次无OOM，不等于普遍修复OOM。37分片/202ms/最大25ms的陨坑退役在通讯阶段已完成，但模型83,351,733B/数组67,109,584B/资源256,881,192B没有下降，内存释放仍OPEN。
- **82a之后的未打包批**：root让增量资源释放等待真实GC周期完成再扫cache，补追加/重入/同步升级回归；g2补原motto、选择退出尾段、合同入场/签名板展开/福利富文本/角标遮挡；g5已冻结IntroSession79ea3758…eaf2bd9，修n17显式空字幕、真实配音结束后的下一句提示、choiceAt。保留已批准底部字幕样式。待统一冻结、刷新报告、同包自然复验；不借82a签新代码。当前用户4369仍旧包。

- **最新冻结82a41dd6正在验收**：`.tmp/outgame-cached-1792102529909` / `manifest-82a41dd6.json` / fingerprint `ef3e9d7be054d3734a7e0401515e7fa440af1f67dd3811a1e59c06f7da7719fa`，507Lua。普通4381 PID3856/session59421、QA4382 PID37884/session58571，HTTP身份已核。自然全序列exec98129，tag=`manifest-82a41dd6-early-retirement`，三比例真实resize；仅OOM abort hook，无FS扫描/CPU采样，但原F8方法计时仍在，不能称无插桩。QA probe SHA `8447e628c38685e86f1b659cb1b44ad8823610ef8d6014d44f129856e7de79dc`。未回结果不签通过。
- 82a新增：comms最后陨坑镜头后立即detach并分帧退役独占陨坑/敌车/物理/特效，保留大厅/页面/配音演出，取消与重复退出幂等；清除已disposed warmup引用。Vivi按原打字结束后等待实际token音源结束，Say/Wait和已批准字幕不改。runtime437/finish53/feedback28、voice253及受影响8报告已实际PASS；g1独立审507/507payload与新增voice报告，生产冻结。
- **已完成开发机预览清理**：82/82旧项目空闲预览进程逐项核identity/PID/manifest/Established=0后停止并确认退出，未删文件，保护4369/4379/4380/4381/4382及用户应用/MCP。停止前WS合计4.654GiB、Private8.438GiB，不等于精确回收量，也不能据此声称修好游戏卡顿。证据`PROJECT_PREVIEW_CLEANUP_2026_10_16.md`与逐项JSON。
- **9b自然诊断已结束，拒绝交付**：exec21072 exit1，浏览器CLOSED，59检查后gate退场`Aborted(OOM)`/2条错误；功能FAIL、连续性FAIL。RAF P9566.730/P99100.090/max316.840ms/2次>250ms，音频max392.975ms/13候选，实际mixer最大1.60ms。CDP采样增加诊断开销，不能用这些数与e9直接算提速；9b没有教程交接PASS。证据`intro-natural-web-1600x900-manifest-9b1ad62f-profile`，最后CompleteFinish110ms，随后OOM，retirement完成未出现。
- 当前并行接续：root核交接资源所有权；g1只读CPU/OOM精确归因；g2重新核身份后清理旧项目空闲预览服务，保护4369/4379/4380和其他项目/用户应用；g5仅修Vivi真实音源结束等待差异（不改变Say动画时钟/已批准字幕）。9b生产冻结，新改动属于下一候选，禁止借e9结果签收。
- 最新候选 `.tmp/outgame-cached-1792101454346` / `manifest-9b1ad62f.json` / `975ff5f1fca165835a678a651b15630394e6aa5af20f8e32c14d36288c492d22`，普通4379(session1167)、QA4380(session68883)。自然Web exec21072正在执行，tag=`manifest-9b1ad62f-profile`，contract后启用CDP CPU采样；本次为诊断路线，不能与e9直接比较提速比例。QA probe=`7511c2ae60446c6734a638e3b2bdc671d987b1d63dc04a535d9a212d74924681`，新增慢App.Update/资源轮询/音乐准备/退场分片/F8 Dump计时；生产冻结。独立实际payload审计507Lua/7505entries/71报告390关联零漂移。
- 9b收入e9之后的独立音频补丁：hold心跳随进度加速，heart/voice/签名短淡出，tvcut450ms后150ms淡出，音乐从当前gain退出，通讯展开confirm。358新增JS/Lua对照及1529/402/53/423/53/3953原回归均实际通过，但不能代替本包自然Web。公开Lua DSP无等价接口的原总压缩与tvcut低通保留OPEN，未声称引擎底层绝对无此功能。
- 当前新候选 `.tmp/outgame-cached-1792100831658` / `manifest-e9f25319.json` / `7708b46bc4fa2b0c80ad13f79d472e06ebd71bb124bdfdd9ad65eb5abfdd3eb6`，507 Lua。普通4377(session22364)、QA4378(session75848)。完整自然Web exec81075已结束/CLOSED：**63功能PASS/errors0，连续性FAIL**；audio max711.9ms/15候选、实际mix max.98ms；RAF P9566.745/P99100.155/max667.16ms/3次>250ms。真实射击、完整后半段、三比例登记、签名、700ms淡出、音频尾段释放及教程交接通过。独立实际payload审计PASS：7505entries、70报告/385关联零漂移，QA工具30PASS。
- e9新增原结束700ms墙钟淡出/交接、音频1.2s淡出及1.4s独立尾段释放、合同与盖章叠层退出、六销/旋锁/分锁盘/白汽缝光、motto逐句揭示及salvage广告退出；保留已批准底部字幕。自然QA新增盖章/开门/20:9开门/淡出截图、回厅音频尾段释放断言和退出各调用计时。用户4369仍旧包。保持生产冻结，不重开G0、不提交上传。
- e9后续音频独立批由g5补源已证遗漏：hold心跳加速/100ms退出、tvcut450ms后150ms淡出、voice短尾段、签名声淡出、从实际当前gain停止音乐、通讯confirm；不能借e9签新代码。g1只读对齐e9退出长task（beginHost0、hostDispose69、restoreHud4、complete74ms），尚未确认剩余667ms的归属。root实际查看e9完整漫画、工资条、射击伤害反馈、contract-stamp、20:9开门图，未签所有像素/字体/移动真机一致。
- 最新卡顿候选 `.tmp/outgame-cached-1792099539845` / `manifest-5f39f096.json` / `48c659df9cc9568bc56e5c9db0bc6b225d038dde98a27357fd18dd43c4563643`，普通4375(session86185)、QA4376(session30107)。自然Web exec8667已结束/CLOSED：**61功能PASS/errors0，连续性仍FAIL**，audio max631.91ms/9候选，RAF P9566.735/P99100.095/max550.43ms/3次>250ms。首boot到ready90.587s。真实easy最低Health0、mine=true/kills1，三比例登记/真实签名/完整后段/教程均到达。独立审包502/502 Lua、65报告344关联零漂移。
- 5f包含合同排版缓存、single shader准入候选、分帧独占场景退场、GC周期完成后安全释放RT、音效原字节预取。实际retirement46 slices/work232ms/max25ms，不能把附近527ms longtask直接归给其单slice；stamp仍有Page303ms峰值。两个目标VERTEXCOLOR非INSTANCED shadow仍在countdown/play首编，single候选未达其预热目标。证据 `G1_INTRO_5F_READONLY_OBSERVATIONS_2026_10_16.md`。root实际看过5f完整漫画、盖章工资条和真实射击反馈图；未签所有演出1:1/不卡/移动真机。下一QA补退出各调用计时，不能借5f签后续包。
- 下一批与5f实测隔离：g1负责源结束700ms淡出及正确教程交接，g2负责合同stamp退场叠层和闸门白汽/缝光/分锁盘/六销时序，g5负责motto逐句揭示与salvage退出；不改已批准底部字幕，不重开G0、不提交上传。残差来源 `G1_INTRO_LATE_PARITY_RESIDUALS_2026_10_16.md`；下一批未打包，不借5f结果签通过。用户仍4369旧包。
- 最新候选`.tmp/outgame-cached-1792098352922` / `manifest-3ba43bd8.json` / `769ae9cf779b74e3632c2b6dd16c689bb3af02dd71619832da60eb0c66b07b8b`，普通4373(session85134)、QA4374(session23149)。自然全开场exec39552已结束，浏览器CLOSED：**61功能PASS/运行错误0，但连续性FAIL**，audio callback max1473.835ms/17候选，RAF P9566.73/P99100.12/max767.245ms/6次>250ms，不能交付为不卡。真实玩家先于超时打中击毁easy敌车，mine=true，伤害1162/hits482；伤害数字、准星反馈、确认音及开场battle gain .3/feedback gain1实际通过。已走完工资条/装配/驾驶/导弹/后续广告/通讯/三比例登记/真实签名/闸门/教程交接。用户尚未切换。
- 3ba独立审包501/501 Lua、327关联零漂移；g5复核本批演员/池/取消释放所有权，未发现新增确定错误。root已看通讯、4:3/20:9登记、回厅图；没有签字体/质感全面1:1。预览四条engine-assets@windows.7z 404为fallback请求，实际资源组完成，保留HTTP证据。
- **下一步固定接续卡顿修复，不重开G0**：g1负责实际gate退场745ms longtask对应OpeningHost/IntroBattle/HangarApp集中销毁回收，及sortie新shadow VS267ms/FS36ms加载期覆盖；g2负责Contract字段共用一个SourceParagraph导致每帧反复Rich.Layout；g5负责音频callback与交接时间线独立归因。可证实处最小修复，统一下一包串行复验，不删预热覆盖、不删演出、不上传。
- **8581实际Web已拒绝交付**：`.tmp/outgame-cached-1792097529664` / `manifest-8581d52a.json` / `724e60566de0c4e649b9de68022d66951db20547d61abfc0ee49e6e17b35ed14`，普通4371(session77336)、QA4372(session13356)。exec59995已结束/CLOSED，首次驾驶松鼠标时`IntroPromo:116 global s=nil`，0检查/11条重复异常；移除旧击毁提示误删局部变量，是本批回归，g2修复并补实际整个Promo.Draw分支测试。原JSON/log/失败图保留，不能借离线或包审计PASS冒签可用。
- 8581已收入正式DriveOverlay命中/伤害数字/确认音与驾驶Command/武器选择、原工资条/漫画文字/擦屏、音频包络和异步音乐准备。之前已有简化击毁slam，不是所有击毁展示都不存在。独立499Lua与303报告关联审计一致，但实跑失败优先。5份受影响历史检查实际重跑通过，原报告/首次审计漂移保留在`evidence/history-manifest-8581d52a-pre-refresh/`。
- 下一包并行：g1修已确认的briefing AI/handoff easy摆放/endPlay倍数与hero恢复/源fallback；g5修源全局音频上下文混音、开场驾驶声压低和模式音乐选择；g2修Promo并补实际调用覆盖。当前没有GPU测试运行。root随后统一打包、串行完整自然开场；未签不卡/所有演出1:1。用户4369仍旧包，不跳转失败候选。
- 最新用户指出4369开场漫画文字、全段音效、首次驾驶射击、工资条及后半演出未还原；本条覆盖下方“停止开屏视觉”的历史决定，继续原G0-G6，不重开G0、不提交上传。源仍为10/15 b276064942ae09c0227ec28d4cfda1d5ff006455。
- 并行所有权：root负责OpeningHost/IntroBattle/IntroSortieUi首次驾驶实际反馈和统一Web验收；g1负责IntroSession原时序及工资条cue；g2负责Familiar/Promo/Film非字幕文字与工资条；g5负责MusicPlayer异步准备和IntroAudio原包络。已批准的底部字幕保留。各生产增量尚未收入14f，4369仍是旧包。
- 已定位开场没有创建DriveOverlay，s.hud=nil使命中/伤害数字/确认音链路缺失；数字键和Controls.Command未接入开场驾驶。正在修复，尚未签真实射击/视觉通过。旧自然测试enemyHit=true只能证明一次路线命中，不能否定用户问题；旧fired检查不足，必须补实际伤害/反馈断言。
- 上轮剧情01测试已结束FAIL/0check/error0/CLOSED，具体是工具对空widgets JSON对象调用.some（check-story-natural-web.cjs:67），不是已确认玩法故障。证据docs/migration/evidence/story-natural-s1-manifest-14f59378-2026-10-15T20-36-25-906Z保留。

## 14f历史包：登记功能已验，玩法与性能仍未关闭

- 本批生产已冻结：登记横屏布局、通讯/电影补层、开篇直接构造、原字节预取与音频准备重叠、Nono已暖头像交给教程、无shared停止时释放，以及Mission同帧死亡源顺序。没有新增视觉范围，不重开G0，不提交、不上传。
- 新包 `.tmp/outgame-cached-1792095367698` / `manifest-14f59378.json` / 指纹 `8e0db284b925572d0a10249309ac7de9dffdd79ab920de8cfac1e8cd18cffa7b`。普通4369(session23564)、QA4370(session13770)，HTTP identity已核；`combatProfile=false`，但基础QA probe仍含MeasureOpening方法计时，不是无插桩运行，probe `fec8e0c9c49848a7f4e696defbd353ef6b17e12066a51f65f5be922eaa9a20ff`。
- root自然Web exec61672已结束并关闭浏览器：54功能PASS/error0/本次无OOM，完整W/LMB/解锁接管/原片段/通讯/登记三比例/签名/教程交接均到达；最后实际F8教程visible=true且T-01正在播放，array/image/retired均0。总体FAIL：audio callback max705.065ms/9候选，RAF P9566.725/P99100.09/max650.5ms/4次>250ms。不开FS内存扫描但仍有开篇方法插桩，不与旧combat wrappers包直接计算提速比例。旧0bcd OOM和连续性FAIL全部保留。
- root实际看过14f三比例登记与通讯图，终端/输入签名板/通讯不重叠，诺诺正向；未声称所有字体1:1或手机真机通过。最长冻结在回厅交接633ms longtask，与大厅MusicPlayer资源日志同帧、教程下载随后完成；没有同期shader编译，尚不能唯一归因，g5写精确对齐证据。
- 已转玩法：同包自然打捞exec8919结束FAIL/1check/errors0/CLOSED，工具在打捞工坊查旧“放进新车位”入口，而实际显示“购买整车”；g5仅修公开购车测试路径，生产仍冻结。证据 `salvage-natural-manifest-14f59378-2026-10-15T20-23-28-681Z` 保留，不能签自然搜撤。库存999来自冻结SalvageRules.testFill，不签真实经济账号。
- 打捞工具已按实际shop分支修为“购买整车”，保留原dialog/库存购车/车位断言。root同包串行复跑exec99577已结束FAIL/7check/errors0/CLOSED，证据 `salvage-natural-manifest-14f59378-2026-10-15T20-28-45-360Z`：实际购车/投放/接管/驾驶/搜L119箱/货物入仓3格/原目标提示通过。撤离E3路点R13:32在35秒内未到（末距离38.40m、HP1、4敌），自动路由未完成，不等于已证明游戏无法撤离；自然成功撤离与结算仍OPEN。root已看搜货和失败图，场景明暗/整体视觉未签，不扩本轮光照范围。
- 14f独立payload审计已完成：494Lua、54必要报告/278SHA关联无漂移；6份过期报告实际重跑19063检查，全部7487本地manifest文件大小吻合。全manifest约866MB不等于首包下载/显存，见 `SNAPSHOT_14F59378_INDEPENDENT_AUDIT.md`。开篇最长冻结对齐证据见 `OPENING_CONTINUITY_14F_2026_10_16.md`。
- handoff实际Widget/所有权/取消/替换/关闭167项通过，另一agent独立复验通过；result-quote1392/input-progress296已随当前StoryComms重跑。snapshot_14f_audit已完成新包实际payload及报告核验。g4已准备第1关日志自然验收工具和严格三杀/拾取断言，尚未GPU运行；无尽现有Web工具没有自然玩家死亡路线，旧native受控kill不能冒签。生产继续冻结。
- **下轮从玩法继续，不回登记页/G0**：先按 `G4_STORY_DEATH_ORDER_2026_10_16.md` 跑剧情01真实三杀→日志→拾取；打捞自然撤离的自动驾驶需要区分路由控制和实际碰撞，保留原35秒失败，不放宽断言冒签；性能下一最小动作见 `OPENING_CONTINUITY_14F_2026_10_16.md`，调查大厅音乐同步资源完成与退场释放同帧，保留原曲序和取消规则。开屏视觉本轮停止扩展，工资单/转场等原差异保留OPEN。当前没有GPU测试运行。
- 用户IAB仍为4350旧包，不能当作当前构建；本轮普通预览入口为4369，已核HTTP identity。玩法严重性能、原G1-G6未关闭项继续保留。

## 以下为上包历史证据

## 历史：10/16 0bcd 开篇 / 通讯 / 登记平板实际验收

- 0bcd第二次完整自然诊断exec18096已结束并关闭浏览器：`intro-natural-web-1600x900-manifest-0bcd53d6-memory.json`，38功能PASS/error0，连续性FAIL，音频max gap2196ms/9候选、RAF P95 50.095/P99 100.09/max733.9ms/7次>250ms。无OOM hook，hall-return采样2s超时，tutorial VFS570771486；该次未崩不抹除上一自然OOM，也不能拿有采样数据签无插桩性能。
- **下一批收口范围固定**：g4 Mission同帧死亡顺序已实现并刷新相关5报告；legacy raw预取与55帧音频重叠已实现，保留decode与全部7段shader准入，不声称消除编译等待；g5正实现开篇已暖Nono portrait所有权转教程卡/canonical资源复用，避免交接重复解码，随后统一包实际复验。此三项完成前不新增视觉功能。不重开G0、不提交上传。
- **0bcd完整自然播放交接FAIL，不能交付为稳定包**：exec8849走完实际W驾驶/LMB射击/全部广告段落/自然通讯/签名/闸门，35检查后03:58:18教程28资源完成即`Aborted(OOM)`。JSON已即时持久化，shutdown PENDING；OOM后收尾挂起，root确认并停止仅node12520及其Chrome子树，exec已结束1。`intro-natural-web-1600x900-manifest-0bcd53d6.json/.log`保留，不借下方skip PASS覆盖。g5加natural内存/失败分配采样；下一包完整复现归因，暂不签“不卡”或切用户到此包。
- 0bcd真实PC公开开篇→原漫画三段→通讯/第二选择→登记(实际resize4:3/16:10/20:9)→真实键盘姓名/签名→闸门→教程交接已结束：`evidence/intro-web-pc-manifest-0bcd53d6.json`，30检查/error0/shutdown CLOSED。root已逐张查看三个比例与PC登记图、通讯图，诺诺正向、终端/签名板/通讯不重叠。内存诊断VFS大厅298177324→开篇549793397→教程565487082bytes，无OOM；这是诊断路线功能通过，不是流畅/真机结论，也不抹除519历史OOM。
- 同包自然完整开篇/实际W驾驶/LMB开火/音频连续性测试正在exec8849，结果待回。下一批g4获准仅修Mission.AfterStep同帧死亡顺序：冻结H5正向、当前Lua倒序导致第1关日志掉落位置不同；生产新增量不能借0bcd结果签通过。不重开G0、不提交上传。
- a7 已拒绝交付：实际登记页触发 `SetSignatureRect` 自动属性 setter 递归/C stack overflow，随后 OOM。这是本批引入错误，不能用离线通过覆盖。已改为 `UpdateSignatureBounds`，新增真实 Widget 属性路由测试，53 项通过。失败证据见 `evidence/intro-web-pc-manifest-a7d7050c-FAILED.md`。
- 修正候选 `.tmp/outgame-cached-1792093513966` / `manifest-0bcd53d6.json` / 指纹 `0ce36dca9885d2574e7f0990a28fe68327c2fb7acaa8b73367c493e2777c263c`。普通4367(session19480)/QA4368(session49731)。独立494 Lua/51报告259哈希审计通过；实际登记4:3/16:10/20:9与教程交接仍待本包验证。下面a7服务与执行状态仅为历史。
- 519教程交接OOM另案：资源释放日志已确认开篇退场，但Web固定1640MiB堆、VFS下载不随cache释放，教程独立路径立绘存在再次解码峰值。尚无失败分配栈，不能声称唯一根因。g5只补测试工具内存采样，root串行真实验收；不重开G0、不提交上传。

- 接续原G0-G6，不重开G0，不提交、不上传。H5冻结仍为10/15 `b276064942ae09c0227ec28d4cfda1d5ff006455`。本批用户明确：通讯狐狐/诺诺取景/大小/方向、商业片缺层次、预热过久和播放卡顿；新增登记终端平板挤乱。保留用户认可的字幕，不重新设计整套UI，收完本批继续后续玩法。
- 最新统一候选 `.tmp/outgame-cached-1792093046817` / `manifest-a7d7050c.json` / 指纹 `356b354696f3606f0a3da06e20b261e90233ff561af3e88fe62e266345740e48`。普通4365（session19911）/QA4366（session42566）。root正在exec87284实际PC开篇漫画→通讯→登记4:3/16:10/20:9 resize→真实签名→闸门→回大厅教程交接；尚未签通过。独立payload审计交legacy。
- 本批收入：8张冻结源通讯表情、Web两层portrait RT纵向修复、专用contain/董事长缺图依赖/小运SVG；Brand/Film/Familiar原开场台标/电影层/独立三格时钟；OpeningHost直接构造最终IntroBattle，移除1套即建即丢Practice车辆/DriveView；登记IntroContractLayout保持16:9/20:9、缩窄平板构图防主终端宽度崩坏，前后暗晕、原字体输入、签名归一化/resize取消在画contact、CSS像素ink门槛。离线报告分别364、20482、21015、328、52检查；不等于Web画面/流畅验收。
- 519真实通讯 `intro-dialog-web-2026-10-15T19-28-08-098Z` 功能6/error0，但root亲眼确认诺诺头朝下，视觉FAIL。旧native正向不能替代Web；本批只在Web portrait RT bridge翻转，源shader/嘴型UV不动。原截图保留。
- 519实际初段漫画/通讯/签名/门/回大厅完成，教程交接03:35:59.987 `Aborted(OOM)`，工具failure截图卡住，root确认并停止仅该测试PID58236/Chrome子树；exec36929已结束1。日志/截图/`intro-web-pc-manifest-5198310b-baseline-INTERRUPTED.md`保留。不是PASS。旧包当前33秒级预热仍待优化，legacy实测51929.258s/430帧409batches，历史33.228s；293新shader编译无exact重复，不能擅删预热覆盖。新构造改动不能先声称消除等待。g5继续只读OOM归因。
- 519建造真实PC82/20:9 70检查/error0已结束，证据 `selection-actions-manifest-5198310b-2026-10-15T19-22-27-438Z`；真实手机准星删除/松手停删/单事务undo通过，root已看undo截图。3e9前两次失败与错误放宽Escape的第三次INVALID_ACCEPTANCE保留，519是真修复后严格一按Escape取消。不是触屏paste入口或真机性能验收。
- SceneWarmup分组候选已REJECTED并撤回生产至3e9字节：多组single可能被引擎重新实例化，679离线不能证明GPU变体覆盖。实验留tools/migration/experiments，不能作为已交付优化。用户旧IAB4350尚未换新；等实际结果再切最新普通页。所有工具GPU串行，用户编辑器仍开着，不声称GPU独占。严重战斗性能/后续G1-G6继续OPEN。

## 历史：10/16 3e9 建造操作真实验收与后续功能并行

- 接续原 G0-G6、冻结 H5 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`，不提交、不上传。最新统一包 `.tmp/outgame-cached-1792091147478` / `manifest-3e9b0260.json` / 指纹 `1af54ef554f01814da1b527bbca4428c809c0552b836af3cb15924cc5be3834c`。普通 **4361**（PID9968/session46106）、QA **4362**（PID47840/session8993）；HTTP identity 已核，QA probe `e203b62430fec32aacff7510a56799ca84786293aecc3e35fa0edd64d75ddf92`。
- 195 真实竞技 exec4654 已结束：公开匹配/加载/驾驶开火/右键快按与长按/确认退出，运行错误0；普通按钮实际primary声1次、右中键与hover静音通过。狙击线与Glow真实shader在加载期载入。退场world/HUD/小地图/capture均释放，array/image/retiredTargets归零。证据 `evidence/combat-performance-2026-10-15T18-57-14-112Z`，实际开镜图已查看。
- **性能仍FAIL**：195 live327帧，中位50.050/P95 83.415/max166.780ms、9帧>100ms；match-load max4136.465ms、190帧>100ms。下载34.943s/场景6.605s/碰撞13.610s/activate46.003s。未签流畅、手机或自然整局。
- 195 选区测试真实发现焦点Enter跨帧重复触发匹配；已停止该工具及其自有Chrome，原日志与 `INTERRUPTED.md` 保留于 `evidence/selection-actions-manifest-19556941-2026-10-15T19-00-44-605Z`。不是通过。ActionButton已修为按住/按键脉冲生命周期消费，且不阻塞其他快捷键；99键盘/1353指针/97repair离线通过，同夹具复现195旧失败。最终SHA `7a949207d08f261700581626da84b6120cfbba45b423cac8228d0d385284a5c5`，收入3e9，等待真实复验。
- root正运行3e9公开PC/20:9选区条、批量涂色、撤销重做、剪贴板与键盘流程，exec17799；结果未回不签。legacy独立审计3e9实际payload并定位已实测CPU热点，g4继续剧情功能，g5核触屏建造原版可达路径；后续生产增量归下一包，不借3e9结果签收。
- 严重性能、自然完整剧情、G1物理手感、G2整体字体/断行/视觉、真实账号/编辑器与手机持续性能继续OPEN。用户编辑器仍开着，不声称严格GPU隔离。

## 历史：10/16 195 选区 / 目标栏 / 输入功能批统一Web验收

- 继续原G0-G6与冻结10/15 `b276064942ae09c0227ec28d4cfda1d5ff006455`，不提交、不上传。当前统一包 `.tmp/outgame-cached-1792090565231` / `manifest-19556941.json` / **488 Lua** / 指纹 `e3ebb6f8193d72ea816eb77dc58a1b2b3fe9b40cc1e898b7b069caac07b7e349`。普通 **4359**（PID60820/session1267）、QA计时 **4360**（PID9652/session15836）；HTTP identity已核，QA probe `56c7a71b0f7a58ab2037645d75099671312ed554b5746f4b273844d49ec16d84`。
- 独立实际payload审计PASS：488 Lua/46报告228SHA、资源字体与原语音一致。c787→195为11 Lua内容变化（含2新增）/0资源内容变化/0删除，meta另计，见 `SNAPSHOT_19556941_INDEPENDENT_AUDIT.md`。
- 新收入：源七入口选区条与单事务批量涂色/撤销重做、选区条手机横滚及hover偏移；大厅焦点按钮Enter/小键盘Enter/Space与快捷键优先级；剧情650ms完成态/420ms切换动画/末目标保留；真实Widget:new属性路由下普通按钮声识别修复。生产已冻结，不再扩本批。
- root真实Web竞技/音效/开镜exec4654正在运行（`evidence/combat-performance-2026-10-15T18-57-14-112Z`）；g4仅准备选区条公开操作Web工具，未占GPU。下一步同包教程音频PC+20:9，以及选区条实际点击/撤销/重做/布局。结果未回不签通过。
- 既有竞技严重卡顿、加载长冻结、自然全剧情与G1-G6未关闭项继续OPEN。真实手机持续性能未验；编辑器仍开着，不声称严格GPU隔离。c787两次真实按钮声FAIL在下方保留。

## 历史：10/16 c787 音效 / 按钮批实际Web回归，选区操作条并行实施

- 继续原 G0-G6 与冻结10/15 b276基线，不提交、不上传。新统一包 `.tmp/outgame-cached-1792089992674` / `manifest-c787bbd6.json` / **486 Lua** / 指纹 `ca51f664b2b5e9d4a67748fa800f9fb98ca739a7d8d1e0c12b2d37b41ce36d57`。普通4356（PID56900/session29867）、QA计时4357（PID59052/session82307），两个HTTP identity已核；QA probe `4fa3c7569a2b2193d240b1e985117fb876d263ac76162d1892d8e36e4d643644`。
- 独立实际payload审计PASS：486 Lua、43报告216SHA及27资源、字体许可、12剧情OGG、7原UI WAV、7原Radio WAV一致；e31到c787为43内容变化（37Lua+6资源）/7新增/0删除，meta另计。不是全部迁移完成声明。
- c787收入：七原UI/建造音效与原10声音池、可选回调保持建造域独立；通讯开闭/截获cue；旧Web对白移除同步解码；普通按钮右键中键不再触发导航；加载期间使用真实狙击线/枪口/落点shader预热。root已启动串行公开匹配/右键镜/音效检查exec73254，结果待回。
- 审计后下一生产批与c787分开：g5补源七按钮选区操作条及批量涂色；legacy补焦点按钮Enter/Space优先于大厅快捷键；g4只读定位下一G4明确缺口。后批尚未打包，不得把c787运行结果套给新工作区。
- 原严重性能FAIL及G1/G2/G3/G4/G5/G6未关闭项继续保留，不重开G0。用户编辑器仍开着；工具Web测试串行，不能声称严格GPU隔离。
- c787实际Web exec73254与诊断exec43984已结束并关闭工具浏览器：右/中按钮静止正确，primary正常切battle但press计数0，两个报告保留FAIL：`evidence/combat-performance-2026-10-15T18-47-44-337Z`、`evidence/combat-performance-2026-10-15T18-51-18-307Z`。未进匹配，运行错误0不覆盖功能失败。诊断确认focus=true/ready7/primary=true，但metatable为属性路由并非类，旧ButtonAt从getmetatable查继承断链。root后续UiSound改为控件暴露的_super链，实际Widget:new含代理构造新增200项通过；修复待下一包实际点击验证。

## 历史：10/16 e31 已验，后续音效 / 按钮功能批收口中

- 继续原 G0-G6 与 10/15 `b276064942ae09c0227ec28d4cfda1d5ff006455` 基线，不提交、不上传。统一包 `.tmp/outgame-cached-1792089242755` / `manifest-e31a194a.json` / 484 Lua / 指纹 `72a18e389300951f4bc6019146d512d49a94bb3ccb21846bd4593ea82f5a06d6`。普通 **4354**（PID10840/session7420）、QA计时 **4355**（PID61536/session51998），HTTP identity 已核。QA probe `5744539dc750337ee78487575b2b2a9bd83167682fc610a26201ae91b81d6ff5`。
- 收入046之后：普通腿 Target 标量化（无规则/射线/步长改变）、狙击线逻辑像素宽/原线性色/枪口横芒、死亡期间已排定选择倒数/片尾观看持久化、原按钮和教程 press/confirm 音效。专项分别见 `G1_LEG_TARGET_CPU_2026_10_16.md`、`AIM_LINES_RENDER_2026_10_16.md`、`G4_CHOICE_EPILOGUE_2026_10_16.md`、`UI_SOUND_2026_10_16.md`。
- e31独立实际payload审计PASS：484 Lua，40报告161 SHA无漂移；字体/许可、12剧情OGG、2原WAV与配置/shader都审至实际发布文件。046→e31共13项非meta变化（9脚本+4资源）、4新增0删除；meta变化另计，不能写成字节完全一致。
- e31真实教程PC exec94447结束：`evidence/tutorial-web-pc-manifest-e31a194a-audio.json`，15项PASS/运行错误0，实际按钮press 8次/条件confirm 2次，root已看pick截图。只到实际B背包操作，不签完整教程、试听或真机。
- e31 exec10693已结束为真实输入FAIL：`evidence/combat-performance-2026-10-15T18-35-13-667Z/report.json`。右键出战按钮发生导航（原生Button.OnClick未过滤primary），声音正确静音；后续工具找不到原按钮，尚未进匹配。运行异常0不能覆盖功能失败，截图已看。legacy已在后续工作区补项目ActionButton及所有22处派生基类替换，1299离线检查；e31本身仍FAIL，不复写旧证据。
- 后一批并行写入，不属于e31：g4原通讯open/intercept/close + 旧Web对白后台解码；g5建造place/remove/paint/stamp/open成功音效，以可选callback保留建造域独立；legacy统一Button主操作过滤。root补狙击实际线/枪口/落点shader预热到现有loading帧，59生命周期/1272源对照PASS。待统一下一包串行Web，不从G0开始。
- 当前工具GPU空闲；用户编辑器仍开着，不能声称严格GPU隔离。严重竞技/加载卡顿、自然全关、字体视觉与真实手机性能继续OPEN。

## 历史：10/16 046 驾驶 / Boss / 搜撤 / 装配接续批

- 继续用户的功能迁移要求，不重开 G0，不提交、push、上传。H5 已再次实查仍为 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`。本批已冻结统一包 `.tmp/outgame-cached-1792088233891` / `manifest-046debe2.json` / 483 Lua / 指纹 `0b49218d133898ab42032b9248b9116d21a2f52f85e960912ff0c77f4c527207`；普通 **4352**（PID22464/session98632）、QA计时 **4353**（PID32640/session70585），两个 identity 已实查。QA probe SHA `26f9d974e922cffe688214f540ab26e5510d1bfc6ad03a7589cbe950ab01ffca`，含更细装配阶段；不能套用旧运行结果。
- G1 新补普通腿混合承载、水平推进超速时不反向制动、离地/贴墙状态恢复。冻结源 JS 对实际 Lua 240 组合/720 帧/2 恢复用例，297959 检查通过；旧 4227 206 失败场景已复现。LegControl SHA `7efea6b1d747c8d20095610057e03ebec2f62a62039963f2fb67f1473e36905d`。Gait 世界位置缓存无稳定 CPU 收益，已拒绝接入，生产 Gait 保持旧包一致。
- G4 新补 Boss 用物理飞行时间落地、普通 hop 不重置 slam 冷却、玩家死亡后不再发起新 specials。1090 源 JS/Lua 检查与原 7826 回归通过，实际自然第五关仍待验。当前 H5 已删除 barrage 对白内容，未恢复废案。
- G5 新补搜撤重进圈使用保留倒数安排接应、原撤离中绿色 feed/信号塔首次 NameCard、无尽金币 toast 1400ms 和死亡时出发/改装等待提示。547 源 JS/Lua 检查通过。Spawn/SpawnUnit 改为复用现有场景所有的 SpawnSpecCache；51 原版 prefab 各连续3车真实 Build204→51，受损后第4车完整/0新增Build、克隆隔离和释放等1291项通过。EndlessSession 最终 SHA `2661cbf0e34b0a51ac2f423ec49c1808e0df37840127efe552057d488ac8572e`，出生497/生命周期22/横幅222/交互547均已重跑。源 toast 本身高于 HUD，短暂遮挡属原表现，不擅改坐标或层级。
- root 新补炮管射界保守 AABB 提前排除：采样步长/顺序/射界不变；无交结果不持久缓存，坐标超 Hash 安全域仍回原扫描。80 真实竞技预制车各 3 次交替冷构造及热缓存，92352 逐 double 对照通过，离线 CPU 中位合计 9929ms→2336ms，本轮无变慢车型；不等于网页帧率或进场总耗时。生产 SHA `0262725b6034c2f6572a32609394e2f88d92b44a3b883f0e86dc0caa9c7bca2f`，89 删除/新增/恢复与1924完整破坏回归通过。独立临界/Hash别名1804项，实际裁剪逐sample共125873600Hash验证无漏命中；见 `TURRET_BOUNDS_2026_10_16.md`。
- native 破坏检查在启动frame23 shader阶段超过原75秒deadline，exec6064已结束为 timeout，没有跑到frame40断言；日志归档 `evidence/native-damage-timeout-2026-10-16T02-13/`。旧 `damage-parity-native.json` 是10/15旧结果，绝不冒签本批native通过。
- 046 独立实际payload审计完成：483 Lua、36报告145SHA、字体及语音配置一致，见 `SNAPSHOT_046DEBE2_INDEPENDENT_AUDIT.md`。真实竞技 exec34582 已完整结束：公开队列/进场/驾驶开火/确认退出，运行错误0；退场世界/小地图disposed、array/image/retiredTargets归零、model回16.31MB。证据 `evidence/combat-performance-2026-10-15T18-18-10-110Z`，root已看局内HUD/小地图图。live262rAF：中位50.045/P95 83.410/max183.465ms，7帧>100ms；加载max4386.685ms/180帧>100，性能仍FAIL。实际下载34.839s/场景6.673s/碰撞13.609s/装配及预热46.021s；不拿不同随机阵容与旧包计算提升比。
- 046 同包无尽 exec42047 已结束并关闭工具浏览器：`evidence/endless-banner-manifest-046debe2-2026-10-15T18-22-07-300Z`，29功能检查/运行错误0；QA实际清敌五波/T2补给/G暂停改装/返回升起保护通过，未签自然五波或死亡复活。7049rAF，中位16.685/P95 50.05/max4103.165ms，191帧>100ms，性能FAIL。旧IAB暂在about:blank，用户自己的编辑器runtime未终止，不能声称严格GPU隔离。
- 下一功能批正在并行，尚未收入046：root狙击线高DPI像素宽/原枪口光轮廓及线性色；g4片尾watched与死亡期间剧情选择倒数；g5普通按钮/教程原批准UI音效；legacy按046真实CPU检查LegControl重复计算，仅有稳定收益的候选可接入。禁止用046结果签下一包，不重开G0，不提交上传。

## 历史：10/16 4227 功能批

- 按用户要求继续功能，暂不提交、push、上传。沿用 G0-G6，不重开 G0。H5 再次实查为 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`；目标 `main / 9541dc59ef2f281cafa5126762a57550189e04dc` 加现有未提交增量。
- 当前统一包：`.tmp/outgame-cached-1792086673066` / `manifest-4227f9e4.json` / 483 Lua / 指纹 `1ae345494d80655706ffe21e522cfdd124374f068e0d40e27acec4c780a79d6f`。普通端口 **4350**，QA计时 **4351**；两个 `/identity.json` 已实查。QA probe SHA `9e45e573ce7f02cce409ac5ec34ead530199f23f998ea3899151c1ec8061f6ef`，仅在QA新增普通腿/机甲腿碰撞更新累计计时，无逐帧log。旧服务和下方旧包结果均不能当作本包结果。
- 新包收入：车辆销毁/重建渲染前事件同步、敌车白闪/盾蓝闪、源连破副行、Boss 盟友规则/跪地/路点缓存、Math3 标量化、加载页真实闪光 shader 预热、保险库警告/开箱反馈与实际水平位移停稳判断、维修符号字体修复。保险库入口 675 项、拾取 92 项、结算 29 项重跑通过并经独立复核；离线数值/接线检查不能代签自然游戏、视觉或真机表现。
- 4227独立审计已通过483实际发布Lua/30报告120SHA，9个项目字体及repair许可/来源、12OGG与3配置实际payload一致，见 `SNAPSHOT_4227F9E4_INDEPENDENT_AUDIT.md`。相对b6f仅StoryBoss.lua生产内容变化，资源内容未变；构建生成的UUID/meta有变化，不能声称发布字节全部不变。
- b6f公开真实射击已完成：`evidence/destruction-web-2026-10-15T17-46-27-022Z`，21项功能检查/运行错误0/probeErrors0。真实shader首次在trial-load、开火前载入；白闪141/盾蓝闪41，GT209→152件后击杀、+300与实际音效通过，root已看受击和击杀图。1070射击rAF中位33.345ms/P95 50.015ms/max66.795ms/0帧>100ms，57次Flush最大20ms；仅本路线100ms门槛通过，不签稳定60帧/竞技/手机。
- b6f五波已结束并释放工具浏览器：`evidence/endless-banner-manifest-b6f6882e-2026-10-15T17-48-52-266Z`，29功能检查/运行错误0；1条edit-return探针JSON截断保留，后续完整探针恢复。第5波T2、G暂停改装/返回升起与保护通过；QA实际销毁敌人清场，不是自然五波胜利。root看维修卡/第五波/返回出击图，白色维修符号正常，奖励toast仍遮挡tier横幅。6936rAF/208帧>100ms/max3886.34ms，性能FAIL。
- 4227新增第五关第二/三阶段跪地对白池、防连续重复和通讯busy门禁，源JS/生产Lua1617项通过，waypoint952/kneel2178/allies3079按最终StoryBoss SHA重验通过。b6f射击/五波不含此增量，不能冒签4227完整回归。Boss自然完整关卡与试听仍OPEN。
- 4227真实单次竞技进场/驾驶开火/确认退出已完整结束，`evidence/combat-performance-2026-10-15T17-52-58-045Z`，MEASURED、运行错误0、75条CPU累计快照；root已看实际局内HUD/小地图图。退场世界/view/effects/scene与小地图均disposed、array/image/retiredTargets归零、model缓存回16.31MB。本次没有观战/MVP/再匹配或自然整局，不借旧包签这些项。
- **4227性能仍FAIL**：match-live 252rAF，p50 50.060ms/P95 83.420ms/max383.605ms，7帧>100ms；match-load max4019.735ms/177帧>100ms；boot max3452.625ms，return max867.360ms。探针带inclusive计时开销，不与旧随机阵容直接计算提升比。独立细分已结束，见 `CPU_ATTRIBUTION_4227F9E4.md`：6车64固定步尾窗，普通腿碰撞共16ms，不是主成本；整车控制/腿控制/物理仍有可测成本。Mech零调用未验；含截图的尾窗不能当稳定基准，嵌套毫秒不相加。
- 下一窄批：沿已证实的VehicleSpec Graph/Connectivity/Rotors/BuildParts/TurretRange加载checkpoint分段定位，以及整车/腿控制的实际重复工作；保留60Hz与物理/画面规则。并按G4/G5原清单补自然完整关卡/搜撤与toast遮挡，G1/G2原验收不清零。不要继续凭旧报告占比优化，也不要把这批小项通过写成G0-G6全部完成。
- 本批工具浏览器已全部关闭，GPU空闲；4346–4349旧包服务已核对PID并关闭，只保留当前普通4350/QA计时4351。没有提交、上传或发布。下一批沿原计划推进上述未验功能和真实成本，不重开G0。
- 仍未关闭：严重竞技/加载卡顿、地理分片流式加载（目前不是）、G1 全移动物理手感、G2 字形/断行/全页面视觉、自然完整剧情/无尽死亡复活/打捞搜撤、真实账号及编辑器、横屏 20:9 真机持续性能。e1fc 的 100.090ms 射击长帧与无尽 3586.1ms 加载冻结保留为真实失败，不套用为本包结果。

## 历史：b239 至 e1fc 功能批

以下状态只记录当时执行过程；当前包和待办以上方唯一接续点为准。

- 最新冻结包为 `manifest-e1fc12f8.json` / `.tmp/outgame-cached-1792085173431` / 482 Lua / 指纹 `ceead2388adb4f8d0a2c5eee2b3bbf38fdb57ac1325610150e6d5640794c1e6e`；普通4346、QA4347。独立482发布payload/24报告98SHA一致，收入TrialSession a869的渲染前事件同步。实际Tick联合旧e266复现与新修复24项通过（含真实PlayerViewSync、0/2/3步、事件一次消费与early-return）。root正串行跑公开射击并观察实际白闪，随后g5跑五波/暂停改装；尚未签此包Web通过。g4继续源剧情缺项，legacy定位竞技实际CPU热点，无GPU并行。旧包结果保留为历史，不重开G0、不提交上传。
- e1fc公开破坏已结束：`evidence/destruction-web-2026-10-15T17-27-05-967Z`，19功能检查PASS、运行错误0、probeErrors0；真实白闪138/护盾蓝闪39，实际活跃闪光截图已查看，靶车209→147再击杀、+300收集、kill_confirm1/score_tick12通过。59次实际Flush最大18ms。**性能仍FAIL**：射击窗1174rAF，中位16.695ms/P95 33.415ms/max100.090ms/1帧>100ms；该长帧附近没有Flush样本，不能归因为破坏或从统计删掉。g5现独占GPU执行同包真实五波与暂停改装；g4开始补源第五关Boss路点缓存（不属于e1fc）。
- e1fc无尽同包已结束：`evidence/endless-banner-manifest-e1fc12f8-2026-10-15T17-29-09-255Z`，29功能检查/运行错误0；自然出兵倒数、QA实际销毁后五波清场与补给、第5波T2、G暂停编辑4秒/壁钟横幅到期、出发升起和模型保护闪烁通过，root已看三张关键图。不是自然打通五波/死亡复活验收。6638rAF全保留，总max3586.1ms/211帧>100ms，性能FAIL；维修符号缺字和奖励toast遮挡横幅仍视觉OPEN。
- e1fc之后已补、待新包：Boss源路点缓存（952源JS/生产Lua对照，120tick寻路120→2，leash分支0次）；Math3 QMul/RotateUnit保持算术分组的标量实现，删除每次11/6张临时表（2020286数值/8512041控制重放通过，不声称Web提速）；加载页真实绘制受击闪光shader，41预热/7加载生命周期通过，待GPU证据。三个Boss旧提示的lines已被b276删除，确认源不可达后没有迁入废案。g5继续查打捞遗漏，当前不重开G0、不提交上传。
- 用户仍要求继续缺失功能、暂不上传；本批无 commit/push。H5已再次实查仍为 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`，目标main/9541加本地增量。不重开G0。
- 已集成四项生产增量：root炮管远处掉件复用扫描（89专项/1924完整破坏对照PASS）；g2零件详情底padding滚动范围（139/108/5867离线PASS）；g4第五关盟友最近目标/攻击阶段/复活阶段（3079源JS/Lua）；g5无尽tierUp复合横幅与原壁钟到期规则（222项）。GPU测试串行、源核对/代码/离线检查并行。
- 当前普通4340/QA4341为 `manifest-b2399110.json` / `.tmp/outgame-cached-1792083383263` / 481 Lua / 指纹 `8b05b30cb9e5827fc8f98ed183ce8a445374ba2f68404f4cd5db001634da7868`。独立481发布payload SHA、18报告73SHA无漂移；但实际破坏公开入口在工坊详情前崩溃，不能交付此包。
- b239真实破坏入口FAIL：`evidence/destruction-web-2026-10-15T16-58-09-658Z`，WorkshopCarousel:98 slides=nil，0断言/1实际Lua错误。旧mounted精选页在slides释放后仍渲染；legacy已补同步隐藏旧page（实际引擎renderWidgetTree38项、新旧对照复现旧失败；shop448/navigation1523通过），待新包真实重验，原失败保留。
- b239真实PC零件详情：`evidence/inventory-detail-web-2026-10-15T16-59-53-332Z`，18检查/6页面/运行错误0。root已看源/目标天元底部图，底部留白可达，右值靠滚动条仍有裁切/字体差异，G2视觉不签通过；legacy继续定位，20:9待验。
- b239无尽入口真实FAIL：`evidence/endless-banner-manifest-b2399110-2026-10-15T17-03-03-991Z`，ObjectiveRoute.path=nil，自动退回大厅；0检查/未跑到五波，人工结束工具浏览器的TargetClosed保留，帧数据缺失不编造。已修无尽对共享ObjectiveView的旧接口：显式Geometry与Begin初始化mesh/origin，不伪造竞技mode；实际模块47项通过。
- 当前新包普通4342/QA4343：`manifest-e266101a.json` / `.tmp/outgame-cached-1792084158158` / 481 Lua / 指纹 `34e77ebc8b4be87ba1254c33bc604d638e23ae375babffafdeb1313ba61be663`。独立481实际payload、21报告81SHA无漂移。收入工坊修复、Boss物理kneel（源JS/Lua2178项）和无尽Geometry修复；真实破坏路线正在此包执行，尚未通过。不冒用b239失败前后的结果。
- b23920:9零件详情已结束：`evidence/inventory-detail-web-2026-10-15T17-06-50-510Z`，18检查/6页面/运行错误0；root看源/目标天元底部，底行可达但字粗/断行/scrollbar仍不同，G2整体视觉OPEN。该页生产在e266未改，仍非e266同包完整回归。
- 下一步root公开破坏后交g5串行跑e266五波/暂停改装。g4另在补确证敌车中弹零件白闪与源连破副行样式，**不属于e266**。分数字体原映射已正确，不误换字体。性能严重FAIL、完整自然流程/真实账号/真机仍OPEN。不重开G0、不提交上传。
- e266首轮破坏工具在冷编译日志期间收到一条截断F8 JSON，工具将其当运行错误而提前停止；`evidence/destruction-web-2026-10-15T17-10-34-127Z`，0检查。无Lua异常，不归为生产崩溃。工具改为逐条保留`probeErrors`并重新索取完整只读状态，所有功能/破坏/性能断言保持原条件；同包第二轮已启动，若无法取得完整状态仍超时失败。
- e266第二轮公开破坏已完整结束：`evidence/destruction-web-2026-10-15T17-12-42-204Z`，17功能检查/运行错误0/probeErrors0；工坊详情原崩溃未复现，GT靶车209→158件后击杀，+300、kill_confirm1/score_tick10实际触发。root已查看击碎/击杀图。56次Flush最大20ms，含截图/探针的射击窗1092rAF中位33.32ms/P95约33.60ms/max50.20ms，0个>100ms；仅此路线阈值通过，不签稳定60帧/竞技或手机。g5现独占GPU跑e266五波，root等待后在含白闪的新包重验；新白闪观察probe已写但不在正在跑的4343服务中。
- e266无尽已进场，初始升起/保护两相/保护后恢复模型真实通过；首轮工具检查未绑定Node.enabledEffective失败，保留原报告，改为现有StaticModel.enabledEffective计数。第二轮`evidence/endless-banner-manifest-e266101a-2026-10-15T17-18-57-499Z`，7检查后实际Lua FAIL：Vehicle:WheelPose.suspension=nil。F2在Update外真实Flush销毁车，下一帧0物理步使CombatView事件尚未消费就渲染旧DriveView；QA触发路径与自然战斗必现不可混同。g5主修TrialSession渲染前事件同步，g4独立实际Tick联合复现，不在WheelPose吞错。4509rAF/max3869.61ms/184帧>100ms保留，最大在初始加载，细分stage另记。
- 已构建白闪候选 `manifest-971b2f95.json` / `.tmp/outgame-cached-1792084787150` / 482Lua / `b7df73ab4976b96b3d9ceaada73248acc622a4c210cbf6e30fc2609ffd6fed12`，普通4344/QA4345，probe1518979345d729bc78d981c316032490974d5019d297b0d9bab7511fee6c6c6a。独立23报告93SHA/482payload无漂移；含源敌车白闪/盾蓝闪/连破副行，850源对照+默认恢复10组通过。此候选仍有上述TrialSession旧生命周期问题，未跑Web、不交付；等修复下一包。额外旧damage-before全对象质量相等夹具FAIL是跨质量合盒基线，原失败保留并归因，不悄悄改哈希。

### 上批已收口结果（d966）

- 用户要求继续迁移功能、暂不上传。本批无 commit/push。固定H5实查 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`，目标 `main / 9541dc59ef2f281cafa5126762a57550189e04dc` 加本地未提交增量。不重开G0。
- 当前服务最终包 `manifest-d966b4f2.json` / `.tmp/outgame-cached-1792082498209` / 479 Lua / 指纹 `a826acb9a277fbfde7c6cb12c966b8e46b7b2ba97262be6852c5737cb702110f`。普通4338、QA4337均实查此包；479实际发布Lua逐SHA匹配，13份报告63条SHA无漂移。
- 最终包实际PC/Android UA的20:9涂装手势：`evidence/livery-gestures-manifest-d966b4f2-2026-10-15T16-43-59-243Z`，19项PASS，运行错误0。公开入口、PC滚轮/左拖、实际双contact pinch/pan、取消后单指旋转、贴纸数据与history不变、完成返回大厅。root查看PC与横屏pan截图；不签整体视觉1:1或真机持续性能。
- 上一固定41e包的重地图两轮取消恢复15PASS及竞技三次完整进场/error0已结束，倒数/退出确认10项/观战/MVP/实际再队列新阵容通过，本次未复现第三次OOM。其后d966只改Mission护送死亡目标与LiveryControls，**没有把41e全流程冒签为d966同包完整回归**。相关公共加载/竞技文件逐SHA未改；d966护送源JS/Lua128项、涂装8195项均通过。
- 本批还补无尽初始/复活/改装出生升起和保护闪烁（497+22离线，真实Web三入口仍待验）、XML去重复DOM、Web机库提前释放/取消恢复、实际加载UI root保活、工坊购车/导航、竞技反馈等。详情 `FEATURE_BATCH_2026_10_16.md` 与各专项报告。
- **仍未关闭**：严重战斗性能（41e首局窗口p50/P95 62.670/118.315ms、首次加载max4701.620ms）、G1物理手感、G2字形/断行/布局、完整自然剧情/无尽/打捞、真实账号/编辑器、20:9手机持续性能。下一批继续这些缺口并实测定位卡顿，不能只重跑离线数量；G5 tierUp横幅未消费已确证但未改，按原规则补。旧失败证据保留。
- 本批工具浏览器均已结束；仅保留本地普通/QA服务。下一次先核此处包身份和最新源码差异，再继续原G0-G6，禁止重新从G0审计。

## 本批历史检查点

以下是执行过程当时的状态，已由上方唯一接续点覆盖；保留用于追溯失败和中间包，不当作当前服务状态。

当前运行已收口：41e4025e 同包两轮取消15PASS/error0；竞技 `combat-performance-2026-10-15T16-33-58-904Z` 三次进场完整结束、错误0，10项退出/暂停检查及倒数、A/D观战、MVP、真实结果再匹配/新阵容通过，本次未复现第三次scene .55 OOM。最终11943 rAF/263内存样本；WASM 1640MiB只是容量。严重性能FAIL继续：首局match-live标记p50/P95 62.670/118.315ms，首次加载max4701.620ms，后两局没有独立live标记，不能编造。root已查看倒数/观战/结果与取消图；未签自然整局/视觉1:1/真机。详见 `FEATURE_BATCH_2026_10_16.md`。后续G4护送128项与涂装手势增量尚未入41e，最终包将另记，不上传、不重开G0。

当前真实进度：41e4025e 两轮公开匹配加载后 Escape 完整恢复已通过，15项PASS、运行错误0；旧厅释放后加载页真实呈现帧继续增长，加载/恢复截图非空且root已查看，车辆名/零件数不变，transition归idle。证据 `evidence/map-cancel-manifest-41e4025e-2026-10-15T16-31-59-783Z`。随后同包竞技串行测试 `combat-performance-2026-10-15T16-33-58-904Z`：首局真实3秒倒数已截图，退出/暂停/取消10项通过并已回厅，第二/第三进场仍在跑。首局阶段p50/P95约62.67/118.315ms、进场最大4701.62ms，严重性能FAIL保留，未签流畅/自然整局。生产另补G4第二关死亡期truck目标继续驱动，128项源JS/Lua通过，尚未收入41e包；legacy正补涂装双指背景手势。当前不上传，不重开G0。

最新候选独立包审计：`manifest-41e4025e.json` / `.tmp/outgame-cached-1792081852213` / 479 Lua / 指纹 `6aa95b260594bd840d6aa3a5ded4680c3679d0f449d977e5229ed6026964988a`。全部479实际payload逐SHA一致，13份夹具63条SHA经原工具重跑0漂移；实际UI root生命周期13项、切场122项、冻结H5出生呈现228情形/生产Lua497项PASS。含root保活和无尽出生呈现，均是离线/包证据，真实取消恢复与多次进出仍待同包实测；旧b932黑屏、OOM和严重性能FAIL保留。详见 `SNAPSHOT_41E4025E_INDEPENDENT_AUDIT.md`，不重开G0。

最新运行结论覆盖下条待验状态：**b932b9cd 释放后取消真实 FAIL，不交付**。旧机库 HUD 清根导致实际 `UI.Render` 早退，LoadingPage 无法呈现，恢复 boot `pageFrames=0` 死锁；原 report/黑屏图/ROOT_CAUSE 保留。g4 后续工作区 `HangarApp ee1177c4…ef496` 已补非交互轻根，独立实际 Render/晚到旧 BuildHud 释放/DriveHud 与恢复 GarageHud root 接管 **13 项 PASS**，主切场 **122 项 PASS**，原生绘图仍替身。修复不在 b932，等统一新包真实取消恢复，不从 G0 重开；详见 `SNAPSHOT_B932B9CD_INDEPENDENT_AUDIT.md` 增补。

最新运行结论：b932b9cd 的真实取消测试 FAIL，`evidence/map-cancel-manifest-b932b9cd-2026-10-15T16-25-26-606Z`。旧厅释放后实际截图全黑；Escape 后恢复大厅 boot pageFrames 持续为0，非 Lua 异常。根因 GarageHud.Dispose 清 UI root，实际 UI.Render 在 root=nil 时提前返回，独立 overlay 也不绘制。确认死锁后仅停止该工具自有 Chrome，report 的 TargetClosed 是人工结束已知失败，不是引擎崩溃。g4 已补 ReleaseMapHangar 的无输入轻量根，实际 UI.SetRoot/Render 联测10项、生命周期122项通过；修复不在b932包，等待新包真Web。无尽出生呈现另一路补齐中；不上传、不重开G0。

最新独立审计包：`manifest-b932b9cd.json` / `.tmp/outgame-cached-1792081345365` / 478 Lua / 指纹 `b4b4b349d6a7635a6b610f245510ebaa139bb58d927ab45f4bd54b7db03dc53b`。478 个源码/快照/manifest/实际发布 payload SHA 一致，13 份夹具的 63 条文件 SHA 经原工具实际重跑后无漂移；切场生命周期实际 Lua 114 项通过，恢复 Install 使用替身。真实三次进出、释放后取消/失败恢复、OOM与性能仍待同包验证，原 FAIL 保留。详见 `SNAPSHOT_B932B9CD_INDEPENDENT_AUDIT.md`；继续既有 G0-G6，不从 G0 重开。

恢复工作先读本文件，再读总计划和各并发任务的进度文档。不要重复从 G0 开始。

## 固定基线与运行包

### 接续功能批：9541 之后，禁止上传

- 10/16接续仍按10/15 b276064源并行推进，不重开G0。592c工坊实际Web最终33项PASS、错误0：五车detail/dialog/取消、余额不足、真实roach扣3852并新增一车回打捞garage，截图已查看。证据`workshop-shop-web-manifest-592c0077-2026-10-15T16-10-30-580Z`；旧16:06轮是工具选中背景同名按钮导致FAIL，保留原证据。新增GarageHud空底盘入口9项、Workshop独立精选/详情选择1523项；这些后续代码不属于592c Web证据。新增MatchFeedback补源3/2/1准备倒数、受击节流/双呈现帧后半秒淡出和决胜维修提示，实际冻结JS/生产Lua666项通过；红边用共享VG渐变近似CSS阴影，不签像素1:1。SceneLoader去XMLFile重复DOM132项PASS；Web旧机库提前释放/失败恢复正并行实现。统一新包及真实重入测试待本批收口，旧OOM和严重性能FAIL继续保留。

- 本批统一本地production最终候选：`manifest-592c0077.json`，`.tmp/outgame-cached-1792079497205`，475 Lua，指纹 `5737484dffb732dc31816e8fe5aa57ff4a5890a0b0893251ea5789859f66c2d6`。普通4338、QA4337。独立逐SHA475/475、13份夹具63条SHA、12条录音/registry/两份交易JSON及AI接线PASS。竞技 `combat-performance-2026-10-15T15-52-54-887Z` 已结束，10项菜单/确认/暂停通过、退出games只加1、第二局QA毁核心后的A/D观战及MVP真实准备/跳过/结束/结果按钮通过，实际截图已查看。点击再来一局确实回厅并进入新queue，但第三次scene加载asyncProgress=.55时Aborted(OOM)，完整再匹配FAIL；新阵容/重入成功未签。两次退场array/image/retiredTargets归零、模型16.31MB，不能直接归因为漏卸载；具体WASM heap/解码峰值待测。崩溃后无最终rAF，report.frames为空，不编造本包帧率。打捞工坊首轮仅探针不完整JSON导致工具FAIL/0项，原记录保留，修工具后待重验。严重性能FAIL和自然路线OPEN不变。
- 统一包校验先后拒绝071896f2（构建后GarageHud新增防半成品异常保护未入包）、a9f40cb6（拷贝到已从生产删除的临时_hudfail.lua）。前者475 Lua中1项漂移，后者多1个故障脚本；保留独立FAIL证据，a9f仅boot测试即中止，不算正式运行验收。已停本轮三个旧服务器，再复用4337/4338，只服务干净592c0077。没有回退或删除并发生产修改。
- 接续本批仍做功能，无 push/commit。打捞结果净货物/通行票与重试一致性（29项）、Boss源结果统计（14656项）、结算语音时序/真实12条原录音（1392项）、竞技AI选敌/缓存/三模式战术（1329项）均离线PASS并冻结。打捞工坊购车钱包/价格/不足余额正在收口；额外定位rat/roach装饰壳漏交易派生数据，购买Rows会nil崩溃，正按冻结源补齐。以上新增尚未进入8d1859cd，不能套旧包Web结果。
- 8d1859cd第三轮真实Web：10项竞技动作PASS、运行错误0，确认退出只记一次败局，实际摧毁核心后A/D观战及姓名画面通过。整体FAIL仍保留：工具在MVP下载准备期间对空widgets调用some失败，已修工具等待真实准备完成/两次Space；结果/重新匹配待统一新包复验。证据 `combat-performance-2026-10-15T15-33-27-812Z`；live p50/P95 76.200/138.795ms、进场max5027.680ms，严重性能仍FAIL，不签自然整局。

- 用户最新指令是继续缺失功能、暂时不上传。沿用 10/15 `b276064942ae09c0227ec28d4cfda1d5ff006455` 和现有 G0-G6，不重启 G0；本批没有 GitHub push。
- root 补竞技 Tab 按次切换、死亡 A/D/左右键观战、源 16m/7m 跟随、观战姓名/复活提示；退出按钮/统一设置/触屏菜单共用原文确认和幂等败局记录；T 不再绕过竞技流程；“再来一局”经返回释放旧世界后走真实匹配队列。Lua 5.4 103 项通过，真实网页流程待本批新包。
- g2 已冻结 InventoryDetail/Layout/Panel/Chrome、TouchMode，5867 项数据字体与 108 项布局设备检查通过；PC/20:9 实际画面对照待新包，Web 初始触屏设备识别尚需观察，不能冒签移动端。
- g5 已冻结 Edit/EndlessEditBar 与 Run/RunRules/SalvageLootMotion，92 项 Lua 检查通过；购买自动快捷栏、完整编辑瞬态复位、源商店 min210 排列、满仓换货/过滤阻塞交互、拾取重量镜头反馈和错峰飞入已接。root 已接触屏消费字段及竞技退出确认。实际无尽/打捞新流程仍待运行验收。
- g4 本批补 IntroBattle AI reset/flip/salvo 和源触屏教程文案/对白选择；冻结及测试见 G4_OPENING_PROGRESS。所有离线结果仅签对应功能契约，严重战斗帧率、全流程自然游玩与真机持续性能仍未关闭。下一步是同一不可变新包的真实按钮/输入/退出/重新匹配及 PC/20:9 对照，不再重新审计 G0。
- 功能批首个包 `2c911f96`（471 Lua，`ed0a5b9c0e3c939503464de69722ac046cc48ff833aa613c78aa38b7da04f77d`）实际 Web：Tab 开/关、T 禁退通过，错误 0；首个退出点击未打开确认，鼠标仍居中且浏览器锁未释放，整体 FAIL 保留在 `MATCH_ACTIONS_2026_10_15.md`。复验工具等待实际 DOM 解锁，不改断言或生产放行。严重帧率和进场冻结仍 FAIL。
- 后续新增两项已冻结：普通剧情 Enter 跳通讯、同评价更快通关显示新纪录。执行实际冻结 JS 与 Lua 260 项通过，证据 `evidence/story-input-progress-offline.json`。最新统一本地包为 `manifest-8d1859cd.json` / `.tmp/outgame-cached-1792077640108` / 471 Lua / `9e1a18222db2cac415191d526ff22d3b4f2f6941262b239f6426b98a54e6a34d`。普通 4336、QA 4335；2c911f96 的旧结果不挂到本包。下一次接续先查看此条及随后追加的运行结果。
- 8d1859cd 零件库真实 Web 已完成：30 项功能检查、14 页状态、28 张配对截图，运行错误 0，root 和 g2 均已查看 PC/20:9 天元底部。Android UA 实测 `native=Android, compact=true`、逻辑 1333.333×600；保留的桌面 UA 触屏模拟 `native=Windows, compact=false`、逻辑 2400×1080，与 H5 coarse 检测不一致，明确 OPEN。字形 ink、长参数断行、滚动起点约14px与可见滚动条仍有差异，不签整体1:1；不是“都通过”。报告 `evidence/inventory-detail-web-2026-10-15T15-22-48-164Z/report.json`。
- G5 的 2c911f96 最小 native 验证在首次机库 shader 编译 frame752 被255秒外层截止，0项G5运行断言、没有PNG/validation；已退出并保留 timeout.json、stderr（既存DDS/themis启动错误）。不能把92项离线PASS升级成native/Web已验，也不重复冷启动占窗口。8d1859cd竞技动作的第二轮实际Web正在串行执行。

### 最新整理增量：接续 d6fcf0de

- 按用户“整理成最新版本、干净一些”的要求收口本批，不扩展新功能。本地最终检出 `main`，与 `codex/h5-2026-10-15` 和私有 GitHub 两个同名分支同步；当前源码以 Git HEAD 为准。H5 最新分支再次实查仍为 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`。旧无父交接分支没有合入。
- 新收入逐事件鼠标尖峰过滤和 Space 无 vehicle owner 空扫描跳过；root 重跑实际 Lua 5.4 分别 8757/8757、85132/85132。只签离线行为，尚未实际 native/Web/真机验收。本批没有新运行包，4331/4332 的 d7af 均不包含这两项，不可用旧包结果签新代码。
- 七份当前 CPU profile 的分类报告和原始聚合已整理。稳定战斗主要落在未符号 WASM，不能直接说是 shader 等待。32/64 米散布分组实测改变组中心距离语义，明确拒绝生产接入；最终 native validator 未产出，整体不签通过。完整实验记录保留，不继续新实验。
- 上批零件详情 Web 会话 70055 已正常完成：22项检查、12个源/目标页面状态、运行错误0。已查看 PC 天元钻头与20:9夫元钻头四张配对底部图，发现 PC 断行和20:9布局比例仍不一致；G2视觉未关闭。本批只整理证据，没有凭数据一致签页面1:1。
- 精选本批报告与四张配对截图归档 `verification/2026-10-15/`。下一迁移工作继续现有 G1/G2/性能待办，先统一新包验证鼠标/物理增量；不从G0重启，不把仓库干净当迁移完成。

### d6fcf0de 整理时的运行包

- 当前开发分支已切到 `codex/h5-2026-10-15`，对齐 H5 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`。按用户最新要求整理当前完整开发成果并同步私有 GitHub 的开发分支与 `main`，不合回旧无父交接快照。具体包含内容和验收边界见 `LATEST_VERSION_2026_10_15.md`；整理提交以本分支 Git HEAD 为准。旧 706d 分支只保留性能复现用途。
- 最新实测包 `manifest-d7af571f.json`，`.tmp/outgame-cached-1792074566364`，467 Lua 逐 SHA 匹配，指纹 `99ac8e3ba04b01496c10f33175ce2bed8bbe724ea971f331cd2ec74ec2b3a04d`。普通预览 4331、QA 4330。两次公开菜单实际匹配/驾驶/射击/瞄准/退出完成，运行错误 0，右键 8/8、会话/小地图生命周期 4/4，退出后自有渲染目标 0；两次局内及返厅截图已查看，小地图有实际场景。性能仍 FAIL：首局 live p50/P95 110.990/139.170ms，二局 117.805/145.785ms；首次加载最长 4708.205ms。原始报告与 CPU profiles 精选收录 `verification/2026-10-15/`。包身份中的 targetCommit 为整理前父提交 ad72080，具体脚本以逐 SHA 和指纹确认，不能误说测的是未改的父提交。
- 本批已收入 shell 材质共享/所有权释放（native 413/413，性能 FAIL）、MapShot 下载取消/兼容及真实底图 rebake（103/103，图片字节未改）、331 零件详情/钻头行/数字字体（离线 5867/5867）、源狙击伤害/穿甲/溅射数据及 Beam 事件字段（native 3729/3729，性能 FAIL）。散布细分仍只是 QA 实验，未改生产地图、未做实际配对渲染，不算优化通过。
- 仓库整理已排除 SDK/cache/临时包/用户存档/批量历史截图和可重建 source fixtures，均保留本机原文件；保留当前精选实测材料。G0-G6 继续原进度，严重战斗帧率、冷加载、整体视觉/手感、完整自然剧情/无尽/打捞、真实账号/编辑器与手机持续性能仍未关闭。下一性能工作沿实际 CPU profiles 与散布剔除实验推进，不从 G0 重启。

## 历史执行记录

以下记录描述各次更新当时的分支、运行包和待办，不代表当前分支状态；最新状态以上方和 `LATEST_VERSION_2026_10_15.md` 为准。

- 本轮继续原G0-G6，不从G0重启。已实查分支区别：H5当前`2026-10-15 / b276064`，迁移基线一致；UrhoX本地仍`codex/h5-2026-10-14 / ad72080`且大量迁移尚未提交，私有交接`5e45931`为独立ref，GitHub默认仍main，不可说本地已切新分支。下一候选待统一构建：ShellMaterials第三次真实native413/413功能PASS/22租约归零/可见模型18PNG，338个>100ms尖峰使整体仍FAIL（零Lua/resource，stderr既存DDS/themis另列）；MapShot生命周期103/103及真实rebake4/4PASS，1146输入check通过，图像字节不变；G2正补InventoryDetail钻头专属行与tabular数字字体。root新增QA-only弱引用资源所有权观察及公开输入重复匹配进出，待新包验证，当前普通4329仍706d。g5仅制作静态散布细分剔除实验，不改生产地图或烘焙输入；legacy只拥有InventoryDetail及新Rows模块。生产全程GPU测试串行，离线工具并行。
- GitHub私有交接已完成并经API复核：`https://github.com/Rinorsi-xd/vox-urhox/tree/codex/engine-handoff-2026-10-15-706d`，commit `5e45931519fab260f0a93f7aa5c2dd11e7131109`，仓库仍private。无父独立快照15758文件（含自身外的15757输入清单），runtime严格来自706d固定包；仅明确工具/文档和约1GB运行资源，排除27份约123MB可重建fixture与本机SDK/cache/saves。隔离GIT_INDEX_FILE建提交，未切当前`codex/h5-2026-10-14`/未覆盖本地工作区。入口`docs/migration/ENGINE_TEAM_HANDOFF_2026_10_15.md`含实测性能失败及原始CPU profiles。用户可将该分支给引擎部，未代发消息或开PR。后续三路仍继续：g4 shell材质native夹具（生产候选已冻结，不属706d）；g5修MapShot取消/兼容+重新烘焙；legacy查真实字体队列去重。未签完整G0-G6。
- 当前用户新增授权上传GitHub私有仓库给引擎部；已实查`Rinorsi-xd/vox-urhox`为private且有ADMIN。准备单独交接分支，只取真实测过的706d快照runtime，不混入后续shell材质候选；附源码资源/精确构建/CPU profiles/原始失败报告，不上传凭证、SDK、.tmp或用户存档。706d普通4329/QA4328，`.tmp/outgame-cached-1792072535275`，指纹`2bfcec5e7a9851ca7da857a59f0f70b999c41b25a3b5c8fa8b405e3cd8eb1fda`，465 Lua逐SHA一致。真实匹配`13-56-49-208Z`错误0/右键4项PASS，但live中位111ms、P95 145.965ms、max215.405ms，进场max5104.195ms，整体性能FAIL。真实破坏`14-01-57-237Z`17项PASS、55 Flush max27ms、射击945帧max69.69ms且>100=0；只签射击窗口，boot/practice-loading仍FAIL。底图captured/ready而无RT views/captureFrame，与baked分支一致；后续新增代码不得套该结果。root负责私有分支推送与精确交接，三个agent继续独立工具/首启资源/审查。
- 本次并发继续推进，未重开G0：g4首发尖峰定位到实际同帧首次Stencil/实例点光shader编译，CombatWarmup新增加载期有界临时探针，22离线场景PASS，待新包Web；g5已烘焙真实陨坑静态底图，1145输入校验PASS，缺失/过期回退41/41，离线原生烘焙本身整体性能FAIL保留；legacy无用地面查询140793前后断言+23455 H5黄金PASS，并续做Nav边索引精确等价。root真实45声音分帧解码与构造复用140/140原生PASS、错误0，最大解码分片5ms、缓存构造1ms；仅签孤立native，不签Web/手机。上述增量均不属于普通4327的04a包，当前下一步固定统一新包实际加载/首发/破坏与小地图复验。
- 用户要求继续多线程，当前三路已重新派发并实际推进：g4已结束04a公开鼠标射击/拆件/击杀Web，继续分类可选引擎包404与首发138ms尖峰；g5接地图离线真实烘焙/元数据/过期fallback，当前独占native；legacy基于实际CPU证据优化EnemyDriver无用地面射线，离线逐步等价核对。root音效资源预解码分帧已落scripts/audio/SoundPreparation.lua，TrialSession音频段接线，Lua5.4分帧/去重/取消/错误检查通过，新包真实时间待测。普通4327仍固定04a，不随工作区新增改动漂移。
- 04a HUD专项实际完成：PC1920×1080与20:9 touch840×378各5/5状态检查、运行错误0，两张全图和crop均已查看：比分/000分离、N在上、凹箭头完整、真实底图建筑道路清晰、无边沿拉伸。独立视觉结论`evidence/hud-04a23389-visual-review.json`，原工具report的PENDING不冒写成程序像素断言。只签本次重叠与缺地图，不签全UI/性能/真机。
- 最新运行包已前进04a23389：普通4327（同包无探针）、QA4326，`.tmp/outgame-cached-1792071037109`，脚本`ee0e9dfe08f03dc62cacfd80f40386a546386e4ee0ccfe7d114393bf01a90af6`，QA只读探针`2ad919eab0ac1716f903611a350f21a1c1af498b2cc82714633d434d247b5d09`，两端identity实查一致。9e05的实际PC已成功进场/HUD5项状态PASS/errors0，截图确认比分与罗盘分离、地图有真实地形；仍发现Web重复翻转使N在底部、map imagePattern填满RT导致边沿拉伸。04a窄改MatchMinimap为无额外Web翻转、底图仅画投影矩形（与源drawImage一致，不额外铺背景），SHA862542d0...da35c5e，PC后20:9最终Web复验中。g4已准备真实试车射击/拆件/击杀回归，等待root完成两个HUD浏览器后独占4326，不并行争运行资源。
- 最新Web修复候选QA4324：`manifest-9e05de29.json` / `.tmp/outgame-cached-1792070723091` / `a6210aa2e2eaf6a3ce87162e5de8f3a9bf09102f0062d30b0e0c54e8881970fd`。3a0真实PC加载在minimap超时，证据13-14-15；同生产只读诊断13-20-53证明Begin/End事件camera与texture各67次完全匹配，但生产views仍nil，协程注册回调未执行。候选改main.Start主线程Initialize、Stop中Shutdown（main a9737c4f，MapShot60c6a345），QA移除额外事件订阅只保留New/state观察，避免干扰。第二次完整Web进场正在实测，不能拿旧native结果签新Web已修；前两包均不交付。
- HUD最终候选已固定：QA4320，`manifest-3a0f7886.json` / `.tmp/outgame-cached-1792070001444` / `a9fbf3d87c6796f0cccfc9692910f234a5a473e4449cc686a31c53b36085f28f`。MapShot最终`c218a41d...b66f1ba`、Minimap`42e75518...24a4baa`、TrialSession/BattleController/TurretRange/CombatView/VehicleView/ReticleGauges共8生产文件逐SHA匹配，收入10/15三车/20零件/品牌和质量合并约束。MapShot最终实际native33/33功能PASS、clip像素27/27PASS；PNG保存帧110.197ms使最终native整体仍FAIL。PC与20:9真实Web专项正进行，未冒签小地图实际网页内容；状态probe的base/frames不作为像素验收。3143781b为尚含错误Octree指针转换的中间候选，未进入浏览器且已停服务，禁止交付。
- 续接HUD/小地图专项：10/15基线已激活为`2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`，冻结输入2168项已核SHA。竞技罗盘漏原版向下100px位移已补；离屏NanoVG无stencil导致底色/凹箭头失效，改源形状alpha遮罩与两个凸三角。MapShot旧runtime必须关闭`fogStart/fogEnd/fogDensity/heightFog`；四块场景实际捕获已有布局，但新查到陨坑drawDistance150/220米会被1200米相机裁掉，g5补仅捕获视图覆盖和恢复。中间包`697eafb4`/`.tmp/outgame-cached-1792069804300`/`836d9a619bda2a4e99842bb31c6d47b1ddf028f124a09f9b23a5341a027d6908`尚缺距离修正，QA4320暂为中间候选，不作修好交付。
- 破坏专项更新：实际native证据`evidence/damage-native-timing-2026-10-15T13-05-13-104Z`，152/152断言通过，Lua/资源错误0。精确TurretRange样本缓存使MEGA三次存活拆件224/320/225ms→43/43/50ms；死亡静态视觉按零件身份转移，最新Consume28/29ms、动作总计42/44ms。1924项等价检查通过，初次构造多约100–200ms，加载仍需分帧。整体仍FAIL：63条整帧>100ms，不能签Web/手机或全战斗帧率；下一步同一最新包真实鼠标射击/击杀回归。
- 接续最新用户HUD截图：不重开G0。已确认顶部`000`为竞技罗盘，漏源`100px * --mh-ui`位移；g5已补。小地图实际RT像素证明原圆形hole/凹箭头在离屏无stencil时擦掉底色、箭头变方块，显式排序无效；g5改凸形遮罩/两三角箭头并接真实地图一次捕获。root已备实际公开匹配PC/20:9专项，等待统一新包；旧4319不含修正，不得报已修。10/15源HEAD已实查为`b276064942ae09c0227ec28d4cfda1d5ff006455`，三车/20零件/fox/品牌增量已落，基线激活和地图实际Web待收口。
- 击碎卡顿并线实际native分段已完成：`evidence/damage-native-timing-2026-10-15T12-48-18-043Z`，136项非性能断言通过、6动作超过100ms，整体FAIL；MEGA存活Flush216–304ms，死亡Consume250–302ms。g4负责TurretRange/Flush等价缓存，legacy负责死亡碎片显示复用；不能拿离线缓存命中或功能通过签真实性能。
- 当前破坏/击杀候选：QA4319，`manifest-8c7a8107.json` / `.tmp/outgame-cached-1792067264260` / `46b9302eb76556c5fcef3480883efac09337342b64d437f43cbf099bd2228029`。已逐hash核对伤车四模块、EffectBatch/JoinedMesh、TrialSession、击杀音频与HUD。收入邻接/炮管局部缓存、复用连通分析、空FX延迟native初始化、顶点颜色缓存、真实击杀定格/慢放/FOV/音效、积分22碎块与连杀、击杀列表/占点标记/小地图。小地图仍fallback底色，MatchMapShot未接线。legacy正在写公开输入真实击碎/击杀Web测试，g4写真实native重建/渲染分段计时，root统一串行实测，禁止把离线等价当性能PASS。
- 前包c346cd29（QA4318）真实Web已完成：错误0，右键短按入/出与长按松开退出4/4 PASS，scope及PAUSED截图已实际查看。性能仍FAIL：live p50 104.145ms/P95 131.99ms/max201.045ms，loading max5152.69ms；focus=true、minimized=false、maxFps60，不能归因失焦10fps限制。证据 `evidence/combat-performance-2026-10-15T12-24-22-048Z`。此前0b包因MatchBanner错误绑定GetSystemTime而FAIL，已按Time:GetSystemTime修正并在c346实际通过，不覆盖旧失败。
- 真实native深度像素检查5/5 PASS：普通Glow被墙正确遮挡，源ObjectiveOverlay刻意透视仍显示；仅签native该材质，不签Web或所有特效。34个100ms尖峰仍性能FAIL（隐藏native窗口10fps限制，max489.99ms），证据 `.tmp/effect-depth.json` 与out/err日志。地图尚无地理流式卸载/软件遮挡实施，不冒称已做。
- 10月15日最新并线：普通待启、QA4317（无细粒度CPU探针）固定 `manifest-0b4790c3.json` / `.tmp/outgame-cached-1792066463328` / `53c8fb04cd902b99b577fff2a3b0698c4521a493009760e79e9070767cf5deae`。含机械腿精确IK复用、真实会话FX预热、剧情刷兵规格预计算、PC Web 60帧上限修正、右键真实事件边沿/250ms、相机车辆遮挡桥、移除竞技全屏暂停黑罩/源横幅，以及源射击FX首批。root补占点3米墙、源水平距离淡出、overlay/volume拆批、橙色3+2米虚线与检查点柱，11项实际Lua几何检查PASS。新包真实Web性能/右键正在测，不能标修好。
- 前候选5e477668真实性能FAIL：细探针匹配live中位90.085ms/P95 132.035ms，关闭细探针同包仍104.13/145.94ms，错误0；两次随机阵容/机器运行差异不支持严格归因。第二次已真实captured但仍卡。证据11-56-32-513Z与12-05-42-944Z。不能用百万离线等价断言宣称性能已改善。剧情S3短路线仅parley、敌人0，不能签AI压力。
- 当前三个子agent续做：legacy已冻结右键/相机并接管掉件Flush/邻接图/炮塔射界缓存；g4已冻结射击FX并补击杀音效/碎块真实事件链；g5已冻结横幅并补积分/击杀播报、占点/推车UI、小地图。root统一构建/单浏览器实测。0b包已固定，各后续增量不得冒挂0b证据。
- 10月15日性能专项接续：不重开G0。最新UI包为 `manifest-b24c5ecb.json` / `.tmp/outgame-cached-1792063134142` / 指纹 `0ad8074d316775c6ed10abe2a811b156b23587ded7d7c2fccd471c6140a49579`，普通4311、QA4312；开篇长句三比例6/6与20:9 S5页面11/11实际Web通过，错误0，仅签专项。用户严重卡顿升级为当前优先事项：独占4313同生产包测量，第一轮匹配live rAF中位50.035ms、P95 83.405ms，进场最长3903.02ms，仍性能FAIL。首轮Lua构造函数计时包含coroutine挂起，不得把其总跨度当单次CPU冻结；已补扣除挂起的探针并重测。现场未见旧大厅在对局后台更新，整图驻留不等于地图流式加载。详细账本 `COMBAT_PERFORMANCE_PROGRESS.md`。
- 未构建性能增量：root修加载期间旧trial PostUpdate与开篇graphics重复更新；g5保留AI静态路网缓存并做物理步内精确读取缓存；g4补真实会话特效池预热；legacy做独立生命周期与加载热点复核。新包实测前不标解决，不更改100ms失败阈值。
- 当前UI/开篇/设置统一候选普通4308（PID45988）/QA4309（PID49020）：`manifest-264a138b.json`，`.tmp/outgame-cached-1792062486110`，脚本指纹 `7a31c714de0dfaa6147cdbe65152b8f5e4ab0a40a53b943146fded6fef62a356`，两端identity已实查，QA探针 `9f940873088c61ddc7ec1498aea1b91541b23abd7586e2116c2bc5ffde54b34b`。收入LA12–15、恢复FX、LB01–03、武器图标门禁、模式/匹配/剧情页面、S5精确派生全息、开篇独立漫画clock/原对话/纹理及统一设置。新包真实Web分三路并行：root设置与三Esc，legacy页面/匹配，g4自然开篇PC/20:9/1605×388。结果未回前不冒签画面或性能；e1faa514以下保留为历史证据。
- 最新增量候选普通4306（PID49676）/QA4307（PID42984）：`manifest-e1faa514.json`，`.tmp/outgame-cached-1792058408682`，脚本指纹 `11c223a54d66f2d77161e9134cd385494dc600c81926526a3aaa36dd0a270a15`；两端identity已实查，QA探针仍 `9f940873088c61ddc7ec1498aea1b91541b23abd7586e2116c2bc5ffde54b34b`。逐文件比较561，唯一脚本差异是 `ui/ResetProgress.lua`，无删除；修原body层CSS固定像素在UI.Scale .7被缩小。原生42/42、错误0、两比例图已查看；最终实际20:9 T→tap→R→取消6/6 PASS、运行错误0，证据 `evidence/practice-web-manifest-e1faa514-2026-10-15T10-01-08-429Z`，root与g5均打开最终840×378图确认固定像素生效。561已通过的完整输入矩阵仍只记在561，不改挂新包。自然倒翻触屏、狭窄空间及真机性能仍OPEN。
- 最新普通4304（PID41360）/QA4305（PID23752）：`manifest-561eef79.json`，`.tmp/outgame-cached-1792057687135`，脚本指纹 `d8ce9ddb44253bd039e60e4ee33941bb30d6dfdbc8c41881a03b363a32023165`，QA探针 `9f940873088c61ddc7ec1498aea1b91541b23abd7586e2116c2bc5ffde54b34b`，两端已实查identity。收入LA01/02/03–09/11候选、打捞依赖修正、字体14项增量和帮助wheel根路由。新包真实Web R/HUD/help三路功能验收正在进行，不冒签性能。中间0e775676（4300/4302）缺最终Scope坐标纠正、compact比例与help根路由，保留为未验中间候选，不作最终交付。
- 历史H5基线：`2026-10-14 / 2b169a9964645f5f346a7158bcb14447f040814a`；当前已切换上方10/15 b276，旧验收结果仍只属于旧包。
- 历史源快照：`.tmp/outgame-source-2026-10-14T10-09-50-505Z`已保留；当前以 `outgame-baseline.json` 中10/15 snapshot与哈希核对资源。
- 目标：`codex/h5-2026-10-14`，已有未提交工作区保留。
- 当前普通预览4295（PID3144）、QA4296（PID50408）：`manifest-11e3cbe9.json`，`.tmp/outgame-cached-1792053971537`，脚本指纹 `20a59fc6a04583dbc61910d3cf4125527e60b15df65e2f66f88da254d85c6c23`。两服务已实查 `/identity.json`；QA探针指纹 `2b32f2d79c1f598ced89883ffefe01f0dbdb6bb24b04e51879e0097aeac8c198`。收入2729全部内容及第二批准星/音乐字体、冻结帮助48条/整卡滚动、打捞工坊Update/键盘路由。新包真实Web验收进行中。
- 上一包普通4293/PID51780、QA4294/PID47684：`manifest-2729bc84.json`，`.tmp/outgame-cached-1792052961120`，脚本指纹 `cf3298c95984ca9f17bd7cec33345187763c015120ba690d44b72c93bdba1db6`，保留对应证据。含字体/DriveReadouts、TutorialPage实际touch目标、OpeningHost延迟释放及教程门禁、共享释放回调链、音乐图标路径缓存。
- 旧4289/PID46628、QA4290/PID48728仍为d6764c9c；g5已启动的自然打捞继续完成，证据明确旧包。QA4291/PID35384为同d676生产的downloadConcurrency=1受控实验，QA4292/PID48740为音频探针修正；均不代表当前2729普通包。
- 完整范围仍是总计划 G0-G6，138 个主验收项及后来发现的源功能；没有缩成比赛演示子集。

## 本批分工与下一步

### 当前四路并发检查点（继续实施，不重开G0）

- 264a本批统一设置真实Web已结束：PC18/18、20:9触屏14/14功能PASS，运行/探针错误0；root已查看两比例真实菜单PNG。实际三Esc经过PollKeys，依次释放/打开设置/关闭设置均不返厅；声音完成回设置、继续保留车辆通过。证据 `evidence/audio-settings-web-manifest-264a138b-2026-10-15T11-09-46-846Z`。依赖审计54/54与16项静态集成通过。g5独立查出开篇chunks字距丢失、完整句提前定框，g4将在保留264a三比例证据后精确补修；不因新包功能通过就签全部字体或1:1。
- 10月15日最新UI批继续原三位子agent：g4已冻结匹配页/开局横幅/顶部计分板首批，转修用户最新开篇截图；已证实IntroPromo每次Mark重置阶段age导致旧漫画格重复入场，按冻结源改每层独立clock，不能误改单图。IntroPage多余nametag、对白字体/按钮和分层亦逐项核对。legacy修StoryPage/Frame、实际预览语音及Outgame第五关ready/place/map旧数据；g5图标/真实Session专项冻结后接统一局内设置入口。root接资源门禁、模式入口颜色与最终统一包。新批未进入e1faa514，当前浏览器仍旧包，不冒签画面。
- 独立LB01–03已修：竞技8/80旧hover预制、Radio 10条语音与死池、两条随机名，701/701离线检查PASS，52源输入和116active WAV已核SHA，见LB01_03_DERIVED_SYNC_PROGRESS.md；未签新包实际对局/听音。WeaponIconResources真实Lua/ResourceGate/TrialSession恢复重建Dispose联合43/43功能PASS、Lua/resource0；303.132/1374.53/1414.8ms三尖峰整体FAIL且无viewport，非画面证据。root已接HangarApp与OpeningHost图标依赖，真实冷Web下载仍待。
- 用户再次要求独立检查旧版残留，已新建 `legacy_independent_v2`，只读生产代码/冻结源，不承担修复、不占运行窗口。独立报告 `LEGACY_INDEPENDENT_REAUDIT_2026_10_15.md`，新发现用LB编号，避免重复LA01–15。重点是剧情/自由探索/试车/三竞技实际入口、公共逻辑与派生数据，再查局外/建造/存档；区分旧版、遗漏、引擎映射差异和未证实。g4已完成LA13/14并冻结释放槽：最终1516/1516功能PASS、Lua/resource0，但3次100ms尖峰/max275.995ms仍整体FAIL，实际Web待统一包。root、legacy的LA12动态成员与g5恢复FX继续原有集成，不重开G0。
- 本批三路生产已冻结：LA12最终646/646功能PASS（含动态加入/移除单位标识），Lua/resource0，2个初始化尖峰仍总FAIL；LA13/14最终1516/1516同上；恢复FX44/44功能PASS、Lua/resource0，三张实际图已核对、光壳错位已修，261.779/970.869ms两尖峰仍总FAIL。root开篇PracticeSession→IntroBattle转移专项23/23功能PASS，Lua/resource0，5520.588/100.135/105.054ms尖峰仍FAIL，stderr默认Cube/Day贴图/themis初始化错误亦保留。均未进入e1faa514，不冒签Web或性能。独立复审首批已定位竞技预制车8/80和Radio派生差异，精确影响及验收以即将冻结的LB报告为准，不重复LA03复活规则。
- 新实施批已启动：g4独占ReticleTarget/新增ReticleFocus补LA13/14；legacy独占DriveOverlay/DriveFeedback/新增UnitMarkState补LA12；g5独占恢复FX/ReticleWeapons补实际恢复青光与掉件琥珀反馈；root负责LA15顺序及TrialSession/资源/生命周期接线。LA15原生753/753功能PASS、Lua/resource0，但15次100ms尖峰仍总FAIL，详见 `LA15_LAYER_AND_INTEGRATION_PROGRESS.md`；尚未进入e1faa514。原生窗口按g4→legacy→g5→root串行，代码/源核对并行。
- 源语义纠正：冻结combatFeedback.partLost是空函数，禁止迁回旧文字通知；实际源由武器槽琥珀闪烁替代。LA01审查备注已纠正，恢复青光与槽位完整动效仍待实现/验收。开篇替换阵容现清理旧PracticeSession/feedbackPlayer；UI导入工具已改冻结snapshot+8输入哈希只读预检PASS，无批量重导/来源标签改写。
- 独立复审已由legacy_audit收口，生产不改。报告共15个正式ID：首批11项保留，LA12普通头顶受击/低血状态（首批备注转正式）、LA13开镜focusPick挑选/保持、LA14目标信息牌arms/警告/低血、LA15 Scope/frame顺序。全部附精确源/目标证据与验收步骤，新增四项未实施；不冒称四项都是首次发现。g4确认20:9 RNG/EN几何冲突原版也存在，顺序差异另记，禁止借此自行移动原版位置。LA10导航已校正，派生来源风险仍保留。
- 561 HUD必要剧情复验已结束：PC13记录/12断言PASS、20:9触屏18记录/17断言PASS，运行错误0/gameHTTP失败0；真实step A、任务罗盘、机枪/狙击镜与返回释放均完成。证据 `evidence/hud-unification-web-2026-10-15T09-55-31-043Z/pc.json` 与 `20x9-touch.json`，root已查看横屏任务/无线电/触屏最终图。首轮boot阶段过早检查marker的失败原证据保留；不重跑已通过试车矩阵。浏览器均退出。全状态字体/样式、无线电与摇杆重叠、scope层叠和真机性能仍未签收；原生42项与功能浏览器并行，不能解释为独占性能证据。
- 561真实R最终PC10/10、20:9 touch11/11功能PASS、运行错误0，实际正常T/点击/R取消/重开/完成/4秒冷却/单玩家均通过；`evidence/practice-web-manifest-561eef79-2026-10-15T09-50-37-892Z/report.json`，两张进度图已由g5查看。发现20:9 ResetProgress常量随UI.Scale .7被缩小，源_resetBar在body外固定CSS像素；已授权仅该widget换算并补原生比例检查，其他生产继续冻结。自然倒翻触屏按钮未触发，仍OPEN。g4实际两比例试车/机枪/狙击scope已出图，PC剧情marker首次夹具在boot过早断言FAIL保留，等待自然阶段后复验必要剧情路线，不重做全矩阵。
- 561真实Web首批：root帮助页实际mouse.wheel(1600)经引擎-1600/no-hover根回退，scrollY 0→433.5，通过；help/help-bottom/settings/workshop截图已收，运行错误0，末条J/页脚图已打开，证据 `evidence/target-font-pages-manifest-561eef79-2026-10-15T09-49-07-610Z`。g5真实PC R10/10 PASS/错误0，已看真实读条PNG，20:9尚在验证；g4试车实际机枪/狙击scope已截图，root看过5.0x/RNG30M及无黑mask/公共HUD，剧情与20:9待回。以上不等于自然全部战斗/全字体像素一致或真机性能。
- 本批原生专项结果已收齐：LA01 33/33功能PASS、Lua/resource0，4尖峰仍总FAIL；LA02最终隔离39/39 PASS/错误0，真实读条PNG已查看，前两轮加载遮挡图不签通过；LA03–05竞技162/162功能PASS、2尖峰总FAIL；LA06–09/11最终752/752功能PASS、9尖峰max493.563ms总FAIL；字体增量14/14 PASS/错误0；帮助wheel根回退与生命周期29/29 PASS/错误0（首轮23/29夹具未制造no-hover已保留）。同包561真实浏览器功能验收正在进行。最新HUD记录已纠正Body.Wrap坐标误判并加真实非原点RNG5，0e775中间包不签收。
- 独立审查后续实施批：root LA01已接真实PracticeSession/CarUnit、合批PlayerViewSync及死亡触屏保护；首轮30/31捕获未接管鼠标掉图恢复失败，修到共享Tick后33/33功能PASS、Lua/resource0，100ms门限下4尖峰仍整体FAIL，证据与缺失恢复闪光/零件丢失提示详见 `LA01_PRACTICE_PLAYER_PROGRESS.md`。root已接LA02安全R及原读条到TrialSession/DriveHud，N保留在途弹丸，Backspace全复原；候选尚未进11e3。g4 LA06–09/LA11共用HUD与源倍率/无黑遮罩、g5 LA02真实OBB、legacy LA03–05竞技15秒/22米/共用恢复均继续专项短检，原生队列g4→g5→legacy；专项文档 `LA02_SAFE_RESET_PROGRESS.md`、`LA03_05_ARENA_PROGRESS.md`、`LA06_09_HUD_PROGRESS.md`（若后者未落盘以agent回报为准）。全项目仍OPEN，不以专项断言替代真实同包入口/画面。
- 独立旧版审查首批已交付：`LEGACY_BASELINE_AUDIT.md`。对照冻结2b169与当前工作区确认LA01-09玩法/UI遗漏、LA10过期基线文档，全部保持OPEN；每条附源/目标位置及真实入口验收。重点为试车/自由玩家CarUnit链、安全R重置、竞技15秒复活/22米占点及车体容差/共享脱战维修、剧情统一HUD/罗盘任务导航/伤害跳字字体。教程16步和flows实际一致、剧情维修已实现，未误报为旧版；导入器live来源风险另列。此为独立静态审查，不代表全项目已穷尽或已修复，不重开G0。
- 11e3自然开篇最新实测：38项功能PASS、运行/关闭错误0，但音频连续性FAIL（最大回调间隙2504.695ms、59候选断流，RAF最大1117.9ms）。破坏后的CarUnit.Flush为明确CPU热点，单次最高416ms；gate→hall最大间隙具体函数未定位。回厅Crater不驻留/cache约78MB，本路线未观察OOM；教程running=true但visible=false/voicePlayed=0，不能签自然路线教程可见可播。g4已退出独占运行，仅整理证据。
- 17:19用户新增“单独审查哪些仍旧版”：已暂停字体扩审释放槽，独立legacy_audit只读对照10/14冻结源，产物LEGACY_BASELINE_AUDIT.md。首批已复核ReticleState.Chips剧情旧尺寸/位置、ReticleGauges按story隐藏新版火控、MechReticle剧情旧长提示，和源10/13剧情统一新版要求相反；此为确认迁移遗漏。字体已落地三文件及待验项保留，不回退、不重启G0。原仓库HEAD5f0bc402比冻结2b169仅多音乐听审档案提交，模式差异不能归因源又更新。
- 17:06接续：root收回dbd65e2b真实Web帮助wheel FAIL/errors0（原始-1600事件已到引擎，scrollY仍0），保留证据并增加仅QA路由追踪，不能以native直接调用modal通过替代浏览器输入。g4已启动11e3/4296唯一自然PCM/deepCPU；root/g1/g5此时离线，结束后g5实际EnterTrial资源/全敌池短检→g1字体短检。字体生产新增暂停标题原22px行盒、涂装三处原tracking，未进当前11e3/dbd包。
- 16:58发现并修新功能阻塞：11e3 miniHeavy自然打捞83秒出现动态敌人Model requested before download readiness（96a6a08c...）。根因HangarApp.options.resources的salvage分支漏已有salvage.Run.Dependencies，已补入，guard保留；g5补实际entry load列表/敌池装配短检，修复尚未进入11e3。自然搜撤仍FAIL，不以已出发替代撤离。
- 11e3字体验收：驾驶详情PC5/5、20:9触屏4/4；音乐PC29/29、20:9 29/29、运行错误0。准星中文工业字/Chakra数字及描边实图生效，但描边为八向近似、设置字形着墨仍有差异（源已由CDP证实实际Alimama、font-synthesis:none，不能私自全局加粗）。root实际help截图显示原48条/原90%卡高，但真实wheel没动；已补modal壳转发，独立dbd65e2b/QA4298/PID2644检验，结果待回，不签11e3滚动通过。native原12项复验PASS/errors0。
- 2729 host两端最终均11/11 PASS/errors0/shutdown0，真实回厅教程T-01播放且Crater模型不驻留；20:9首次旧快照超时保留，真实失败图已有教程卡，freshF8复验确认。只签skipad公共host路线，自然sortie/PCM仍待独占测量。g4等待root/help与g1/build/livery退出后做11e3细分CPU自然音频。
- 字体第二批生产已冻结、下一统一包正在构建：g1补Web准星中文显式工业字体/原数字字体与3px描边、音乐盒原行高；root修帮助旧41条→冻结48条、kbd原正文/透明边框及90%整卡滚动。帮助native12/12 PASS、错误0，100ms阈值未失败；首轮9/11因夹具未扣scroll偏移FAIL保留。帮助旧数据来自过时导入器，已改为执行冻结UI._help再DOM结构化提取，避免旧41条断言继续遗漏。工坊打捞嵌套时遗漏Update/键盘转发已补，g5短检待回报。
- 2729实际字体截图补证：root PC help/settings/workshop，20:9 settings/workshop全部CAPTURED、运行错误0，`evidence/target-font-pages-manifest-2729bc84-2026-10-15T08-34-29-029Z`；真实查看，help仍旧清单/旧布局是此包已确认缺陷，下包修复，不签此页一致。g1驾驶详情PC5/5、触屏横屏4/4功能PASS，准星字体偏差另修后下包验。
- 2729真实教程PC24/24与20:9触屏37/37 PASS、运行错误0，实际编辑/保存/返回/重播和十槽高亮；前轮查旧“删除”按钮夹具失败保留。真实开篇skipad公共入口PC11/11 PASS、page关闭后errors0、回厅tutorial运行且craterResident=false/cache73MB；20:9采样门禁复验中。此非自然sortie/PCM或全S01通过。
- 新2729包已上线。g1实际Web音乐/驾驶详情PC及20:9；root实际help/settings入口/workshop字体结构；g4先完成native host释放再真实Web教程/host；g5完成已开始的d676合法T5自然搜撤。四路沿原进度继续，不重做已验旧项。
- 字体生产首批已完成并收入2729：音乐盒恢复原工业字，驾驶详情改回底部摘要/展开双栏/3.6秒标题。音乐35/35功能PASS；readouts88/88功能PASS，但224ms准备尖峰导致总FAIL。源自然PC与840×378 DPR3原截图已查看；源中的NaN和跨列宽度两项差异单独记账。新包视觉仍待真实截图，不能以功能断言签1:1。
- d676自然开篇音频37/37操作完成，但回厅后新教程21资源组引发OOM，整体FAIL。PCM最长1196ms/41间隙，仍未关闭音频连续性；旧原报告及补充analysis均保留。音频独占已结束，当前功能Web可并发。OpeningHost释放/教程延后候选已在2729，须新Web证明后才能关闭此条。
- 字体专线已由 `g1_fonts` 接手，复用已完成的g3并发槽，不重开G0。实际原版入口 `http://localhost:5173/three/`，26份CSS归一换行后与冻结10月14日源一致；音乐盒Windows错误改用Segoe UI已改回原VoxIndustrial/精确advance，尚未进入d676包。正在核对并修复试车仍显示旧左上详情与底部长键串的结构偏差，目标为冻结CSS底部摘要/展开网格；逐项进度 `G1_FONTS_PROGRESS.md`。
- d676共享加载真实20:9路线7/7 PASS、游戏/探针错误0，实际CDP双指放大/反向恢复/触点释放与返回已执行；加载页及试车截图已查看。证据 `evidence/loading-battle-manifest-d6764c9c-2026-10-15T08-07-30-447Z`。前轮期待旧“拉近”按钮的夹具FAIL保留在08-03报告；四条可选Windows归档404后逐资源回退，不等于必需资源缺失，也不签整体样式或真机性能。
- g4唯一自然音频改用QA4292/PID48740，仍同d676生产，修QA观察过早读取未Spawn combat.easy的guard；probe `62d618ad252202c9ecaef768d20ac3d47803dbb77484b23528272521dc3dd5f9`。4290旧probe及首轮bootguard失败原样保留。g1/g5/root暂不启动其他运行实例，离线代码与源核对继续并发。
- 16:01统一d6764c9c包已固定并验证身份，收入CollisionAudio事件unit/世界COM、BossHudMotion、原开篇Equipment/Chip/Missile预热及covered暂停3D/源.05模拟步长、SceneLoader进度watchdog、无尽Records安全数校验。root完整LoadingFlow772/772功能PASS/errors0，首轮旧夹具假机翼进入物理的失败已完整归档，未放宽生产物理校验；资源加载全生命周期联合进行中。g5 Records74/74 PASS/errors0。新包g3受控并发连续换图、g5真实T5自然搜撤、root实际PC进场/鼠标/滚轮/返回并行；全部功能退出后g4独占自然开篇音频。G5/G4及G3各ID实际账本已补，仍OPEN项不隐藏。
- 15:54 接续仍为 root + 三位既有 agent，不重新启动 G0。root 修复共享 SceneLoader 在持续资源准备时累计90秒误超时：资源索引、scene asyncProgress、分阶段checkpoint真实推进才刷新停滞计时，重复进度仍超时；LoadingFlow显示实际资源数量。新原生6/6 PASS、Lua/resource/engine0，`evidence/loader-progress-2026-10-15T07-53-18-330Z`；首轮夹具跳过Load初始化导致nil错误保留在07-50报告。共享完整加载回归与统一Web大车加载尚待。撞击消费者46/46功能PASS、Lua/resource0，但164ms尖峰整体FAIL；保留后处理覆盖停更18/18 PASS/errors0。g3继续五关入口及WasmFS证据，g4实际host覆盖/原.05时步/自然音频归因，g5继续N/L/D缺口与下一包自然搜撤。
- 6d暂停菜单真实Web：PC9/9 PASS；20:9首轮错误使用mouse wheel的夹具FAIL保留，改真实CDP触摸滑动后10/10 PASS/errors0，底行完整可见截图已查看。6d五关s1-s4真实入口各3/3 PASS/errors0，不等同完整通关。真实FS扫描未截断：初厅296.85MB→陨坑532.25MB，项目chunk.vdat80.44→312MB，完成后XHR响应0；FS文件大小不能单独证明堆后端，未擅删chunk。
- 15:45接续仍为root+三位既有agent。root新补原CollisionAudio侧向撞击音效，真实Bullet墙碰/落地/空中制动及29源规则43/43 PASS，错误0；发现共享CombatView事件需要unit引用后已补并追加实际消费者回归，待原生队列复验及下一统一包。进度`G1_COLLISION_AUDIO_PROGRESS.md`。6d自然音频33项后FAIL：导弹探针条件漏采样，仍实录PCM最长3205.67ms、94间隙，RAF最长1264.03ms；g4补准确探针与缺漏冷编译预热，不冒充完整开篇通过。g3同包连续OOM与五关入口、g5合法T5/COM自然搜撤、root暂停菜单PC/20:9功能Web并行。新只读COM QA4288/PID43404仍6d包，probe指纹`1282e39407c410c5a7bf617c188808ebd5d89c6736b8f06b9d60778e7e2019d1`。原生当前g5短搜撤→g3 Boss UI时序→root撞击消费者。
- 15:30：g5实际无尽联合45/45 PASS、Lua/resource/engine0，覆盖真实伤害/死亡/五秒复活/三命结算、实际Edit→Reload与Edit→Stop、首次正确退出及重复Leave不触旧主人、旧damage恢复与引用释放。证据`evidence/endless-runtime-native.json`；仅功能阈值，不作性能通过。新6d包生产未变，g5继续打捞实际返厅释放，结束交g4独占自然音频。
- 15:27：三路生产冻结后已创建上述6d18072e统一包，收入共享释放/死亡HUD/Install及Stop退出顺序、原PauseMenu、保留开篇post、装配池、原图预热与contain、剧情警报/三行横幅、无尽/打捞持有链清理。新包功能/音频/连续OOM路线均待实际Web回归，不能沿用8db结果。无尽联合首次实跑死亡/复活/结算和首次实际Edit退出通过；两条二次Leave spy误判和Engine:Exit未写JSON仍保留，夹具改分首退/重复幂等并等validator终点写报告，未改生产或放宽首次退出断言。
- 15:20接续：按用户要求继续root+三位既有子agent，不另建重复任务。g3战斗/地图/剧情，g4开篇/字体/音频，g5无尽/打捞/经济；root共享驾驶输入/UI/生命周期/统一包。原生窗口仅为焦点和性能量测串行，代码和离线源核对持续并行，统一包后的功能Web分上下文并行。
- root新增死亡Reticle早退：血量仍更新为0，清fire/lock，不读取已销毁车辆的native。g3实际Boss死亡/重生/三钻头/三飞机/结束/片尾/Reload及持有链112/112 PASS，Lua/resource/engine0（该wrapper阈值20秒仅功能，不作为性能证据）。root实际CarUnit死亡HUD与共享释放11/11功能PASS、Lua/resource0，仍两100ms启动尖峰导致整体FAIL；证据`evidence/world-lifetime-2026-10-15T07-19-42-886Z`。App.Install/Stop先退局内改装再替换/销毁旧HUD和后处理，g5完整Edit→Reload/Stop待联合复验。
- g3原三行MissionBanner与爆炸新短检514/514功能PASS、Lua/resource0，100ms尖峰仍FAIL，实际截图已查看；g4开篇14张原图分帧预热66/66 PASS，并修contain图片铺满裁切产生边缘条纹，最终联系表已查看。以上生产增量尚未进入当前8db包，不能套用旧Web结果。
- 15:10接续仍复用原三位子agent，未重开G0。root新增共享Body失效断native、Vehicle/Space/TrackWorld/DriveView幂等释放和TrialSession先退局内改装再销毁、末尾断会话引用。真实Bullet/实际模型/持有wrapper回收10/10功能PASS，Lua/资源0；273/351ms启动尖峰使整体性能FAIL，证据`evidence/world-lifetime-2026-10-15T07-02-05-756Z`。新清理后原装配池21/21 PASS/errors0；完整自然连续路线尚未复验。
- 同包8db网页声音设置PC及20:9各11/11 PASS/errors0，真实入口、checkbox、滑杆、持久值、局内返回均通过，实际三张目标/源图已查看；证据`evidence/audio-settings-web-manifest-8db734ff-2026-10-15T06-47-57-087Z`。新暂停菜单补原模式介绍重播/源蓝色/PC与紧凑横屏尺寸/全部滚动/触屏条目，原生26/26 PASS/errors0；实际Web待下一统一包。
- root原开篇保留后处理链14/14 PASS/errors0，切回同scene/camera复用实际29pass，停用不更新、释放全排空；不保留所有地图。g4真实431hero装配池21/21 PASS；完整host1700帧34/35、运行错误0，最终m-missile完成被fixture帧预算截断仍FAIL，不冒充自然整段通过。
- 8db横屏story5→完整自然片尾→wing→第二次crater仍OOM/FAIL；共享WASM固定1719533568字节，cache用量不代表整堆。g3补首关原警报灯及Boss/地图持有链，并继续补原collector/fight三行横幅。g5自然打捞两车均真实死亡返回，T3已搜到货并验证携货死亡10项PASS/errors0；成功撤离仍未通过，后续合法车辆/路网实驾，不注入状态。
- 本批唯一集成动作：原生短回归收齐三路冻结代码后打一个新不可变包；先g4独占自然音频PCM/RAF，再root暂停菜单PC/20:9、g3连续OOM/五关、g5成功搜撤同包并发。用户Editor运行实例不归本任务，不擅自关闭。

- 本轮统一包8db734ff已收入：声音设置PC/紧凑横屏源尺寸与最终主题、三路音量、SourceLayer纹理桥接/自有纹理释放、Hangar独占材质释放、地图FX幂等释放、片尾视频桥接API修复、431零件原装配动画/639flash显式预热、普通剧情原爆炸与Radio接线。root实际Web声音入口/布局，g3横屏story5→wing→crater，g5真实购强车搜撤/死亡结算并发；这些新包结果尚待返回。功能浏览器全部退出后g4独占自然开篇PCM/RAF。
- 本轮原生增量：Story爆炸/普通Mission Radio495/495功能PASS、Lua/resource0，33个100ms帧尖峰使性能FAIL；Flash真实预热collector覆盖15/15 PASS、运行错误0，但该短检不能证明新Web包已预编译。声音真实路由29/29功能PASS、错误0，仍有5个129–779ms尖峰，性能FAIL。旧失败均保留。
- 14:30接续：四个现有agent均保持运行，未另开重复任务。root完成原声音设置ref1080/紧凑横屏ref600的局部尺寸/字体/控件缩放，新增真实源三尺寸测量证据；共享弹窗改回源最终蓝色主题。新增SourceLayer显式Retire自有双纹理；card拥有composite上下文内的图片桥接，所以必须先Dispose card再composite（反序试验8条Invalid context失败保留）。真实双层弹窗resize/销毁/复开/Retire.Flush新增7/7 PASS、Lua/资源/引擎错误0、419ms，不改100ms阈值。Hangar仅释放Mat.Bind独占克隆并清节点引用，实际进出回归待复验。
- 声音UI首轮测试FAIL保留：boot遮罩未退便点击，试车后探针仍读VOX_HANGAR导致连锁错误。g5现仅接手这两份测试改动态门禁和持有app引用，生产设置由root维护；不以绕过真实点击替代。g3地图FX15/15、片尾Texture2D桥接11/11功能PASS/Lua资源错误0，但100ms尖峰仍性能FAIL。g3修正nvgCreateVideo错误配对nvgDeleteImage；20:9连续路线OOM待新包复验。
- g4实际431零件装配池化11/11、音频registry38/38、StoryRadio62/62功能PASS/错误0，驾驶音频及warmup新增检查进行中。g5新b8自然搜撤遇真实敌人低血卡路，未撤离，整条FAIL/运行错误0，已关闭浏览器；不把载入/搜到货算成功撤离。
- root：原声音设置、共享弹窗最终主题、三路音量云键和局内入口已接；新增`check-audio-settings.lua`真实鼠标/键盘/存储/回场生命周期检查，等待音频独占结束再运行。尚未打入b8包，不能套旧结果。
- g4_opening：原`vox.audio.v2`三路音量/Intro与MusicPlayer、Story说话压音乐已实现，新增模块原生29/29功能PASS。实际MasterGain上限1，SoundSource.gain允许1.5；因此其他音效以每源raw gain调制，不能用master比例假支持大于默认音量。b8自然开篇音频正在独占复测，其余任务不启动运行实例。
- g5_endless：b8真实PC与20:9无尽各8/8功能PASS，运行错误0，包含完整AI、补给、G改装与返回保留战场；两浏览器已退出。自然打捞搜到3件但直追撤离口爬山失败，保留FAIL；已离线核原845节点/908边，下一轮按原路网实驾撤离，不改地图或注入货物/时间/血量。
- g3_g4_battle_story：935 PC自然片尾8句/4panel/盖章/自动回厅及Boss后半/feather/边界共40/40功能PASS。盖章图发现旧漫画未完全淡出，最新生产透明度和原1.65s声音延迟已修，原生7/7功能PASS、启动尖峰仍性能FAIL。20:9自然片尾完成，但连续story5→wing→crater在再次进图时OOM，整条路线FAIL；不能写成双端完整通过。旧失败日志保留并追查资源持有。
- 音频测试独占仅针对测量有效性，三路代码/源核对/离线路由仍并行。下一动作：g4自然音频结束后按原生窗口队列验增量，固定下一份不可变包，同包真实回归；不重复身份调查或旧项。

### 接续检查点：935b3961统一包

- 最新候选已推进`manifest-b8b63ade.json`，快照`.tmp/outgame-cached-1792044093624`，脚本指纹`477f9b9e7214352d45012b57825a5591d3e8b43a3ff636bb27b2147fa46417a6`。普通4281/PID6364、QA4280/PID9844；收入无尽shieldTarget契约修复、打捞原爆炸实际Run hook、开篇原逐字双底板/Track33字图、剧情LINE_LIST/spawnFlash和刹车重复分摊修正。新包结果待实际验证；爆炸余烬投影修正在copy后，不属于该包。
- 不重开G0，复用g3_g4_battle_story、g4_opening、g5_endless三个子任务继续G1-G6。root负责共享输入/显隐/分帧/统一构建及真实物理曲线。
- 本批统一普通4277（PID34176）、QA4278（PID34696）：`manifest-935b3961.json`，`.tmp/outgame-cached-1792043283252`，脚本指纹`494022f184eb6e207d03086817785d92f28e15fa9d0ea764518ae02bc8c38f7e`。上方cbeb包为历史，不再代表当前候选。
- 已收入root开镜持续隐藏/原mask恢复、Esc延迟接管、装车内部协程/取消、伤害击杀归属；g4原GameFont219字形/原sortie光效；g5打捞Fx和无尽改装adapter；g3动态甲板及自然片尾推进/字体。未挂钩的新SalvageExplosion不能算此包功能。
- 935真实PC滚轮、第一人称鼠标/WASD、上色、Esc释放后真实点击重新锁定、涂装缩放、MEGA取景全部PASS，游戏/探针错误0。报告`evidence/web-camera-input-935b3961-2026-10-15T05-49-17.json`，对应建造/MEGA两图已实际查看。
- g3动态甲板原生6050/6050功能PASS、Lua/resource错误0；4条100ms尖峰导致整体性能FAIL，未放宽阈值。Boss/完整自然片尾935同包Web进行中；g5同包改装/打捞进行中，之后g4独占自然开篇音频验证。
- root新增真实Rapier0.21世界：同3份冻结蓝图、每车3次、固定60Hz加速/滑行/反向制动/转弯，共2430样本；Bullet同条件测量待原生窗口可用。此为量测，不凭公式签收手感。
- 上述真实世界已完成三组实验，详见`G1_ACTUAL_WORLD_MEASUREMENTS.md`。4km单块box造成Bullet接地剧烈异常，不能直接归因驾驶控制；双方同1km地面后GT末速26.1189/源26.1200，停距11.8421/源11.8092；GT转角仍差0.7035rad、履带加速距离仍差7.7143m、COM仍不同，未签收G1。2439/2439只证明量测成功。
- 935原scope两端FAIL已保留；probe原来在Update内、动画启用后但PostUpdate隐藏前取样。QA4279同935生产快照、只将trial采样延后真实PostUpdate后，两端13/13 PASS，实际开镜231/visible0、释放恢复mask、错误0。不是通过篡改生产显隐或跳过开镜断言。
- 935真实无尽两端均FAIL：shieldTarget缺冻结源pos/zone/aimPoint导致AI Spatial(nil)。g5已按源补target，新增完整真实driver原生25/25 PASS错误0；新b8b网页待验。旧失败不覆盖。
- 新发现fixture文件NUL异常已让g5隔离处理；root扫描当前scripts及935快照全部Lua均无NUL。后续Track原GameFont33张文字纹理已由g4核源推广，尚未进入935包。
- 下一动作：收齐935各Web功能结果，修实际失败；全部功能浏览器退出后独占测自然音频。保持旧失败与真机/真实账号缺口，不回到G0重新调查。

### 接续检查点：04:00并发批

- 仍为root加三个既有子agent，不重开G0、不另建重复任务。g3负责第五关甲板原动态接口与Boss；g4负责原开篇催促/锁圈光效和自然音频；g5负责无尽局内改装适配、打捞原爆炸火烟；root负责共享输入/显隐/装车协程/同包集成。
- cbebfb9c两端Boss真实开镜FAIL：231个玩家StaticModel有10个仍可见，根因为WeaponPresentation每帧重新enabled。root正在原生回归自存显隐mask、开镜持续隐藏和实际重建后恢复；不是删除模型。原生新增恢复断言先FAIL（4702/4703，Lua/resource/engine错误0），暴露引擎重复递归操作覆盖内部mask，失败记录保留。
- cbebfb9c自然开篇真实ESC再捕获FAIL，迟到锁请求与长帧使pending超时；root DrivePointer/BuildCamera已改按响应帧累计等待并主动释放无授权迟到锁，新增夹具通过。当前包尚未收入生产修复，完整自然开篇/PCM间隙仍FAIL，下一包单实例无PNG编码重验。
- root装车内部checkpoint已接VehicleView/DriveView/CombatView/TrialSession，候选场景每零件让现有SceneLoader预算决定yield，并在首次yield前交所有权以允许取消。实际feather同步/分片模型、颜色、边界、飞控绑定与取消释放检查通过；不因此宣称整体加载性能已达标。
- g5 cbeb自然搜刮真实驾驶/搜索/货舱/放弃/回厅7/7 PASS、游戏错误0。证据`evidence/salvage-natural-manifest-cbebfb9c-2026-10-14T19-43-03-567Z`；不是成功撤离、死亡、超时或真实账号恢复证据。新Run/Fx与Edit后续增量待新包。
- 原生窗口队列：g4短sortie-fx→g5局内改装适配复验→g3甲板ray/显隐/唤醒→root联合。代码并行，原生窗口串行避免焦点争抢；统一包后Web各功能上下文并行，音频性能最后独占测。
- 当前唯一下一动作：完成上述增量原生验证后固定一个新不可变包，实际ESC释放/重捕获、scope零子模型泄漏、Boss后半流程、无尽局内改装和打捞新效果同包回归。旧FAIL保留；完整G0-G6仍按138项追踪。
- root最终联合原生`evidence/physics-batch-2026-10-14T19-55-54-208Z/result.json`：4788/4788 PASS、测试范围错误0。已包括上述scope原mask/损坏重建、pointer-delay、真实分片/取消，18源伤害/击杀归属和24源CarUnit有效/拒绝命中归属。g5最新Edit23/23、Run/Fx29/29 PASS错误0；g4新GameFont字体短检、g3甲板/完整自然片尾仍待本批验证。下一动作仍为统一包真实Web，不重复原生旧项。

### 接续检查点：显隐、预热、驾驶反馈

- 沿用三位现有 agent 与冻结10月14日基线，不从 G0 重开。native 队列为 g4 预热/教学 → g5 打捞 director → g3 Story/Boss/Boundary 显隐 → root 联合物理；Web 同包独立上下文并行。
- root 已补仓库专属 PreviewRoom；原生仓库几何诊断1/1 PASS且无白面，但该诊断绕入口门禁，Web白色横面仍待真实采购入口射线定位。
- root 修复 CarUnit 毁车分类漏 wings/mechLegs；626项冻结源分类与受损机翼/机械足真实Bullet重建检查已加入联合检查。首次982项遗漏旧story-marker帧42，现分类移到44，不能把982当完整联合通过。
- root 新接冻结源 CameraFeedback：武器开火、近爆、钻头、加特林震颤、机械足落脚/腾空/落地弹簧与 Story/Salvage stompV；新增8场景960帧原JS黄金夹具及实际引擎相机姿态检查。第一人称车体改递归显隐。完整联合4595/4595 PASS、测试范围错误0；新增MechView空中插值引用修复及真实T3/T4/T5渲染14/14 PASS。证据与边界见 `G1_CAMERA_DAMAGE_PROGRESS.md`；待统一Web包，不签收完整G1或手感。
- g3 修真实递归显隐并补原glow metadata/collector落地；g4 预热去重实际291呈现帧/276批次并保留4实例覆盖instancing；g5 恢复源锁红/开青/撤离绿信标及原生成/采购/搜撤规则。生产稳定后统一新包，不将旧1f35093f结果套入增量。

| 任务 | 执行者 | 状态 | 所有权与下一动作 |
| --- | --- | --- | --- |
| G2/S02 跳过确认覆盖路线按钮 | root | 子检查 PASS | Web 96/96、4种 PC/20:9 实际两次点击；图见 `evidence/tutorial-layout/2026-10-14T15-50-07-298Z`；非真机 |
| G4/S01 开篇五阶段 | g4_opening | IN_PROGRESS | 新 `intro/*`、`ui/Intro*`、`audio/Intro*`、`assets/Intro/*`；原宣传、现实、通讯、合同、出击；进度 `G4_OPENING_PROGRESS.md` |
| G5/N01-N07 无尽 | g5_endless | IN_PROGRESS | 新 `endless/*`、`app/EndlessSession.lua`、`ui/Endless*`、`assets/Endless/*`；原波次/掉落/仓库/改装/生命；进度 `G5_ENDLESS_PROGRESS.md` |
| G3/M03-M05/W08、G4/S06-S07 | g3_g4_battle_story | IN_PROGRESS | 地图边界、狙击识别、第五关/Boss/片尾；进度 `G3_G4_PROGRESS.md` |
| 公共入口和统一验收 | root | IN_PROGRESS | `HangarApp`、`TrialSession`、`GarageHud`、`HomeBattle`、`BuildSession` 由 root 集成，避免多人相互覆盖 |

子任务先交可接入代码及精确接口，root 持续集成，不等待全部代码完成才开始验证。所有任务按源行为和资源实现，不拿静态图、空回调或测试赋值替代原功能。

## 10月15日接续批

- G3 边界与狙击瞄准线/威胁 HUD 已接入 `TrialSession` / `DriveHud`。原生发现 shader 保留字 `line`，子 agent 已改 `hexEdge`；后续同包 Web 再验。
- G4 第五关已接真实独立 `EnginePit.xml` / `EnginePitWorld`，从冻结源导出 168 模型、26 材质、原 194 碰撞描述（18 个源 fallen 禁用，启用 176）、500x500 高场、路宽与顶棚，五组 shader hook 与陨坑源逐字相同；烟/风特效仍待完整接入及场景实际验收。
- G4 开篇模块最新85/85、真实host16/16、live24/24、宣传演出8/8通过，运行范围错误0。原版55音频/14图片、实时场景/装配/驾驶/导弹/光束、签约和闸门已接；清理教程叠层及延迟三帧抓取的实际图片已核，Web完整播放仍待验。
- G5 644/644 源规则对照、18/18 原生真实入口→出兵→补给→保留战场改装→复活→三命结算→回厅通过；原音效、零件缩略图、限量库存、HUD/选车与云键已接。Web与真机、商店/补给视觉验收仍进行。
- G1 机械足3557/3557源黄金、56/56 Bullet行为、11/11实际骨架/护盾/喷口检查通过；首次快进的性能FAIL单独保留，拆帧后行为通过。root已修FK X角/镜头俯仰并补护盾扫描/落脚脉冲及2.4倍喷焰。新喷焰截图正在补，见 `G1_MECH_PROGRESS.md`。
- G1 机翼源黄金5865/5865（含正反推进）、实际wing2..5骨架/舵面/尾迹20/20通过；整体检查的启动/脚本尖峰仍FAIL，不能算性能通过。受损飞行、真实Web控制仍待验。
- G3/G4 Boss 原生107/107重跑通过、FOX四足真实装配通过；已补display lean、露天跳砸重定向、冲击衰减/腾空免疫与钻头驾驶。片尾董事长修用源透明cut图片，完整淡入截图已核；自然完整战斗及全片尾仍待验。
- 源主页 `shared/ui/home.js:44` 隐藏无尽，保持这个入口状态；可通过 `app:SelectEndless()` 真实选择，不自行增加替代卡片。
- PC相机检查在4261中间包通过：原版像素滚轮可逆、FP鼠标接管/WASD、涂装缩放、MEGA预览墙体约束，运行错误0。此前首滚轮FAIL是测试在boot-exit遮罩关闭前操作；失败证据保留于 `evidence/web-camera-stale-probe-ef8eb4a7.json`，测试已改等实际可操作。
- root本批公共伤害修复：CarUnit狙击armor绕盾、贯穿余量/倍率/溅射，TrackWorld/各模式透传shield/pierce，HUD分行伤害/穿甲/抵抗、原字体/字号/1.1s动效/大块击碎门槛。冻结源96层+12贯穿夹具，原生112/112 PASS，运行错误0。对应原生真实HUD132/132 PASS；保留之前截屏裁切与测试缩放/过早返回失败报告，不作为生产问题关闭依据。
- 同包9100f4af：PC真实滚轮/FP接管/WASD/涂装/MEGA相机Web PASS，运行错误0；20:9触屏建造返回、试车加载/摇杆/release/返回8项PASS，运行错误0。冷厅53.746秒、试车10.094秒仍为性能不合格；桌面模拟不等同真机。证据 `evidence/web-camera-input.json` 与 `evidence/full-parity/2b169a996464/G0/manifest-9100f4af/2026-10-14T17-53-09-434Z`。
- 继续源对照发现HUD仍读旧总耐久：新增CarUnit:Life，对齐核心/15%预算瘫痪线/车体耐久取最小值；HUD/目标/低血和维修声音改接Life。新增144个冻结源黄金场景，连同伤害验证原生256/256 PASS，运行范围错误0。新包运行回归仍待验。
- 当前三路下一动作：G3/G4使用QA4265的大厅F4、局内Home避开生产F5重载冲突；G4真实开篇等待loadingFlow完全退出再点击；G5修商店980px源宽及编辑投影并跑20项原生和Web。只回归实际变动，不重开G0。
- 三个子agent并行制作，原生窗口验证按g3→g4→g5→root排队，避免抢焦点；Web可分开浏览器上下文并行。生产稳定后统一包，同包验证不重新审计G0。

## 已完成的前批内容

见 `G0_BATCH9_2026_10_14.md`：原启动页、有效首帧加载门禁、教程通讯卡连续布局、可见视锥预热、旧加载 toast 移除。原生加载 722/722、教程 41/41；这只证明对应子检查，未签收 G0 或所有教程状态。

## 保留缺口，不阻塞后续实施

- G0/Q01-Q05：当前冷启动与陨坑总等待仍长，最大实测 rAF 停顿 4.84 秒；加载性能 FAIL。暂不重复进行归档/并发调参调查，后续统一构建采样。
- G0/D03、Z04/M08：真实账号刷新恢复和编辑器操作证据缺失。
- G1：地面/悬浮/空中等已有迁移与原生结果，Web 各移动方式和手感完整对照未完成。源建造夹具 `mixed 43 / T1` 转轴环递归失败保留，不改冻结源或删除失败样例。
- G2：全页面、长文字、所有字体/光效/动态状态未完整验收；当前确认按钮是新增发现。
- G3-G5：以上并发工作进行中，其余总计划 ID 均继续跟踪，不能因先补主要缺失系统删除已有规则或验收项。
- G6：同包全流程、连续进出、弱网、实际手机/M1长期性能未完成；桌面20:9不能代替真机。

## 交接要求

每批结束更新本文件的当前包、任务状态、失败证据和唯一下一动作。源内容已冻结时只核身份一次，不反复重跑整个G0。当前下一动作是收集并修复三路真实Web功能结果，收入Life/safeCam/商店宽度增量并固定新包，继续G1-G5源遗漏；不是从头审计。

## 并行接续：02:10批

- 三个既有子agent持续执行，无重复创建：g3_g4_battle_story 完整源AI；g4_opening 开篇原演出及短radio cue；g5_endless 缺料采购及云恢复校验；root 原版触屏驾驶与统一包。
- 同包9100f4af，真实Web开篇PC、20:9各10/10 PASS，包含实际文本输入、空签名拒绝、笔迹、签约、闸门、返回及输入释放；旧返回probe假阴性归档保留。原生开篇89/89、最新演出12/12 PASS，完整自然演出/声效持续性仍未签收。
- QA4266同包Boss/片尾/原feather飞行/陨坑边界PC与20:9各19/19 PASS，游戏错误0。每端4个引擎缓存7z回退404单列，不计为游戏资源成功。
- 无尽商店修为源实际Panel/ScrollView，3列/980px/80vh；最新原生真实链21/21 PASS错误0，实际商店和车居中截图已核，等待新包Web。
- root发现并补旧触屏驾驶UI：复制25个冻结源原图标（证据touch-icon-import.json），右手切角弧形键、开火就绪条、按载具隐藏无用键、情境翻正/交互、飞机方向舵、浮动八边形摇杆及机械足外圈冲刺。源真实构造器/样式重新量201摇杆样例与4比例，旧touch对照不能作为新源验收。新增verify-touch-drive.ps1原生656/656 PASS，运行范围错误0，实际画面已核。首次旧别名传nil样式导致加载失败已修；第二次Yoga像素取整误差为测试容差修正，两失败报告均保留。新包Web20:9/16:9进行中。
- 尚缺触屏设置持久化、原版移动编辑器完整布局/点放长按删、辅助瞄准与自动开火。当前drive补齐不代表所有移动端功能完成。

## 并行接续：完整AI与移动建造批

- 不重启G0；继续G1-G5实施，G6随统一包验证。三位原子agent持续复用，未新建同名工作。
- 43b0ce1d实际Web触屏驾驶16:9、20:9各19/19 PASS，运行错误0；无尽PC和20:9各6/6 PASS，但后者touch=false，是横屏布局/流程证据，不是真手机证据。无尽加载约67秒，性能仍FAIL。
- 完整源EnemyDriver已替换旧简化决策；65场景11700帧23455/23455功能PASS，源route夹具改深拷贝后重验通过，100ms尖峰总报告仍FAIL。BattleController、Mission、Boss ally、EndlessSession、salvage/Run均透传reset/flip/salvo，DriverActions按原版先reset再flip再物理。
- StoryRadio短cue原生62/62 PASS，运行范围错误0；自然完整开篇/全剧情声音连续性仍OPEN。
- 源AimAssist纯函数336/336黄金PASS，root新增DriveAim接准星附近裸露零件吸附、scope1.8/触屏2.2角、鼠标减速、触屏跟随和可选自动开火；生产入口与新设置仍待本批统一验。修ReticleState距离X符号及辅助目标HUD引用。
- 原版移动建造TouchEditorLayout/Widgets/TouchBuildControls由g4并行制作与验收；root已接TouchTarget/TouchAt、指尖射线、tap模式不重置到中心、PC保持中心射线，并隐藏触屏下旧desktop层。手势及移动stats源比例由g4核对。
- TouchPreferences按源默认/枚举落盘，并接touch-settings云键；TouchSettings按原7类分段设置接入，驾驶菜单补原试车传送/出生与无尽维修/下一波/改装。按钮大小、敏感度、飞机模式共用偏好；真实账号刷新恢复和平台全屏能力仍须实测。
- 打捞StashRules严格数值与事务70/70、缺料购买/批量/Undo补买/整车失败退款14/14原生PASS。公共BuildSession.Attach、GarageHud采购入口已接，源禁止的建造内load/import被守卫，save/export允许。采购新580px样式是后续增量，不归入旧Web包已验。
- 下一动作：g3生产自然AI、g4实际移动建造、root公共集成输入/设置验证；稳定后制作唯一新包，分浏览器上下文同包回归。真实手机/M1、真实账号和冷加载失败不隐藏。

## 并行接续：8d52110f统一包

- 继续原三位子agent，不从G0重启：g3自然AI/任务目标，g4自然开篇及真实音频时间线，g5真实采购PC/20:9，root移动建造实际触摸与共同故障修复。
- 原生移动建造1067/1067 PASS、驾驶660/660 PASS。驾驶第一次643检查有1 FAIL，实际为TouchDriveControls局部adapter闭包nil使LoadingFlow失败；已修作用域后660项重验。失败报告单存touch-drive-settings-adapter-failed.json，不因引擎summary错误数0掩盖LoadingFlow日志故障。
- 公共同进程1069/1069 PASS：输入/设置/自动开火门禁、数值存档、AI源生命/瘫痪判定195、任务指引/投影732、新车创建9种成功/部分写入/抛错/回滚故障。报告current-integration-native.json；Lua/资源/引擎错误0。宽松尖峰阈值只为功能验收，不能签收性能。
- Garage.CreateVehicle任何SaveSlot/Switch失败（包括抛错）退休刚分配车位的双代存档并恢复原车与元数据；清理或恢复失败显式rollback，采购不得假退款。实际购买UI扩展原生及Web继续由g5核验。
- 新唯一包已启动并核对身份；当前下一动作是4路同包真实流程与截图。旧包的通过结果不套用；冷加载、账号刷新、自然完整剧情与真机性能仍OPEN。

## 并行接续：真实流程发现与收尾

- b3a7f84f（QA4271/普通4272）修采购实际回车库；两端真实采购各5/5 PASS、运行错误0，明确检查车库“拆掉这辆车”按钮和新车渲染。旧8d的统计通过没有发现子页未切换，不作为此修复通过证据。
- b3实际触屏驾驶20:9/16:9各19/19 PASS；实际移动建造各23项通过但总体FAIL：DOM touchcancel被引擎映射普通结束导致误放置。问题/根因/证据见WEB_TOUCH_CANCEL_BLOCKER.md，不以纯Lua取消夹具覆盖真实平台缺口。已查看20:9实际stats截图。
- 8d PC自然竞技12/12 PASS：真实5AI位移/多战术/交火损伤，未传送或注入HP/kill；冷厅58.186s、战场98.187s性能FAIL。剧情4横屏实际16/16 PASS（敌人/采集器/指引/返回），全剧情未签收。
- 自然完整开篇首次真实到comms发现Plain/gsub第二返回值误入utf8.len，无标签对白崩溃；已修单值返回，原生91/91 PASS。长播放声画连续性仍FAIL，最大音频callback gap14.31s；g4继续原演出机位预热及源sortie准星/标记，不能拿skip路线签收。
- 当前候选1f35093f（QA4273 PID27768/普通4274 PID36572）：.tmp/outgame-cached-1792003884897，指纹5ebde9bdac61daa63cbc313eb654ce11a12479513efb6fc14297d34fc3849572，包含采购回车库与Plain修复。g4在该包重跑自然开篇，其他长测试保持各自旧包身份。下一生产增量不要套用此包。
- g5新结算/两代重开/云解码隔离store25/25 PASS，含开局raids计数/幂等/失败回滚；这不是自然搜撤或真实账号证据。新BeginRun等delta待下包。root接仓库白色遮挡实际射线取证；g3继续信标色/淡化和Boss安全提示；g5继续原巢穴/巡逻/营地生成、车队额外奖励和警觉HUD。
