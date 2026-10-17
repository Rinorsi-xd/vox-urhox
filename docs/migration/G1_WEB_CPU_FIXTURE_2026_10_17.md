# G1 Web CPU 隔离基准准备与边界

日期：2026-10-17。当前状态：Web 六车小场地 profile 与真实 damage 五夹具、12 阶段、23 范围 profile 均已有效通过。未改生产代码、未提交推送。

## 最新实测：毁伤 local 分段 PASS，无生产修改

已阅读 CURRENT 最新整帧与 occIds 拒绝结论。本轮以当前普通 fc1c 源冻结 `.tmp/outgame-cached-1792171171463/identity.json` 派生；TurretRange/VehicleSpec/CarUnit/Blueprint 四目标模块与此前实测 f429 完全一致。收到 tab_failure_audit 明确关闭4499及浏览器后，独占4496完成唯一一次真实 profile；未运行优化/AB，未修改生产或 CURRENT。

实际隔离 profile 包：`.tmp/g1-web-cpu-local-sections-fc1c-profile-v2/identity.json`。首次硬件前按项目现有模块通信范式把 marker 显式放 `_G` / `rawget`，离线重建 v2；旧无 v2 包从未启动，不属于失败硬件重试。只替换 main 和两个含计时标记的模块；不是 occIds 优化。实际 main SHA `8d0f884991a9abbdfd56eb813641203c324074d0e15ff1639a82d39eca3c5055`，damage probe SHA `6cdac8f5db5987bf547c04fc52fd2cc9bc7506686bfcfbcfe8ce3ad75fb79fdc`。TurretRange profile variant SHA `c6ac2180777341102e234d8a89d40eb4ab2132e89ce7177b02909f687152608c`；VehicleSpec profile variant SHA `2d713d9023867357be0379561fcab747dfd9f3f5f97ae292b0bedccdca870d40`。

`evidence/g1-web-cpu-local-sections-fc1c/report.json` 为 PASS/CLOSED，runner96822退出0；Runtime/HTTP错误0，7926本地资源/22 HTTP身份通过。独立 `summary.json` 重算通过：全部初始/逐阶段炮塔 range、完整 state 摘要和32个 RNG尾值与无包装 A1完全一致；23导出范围和八个local范围非负/calls/父范围对账通过。再执行独立 `g1-web-cpu-verify-damage.cjs`，五夹具/12阶段及逐阶段流与最终结果逐字段一致。服务3474已Ctrl-C退出、4496无监听、Chrome无残留。

| 巨型车非 combat 单块 Flush | 第1块 ms | 第2块 ms | 第3块 ms |
| --- | --- | --- | --- |
| 外层 Flush | 26 | 26 | 27 |
| TurretRange.For inclusive | 8 | 8 | 8 |
| List/签名 self | 2 | 2 | 2 |
| 失效检查 self | 0 | 0 | 0 |
| Prepare self | 2 | 1 | 1 |
| Evaluate self | 4 | 4 | 5 |
| SameContext self | 0 | 0 | 0 |
| MergeBoxes inclusive | 6 | 6 | 6 |
| Merge 索引 self | 0 | 1 | 1 |
| Merge 排序 self | 3 | 2 | 2 |
| Merge 扫掠 self | 3 | 3 | 3 |

For 第2块 local self合7 ms、导出inclusive8 ms，剩1 ms未归入局部；其他两次残差0。Merge三次局部与父范围均对齐6 ms。0表示低于整数毫秒分辨率，不能说没有开销。签名和 Evaluate 已确认各占实测时间，occIds候选改动的失效检查在该样本均未超过整数分辨率，这与其 ABBA 无收益一致。

初始mega构车非 combat/combat为147/123 ms；其 TurretRange.For为65/64 ms，其中 Evaluate均58 ms/3调用、Prepare5/4 ms、签名各2 ms。raceCar初始66/57 ms，Evaluate52/48 ms/3调用；第一次破坏Flush13 ms，For10 ms由 Prepare2+Evaluate8 ms组成，后两次不重跑Prepare/Evaluate。以上是隔离未分帧构车的带观测归因，不能换算正式加载页或完整战斗FPS，也没有优化收益。Merge扫掠3 ms仍包含Key、Has、Row、Layer、质量累加和box创建，尚未细拆其内部贡献。

新增八个局部范围，另存 initialBuildLocalScopes / damageLocalScopes / flushLocalScopes，不与原23导出方法的 self 相加：

| local 范围 | 精确计时边界 |
| --- | --- |
| TurretRange.For.Signatures | bp:List、全量签名生成、变更/删除 id 集合 |
| TurretRange.For.Invalidations | 每武器 previous/context 读取、旧占用失效与新变更格相交检查 |
| TurretRange.Prepare | 原 Prepare 全部执行，保留早退与返回值 |
| TurretRange.Evaluate | 原 Evaluate 全部执行，保留采样顺序、射线缓存及 blockers 顺序 |
| TurretRange.SameContext | 原 SameContext 全部执行 |
| MergeBoxes.Index | 原 cells 遍历，构建 left/order |
| MergeBoxes.Sort | 原 y/z/x table.sort |
| MergeBoxes.Sweep | 原 Has/Row/Layer 的 x→z→y 贪心扩展、质量累加和输出构建 |

范围内含计时包装扰动，Sweep 暂未单独拆分逐格字符串 Key 与扩展运算，不能据未测结果猜收益。所有局部 marker 只存在派生模块，回调/随机/浮点计算顺序不变。离线真实函数输出对照通过：TurretRange 61 次变更输出/checkpoint/RNG，MergeBoxes 34 个含空格集、负坐标、质量阈值的输出/checkpoint/RNG；八范围栈/self守恒、reset/restore通过。runner 新增六个负控通过，强制 local 标签/非负/calls 与导出范围一致、local self 不超父导出范围。原工具16项拒绝控制及三模式自测继续通过。这些均非真实运行性能证据。

唯一一次独占窗口运行命令，服务与 runner 分终端；发生启动契约或内容错误先停并通知，不无限重跑：

```powershell
node tools/migration/g1-web-cpu-serve.cjs .tmp/g1-web-cpu-local-sections-fc1c-profile-v2/identity.json 4496
```

```powershell
node tools/migration/g1-web-cpu-bootstrap-audit.cjs .tmp/g1-web-cpu-local-sections-fc1c-profile-v2/identity.json http://127.0.0.1:4496 docs/migration/evidence/g1-web-cpu-local-sections-fc1c/bootstrap-audit.json
node tools/migration/g1-web-cpu-run.cjs http://127.0.0.1:4496 docs/migration/evidence/g1-web-cpu-local-sections-fc1c
```

与此前相同真实五夹具/12阶段；炮塔 range 及完整状态/RNG摘要均在计时外保留。上方为本次已执行命令，后续复测必须使用新证据目录，保留原结果。完成后必须 CLOSED、停服务及确认无 Chrome 残留。本批不继续追加硬件或自动合入优化。

## 最新真实毁伤分段：PASS

`evidence/g1-web-cpu-sections-damage/report.json` 为 PASS/CLOSED，Runtime/HTTP 错误均为 0；22 个实际 bootstrap HTTP 身份检查通过。专属 4496 服务与 runner 已停止，Chrome 无残留。独立 `g1-web-cpu-verify-damage.cjs` 重算通过：5 夹具、12 阶段、每段 23 个唯一范围，全部 self 非负且不超父范围；包装 self 总和不超 Damage/Flush 外层墙钟，12 份逐阶段进度与最终结果逐字段一致。

巨型车 1611 零件的三次逐块击毁，实测主要耗时位于重建规格，不是原生车体初始化：

| 非 combat 阶段 | 零件变化 | Flush ms | VehicleSpec.Build inclusive ms | BuildParts inclusive ms | TurretRange.For self ms | MergeBoxes self ms | Vehicle.init self ms |
| --- | --- | --- | --- | --- | --- | --- | --- |
| part 1 | 1611→1610 | 26 | 19 | 9 | 8 | 6 | 2 |
| part 2 | 1610→1609 | 26 | 19 | 10 | 7 | 6 | 2 |
| part 3 | 1609→1608 | 26 | 20 | 9 | 8 | 6 | 1 |

三次 Damage 均低于 1 ms 整数计时分辨率；Blueprint.Graph 各 1 ms，Connectivity 为 2/2/1 ms，Rotors.Spec 为 2/1/2 ms。`VehicleSpec.Build` 包含 BuildParts、MergeBoxes、TurretRange 等子范围，**不能把 inclusive 父子相加**。三次 Flush 的全部已包装 self 为 25 ms，外层剩余 1 ms。下一步可针对实测 `TurretRange.For` 与 `MergeBoxes` 做候选和等价/A-B 验证；此次没有优化代码，不宣称改善。

其他实测：raceCar 初始构车为 64/61 ms（非 combat/combat），megaMech 为 151/135 ms。raceCar 逐块 Flush 为 14/3/2 ms，首次的 TurretRange.For self 11 ms。megaMech 非 combat core kill 的 Flush 14 ms，其中 Debris.Spawn inclusive 11 ms、VehicleSpec.Debris inclusive 9 ms、MergeBoxes self 6 ms；combat hull kill 的 Flush 19 ms，依次为 16/14/11 ms。父子范围重叠，不能累加。单桥断连 7→2 保持存活、一个四块碎片组，之后 core kill 2→1 死亡、总两组 debris，两次 Flush 均低于整数分辨率。

本轮为隔离的真实 CarUnit/VehicleSpec/Space/Debris Web 夹具。非 combat 样本没有活跃 WeaponSystem，相关包装 calls=0；不包含渲染、音效、UI、AI、真实开火及 CombatView GPU 上传，不能据此宣称完整对局 FPS 或骁龙845持续性能。profile 包装有扰动，只用于归因；三次 26 ms 与旧无包装 26/26/27 ms 不是优化对照。

## occIds 隔离候选：ABBA 等价通过，无有效收益，不合生产

当前生产 `TurretRange` 已有 bp 弱引用缓存、局部占用失效和射线缓存。For 的 7–8 ms 是整个导出函数的 self，尚未细拆其签名构建、逐格失效检查、Prepare、Evaluate；不能仅凭源码认定其中哪段最大。核对 `TurretRange.lua`、`VehicleSpec.lua`、`CarUnit.lua`、`Blueprint.lua` 与已测冻结字节完全相同。

候选只在 Prepare 完成最终 `occ` 后存一份占用 owner 唯一集合 `occIds`，For 检查失效 id 时从逐格遍历改为唯一 id 遍历。集合必须从**最终 occ 值**构建，保留重叠格后写入者；不能收集所有曾靠近的零件。这里仅判断两个集合有无交集，迭代顺序不影响布尔值；没有更改 Hit 的采样顺序、blockers 顺序、几何数值、checkpoint 调用点或随机调用。多出集合构建与内存成本，实际可能无收益或变慢，必须等 ABBA。

`g1-web-cpu-occids-selftest.py` 离线通过 61 次逐步 range 输出、checkpoint 次数与 RNG 尾序列对照；覆盖重叠赢家/输家、同 id 多格、无交集/有交集、反复 damage/repair、owner 变化、武器移动/旋转、分数格、哈希域外格、空占用与未变化调用。另比较最终 occ 集合与 occIds，并对 16 个失效子集核验谓词。此处依赖是确定性假几何，不冒充真实游戏行为实测。

原 damage 状态摘要没有炮塔 range，不能充分验收此候选。工具已在计时外加入 `initialRangesDigest`、逐阶段 `rangeDigest` 与完整状态中的 weaponRanges；修改后工具离线自测仍通过。为此重建新 A/B-v2，旧 A/B 不用于候选验收。生产代码仍未改。

| 变体 | 派生身份 | TurretRange SHA-256 |
| --- | --- | --- |
| A 原版 | `.tmp/g1-web-cpu-occids-A-v2-timing/identity.json` | `cb7fa9d831a2af1c76a3f72008dc3a340dbae3531d5107bf1030cfb1ad4240cc` |
| B occIds | `.tmp/g1-web-cpu-occids-B-v2-timing/identity.json` | `6a937443db152a72dea90dbaeb21e8af90b1f98b177484376864019e8cc16c71` |

两包 542 脚本只有 TurretRange 不同；共同 main SHA `72231a91c541b79e30c317ad1804e32d647af822c540c5465eb6545e957d839a`，共同 damage probe SHA `ed2fd12d829811dcc154f3f3a351dcc264f0a07d9937241d5de57114b869269c`。同一源冻结、五夹具、seed1016、timing 零包装。独占窗口按 A1→B1→B2→A2，每轮全新服务与浏览器已跑完；四轮均 PASS/CLOSED、Runtime/HTTP 错误 0，各轮 7926 本地资源和 22 HTTP 身份检查通过。最后服务已关闭、4496 无监听、Chrome 无残留。

`g1-web-cpu-occids-abba.cjs` 实际核对 Runtime 字节、除目标模块外所有脚本、配置、32 个 RNG 尾值、全部初始/逐阶段 range 摘要与状态摘要、无包装和五夹具12阶段，结果 EQUIVALENT_RESULTS。其 8 个拒绝负控亦离线通过。原始证据分别在 `evidence/g1-web-cpu-occids-A1/`、`-B1/`、`-B2/`、`-A2/`。

稳定摘要为 `evidence/g1-web-cpu-occids-ABBA-summary.json`，包含逐次原始计时、等价检查项、四轮 CLOSED/错误0及 `REJECT_NO_TARGET_BENEFIT` 决策；可用同一比较命令加 `--out` 重建。生产文件与 CURRENT 未修改。

| 巨型车非 combat 单块 Flush | A1 ms | B1 ms | B2 ms | A2 ms | A均值 ms | B均值 ms |
| --- | --- | --- | --- | --- | --- | --- |
| part 1 | 26 | 26 | 29 | 26 | 26 | 27.5 |
| part 2 | 25 | 24 | 24 | 24 | 24.5 | 24 |
| part 3 | 26 | 26 | 26 | 26 | 26 | 26 |
| 三次合计 | 77 | 76 | 79 | 76 | 76.5 | 77.5 |

实测没有改善巨型车逐块破坏的主目标，不合生产。raceCar 三次均值 A 为 13/2.5/2 ms、B 为 12.5/2.5/2 ms；整数时钟与每变体两次样本不足以认定 0.5 ms 改善。巨型车 combat hullkill 的 A 为 19/21 ms、B 为 13/13 ms，但该 Flush 直接走 Die/Debris，不调用候选修改的 For 失效循环，不能据此宣传候选收益。额外集合会影响堆布局或 GC，当前证据未细分这个差异。

下一步应细拆 For 内部各 local 阶段，或把 MergeBoxes 的 sort 与 Key/Has 阶段分开测。不能从此次无收益候选推断全 7–8 ms 在签名字符串或几何采样，也不能直接合并猜测改法。

## 有效测量与当前结论

启动契约已修复：从源冻结逐字节复制真实 `dist/project.json`、`dist/1.0.0/project.json`，并让 latest/version/1.x.x 元数据统一指向派生 manifest。没有伪造 SDK 响应。全部 7926 本地资源尺寸、12 项固定 source/阻塞启动脚本、22 个实际 bootstrap HTTP 字节身份检查通过。两张未分组 review UI 图片未缓存，明确不属于本夹具 skip-login/non-review 首次 Web 启动的消费路径；不据此宣称完整 review 资源通过。

六车小场地结果 `evidence/g1-web-cpu-contract-profile/report.json` 为 PASS/CLOSED，Runtime/HTTP 错误均 0。60 预热步后采 120 个固定步，总 201 ms，平均 1.675 ms/六车步，单步中位 2/P95 3/最大 5 ms。独立 `verification.json` 重算全部 self 之和恰为 201 ms，调用数关系通过。

| scope | inclusive 总计 ms | self 总计 ms | 实际调用数 |
| --- | --- | --- | --- |
| Vehicle.Step | 190 | 77 | 720 |
| LegControl.Step | 76 | 36 | 240 |
| LegGait.Step | 27 | 17 | 240 |
| RaySuspension.Sample | 22 | 10 | 720 |
| Space.Raycast | 28 | 28 | 6311 |
| Space.Step | 10 | 10 | 120 |

父子包含，表内不可相加。13 静态体的小场地没有复现自然陨坑高开销，没有据它修改腿部算法或声称整场提速。

毁伤两轮 `evidence/g1-web-cpu-contract-damage/`、`evidence/g1-web-cpu-null-damage/` 均保留 FAIL/CLOSED。第一轮摘要不接受引擎 `cjson.null` 函数哨兵；只对此特定哨兵编码为 null 后，第二轮前四夹具的 10 个阶段均完成，11th 单桥断连后旧断言失败。Runtime/HTTP 错误为 0，失败原因是工具断言而非时间门禁。第二轮实际阶段墙钟：

| 夹具/阶段 | 零件变化 | Damage ms | Flush ms |
| --- | --- | --- | --- |
| raceCar 非 combat，单块 1/2/3 | 209→208→207→206 | 0/0/0 | 13/3/2 |
| raceCar 非 combat，core kill | 206→205，dead | 0 | 2 |
| raceCar combat，hull kill | 209，dead | 0 | 2 |
| megaMech 非 combat，单块 1/2/3 | 1611→1610→1609→1608 | 0/0/0 | 26/26/27 |
| megaMech 非 combat，core kill | 1608→1607，dead | 0 | 13 |
| megaMech combat，hull kill | 1611，dead | 0 | 18 |
| 单桥断连 | 7→2，alive、1 组 debris | 0 | 1 |

0 ms 是整数时钟分辨率下的结果，不表示免费。该旧无包装轮的最大已观察阶段是巨型车每次单块 Flush 的 26–27 ms，当时不能从总量直接判断子阶段。前四夹具数据保留，不作优化 A/B 或 FPS 证明；最新完整五夹具 profile 已通过，归因见文首。

单桥旧断言要求 7→2 后必须立即死亡、产生两组 debris；当前真实结果是剩余预算 1 不低于初始 6×WRECK_RATIO(.15)，所以应保留 core+cube 并存活。工具拆为“断连后 2 块、4 块碎片组、1 组 debris、预算仍高于阈值”和后续独立 core kill；最新运行两阶段均通过。未修改生产阈值。

## 内部归因范围与陨坑待测

damage 的 `mode=timing` 保留无包装；`mode=profile` 已离线加入 23 个真实导出方法范围：Blueprint.Graph/Connectivity、VehicleSpec.Build/BuildParts/MergeBoxes/Debris、CarUnit.DisposeVehicle/Build/Budget/LostCombatAbility、Vehicle.New/init/Dispose、WeaponSystem.New/init/Refit、Debris.Spawn、Space.Register/Unregister、Body.Wrap、TrackWorld.NewVehicle、Rotors.Spec、TurretRange.For。

每个初始构车和每次 Damage/Flush 分开重置计数，输出 inclusive/self/calls。逐阶段输出独立 chunk，后续失败也保留前面范围。profile 带包装扰动，只用于归因；不能与无包装 timing 相减宣称收益。离线假适配器验证了 23 范围、嵌套 self 守恒、nil 多返回值、Reset/Snapshot/Restore、timing 零包装，并验证仅 cjson.null 哨兵可编码、任意其他函数仍失败。真实内部 profile 已运行并通过，见文首。

另准备 `scenario=crater`：直接复用 `CraterWorld.New(scene,true)` 与 `CraterPhysics.Build`，构造阶段按 8 ms 预算让出真实 Update；同六车 T3 variant0、seed1016、同输入、每 Update 一步，出生坐标沿用 `perf-drive-sections-crater.lua`。冻结 JSON 离线点数是 100 地形块+1883 authored+81 boulder=2064 地图注册体，加六车为 2070；**真实引擎数量尚未运行确认**。运行时在六车创建前点数并核对各类总和，禁止把 2070 写成纯地图体数。此模式不跑 AI、武器、渲染/UI/音频，不是完整对局。`.tmp/g1-web-cpu-crater-ready/identity.json` 已准备但未运行。

## 首轮硬件结果

root 释放窗口后在 4495 运行。`evidence/g1-web-cpu-first-profile/`、`-b/` 先后因自动 `/favicon.ico` 404 被严格门禁判 FAIL/CLOSED，第二次已记录 console 实际 URL。专属服务随后只为该路径回 204，实际 HTTP 检查及服务请求日志均证实 204，没有忽略任何 Runtime/资源错误。

`evidence/g1-web-cpu-first-profile-c/` 进入 Web 引擎 bootstrap 后，登录入口 `ws://entrance-new-master.spark.xd.com:443/` 返回 `net::ERR_NETWORK_ACCESS_DENIED`，门禁 FAIL/CLOSED。引擎自身随后跳过登录并开始下载本地 manifest，但探针未开始，不能输出车辆 CPU 计时。未忽略该错误或把启动耗时当模拟热点。

root 批准最后一次 `-d/`。离线核实 WebRuntime.js 将 URL query 按 `&` 拆分、decodeURI 后传 Module.arguments，Native 既有工具使用精确 flag `-skip_login`。专属 runner 增加末尾 `&-skip_login`，并保存 launchUrl；实测 bootstrap 无 Login 网络请求，随后 engine-startup 的 UpdateProjectInfo 明确请求 `/game-dist/project.json`，派生 dist 无该文件，实际 HTTP404 被严格门禁判 FAIL/CLOSED。没有进入探针、没有任何有效计时，damage 未运行。服务与 runner 已停止，4495 拒绝连接，Chrome 无进程。本轮按止损不再重试启动；下轮先离线补齐派生 dist 的真实 project 元数据，不得伪造404成功或放宽资源错误门禁。

## 已知问题与本次目的

有效自然路线证据仍以 `evidence/performance-trial-sections-match-1792167434262/` 为准：1099 详细帧、1805 固定步、六车/五 AI，生产 Update 平均 14.833 ms/帧，其中六车 Vehicle.Step 为 4.894 ms/帧，物理 Step 为 1.693 ms/帧，Effects.Update 为 1.438 ms/帧，五 AI 为 1.139 ms/帧，HUD 为 0.819 ms/帧。这些父子范围重叠，不可相加。该路线未发生毁伤，不能签收击碎尖峰。

旧 Native 特效探针因 stderr 出现 `Failed to create bgfx dynamic vertex buffer`，全部性能计时判废。此前约 9.6% 收益已撤回，不能据旧 profile 认定 Quad 是确认热点。本次复用现有 Web Runtime，专门拆真实车辆模块和真实毁伤路径，避免继续为 Native 环境安装试错。

## 冻结与隔离

源冻结：`.tmp/outgame-cached-1792169432758/identity.json`，`manifest-f4293386.json`，542 Lua，指纹 `f10fd67d88c80fb9854f2bfc5f0a10aa49cb06ddc1e7bffb589cb317c5682bd4`。

`g1-web-cpu-prepare.cjs` 创建派生冻结，只替换其 main entry。原 main 不执行，App/Trial 不启动，没有正常玩法 AI、视口、音效或 UI 构建。未变资源采用硬链接，禁止覆盖；替换资源使用新 CRC32 文件名。源冻结与生产代码不动。可选 `--variant module/path.lua=candidate.lua` 仅替换派生冻结内的既有模块，用于之后锁定变量的对照。

已准备：

| 夹具 | 派生冻结 | 主入口 SHA-256 |
| --- | --- | --- |
| 最新毁伤 profile | `.tmp/g1-web-cpu-damage-sections-ready/identity.json` | `43ffbbcdf26838ff444ca96e4725349d2731b17217f5088c4f2667dd5d11b9b3` |

六车 profile 的有效身份以 `evidence/g1-web-cpu-contract-profile/report.json` 为准；早期 `*-bridge-ready` 派生目录缺少最终启动契约，不应直接用于复测。

## 测量范围

六车夹具复用 `perf-drive-sections-native.lua` 的固定六车、双队三级 assault/heavy/sniper、六条隔离车道、台阶/墙体和输入序列。每个真实 Update 仅执行一个 1/60 秒固定步：Vehicle.StepRotors、Vehicle.Step、Space.Step。先热身 60 步，再采样 120 步。该小场地只有 13 个静态物理体及六车，不含陨坑 2070 个物理体，不代表完整战斗场景规模。

- `timing`：不安装方法包装，仅计固定步墙钟。
- `profile`：14 个真实方法包装，包含车辆、步态、足部、悬挂、射线、Bullet。保留多返回值并输出 inclusive/self/calls；父子不相加。包装本身有扰动。
- `equivalence`：计时外逐步摘要状态、步态/命中框、射线输入/几何命中/逻辑 owner 和随机尾序列；用于之后候选行为对照，不能拿它报告真实 CPU 提速。

结果的 `expectedVehicleStepCalls` / `expectedPhysicsSteps` 是预期次数；profile scopes 的 `calls` 才是观测次数。整数毫秒墙钟包含调度、GC、绑定开销，不是线程 CPU 时间、画面 FPS 或手机性能。

毁伤夹具直接复用 `check-damage-native-timing.lua` 的真实 CarUnit.Damage/Flush、TrackWorld、Space、Debris：raceCar/megaMech 各非战斗和战斗四例；另复用 `check-destruction.lua` 与 `source-damage-fixtures.json` 的七块单桥例。分别计首次原生构车、Damage、Flush（连接图、重建/销毁原生车体、碎块生成）及 debris 到期释放。单桥断开 id=3 后检查两块残车、四块碎片组和仍高于当前瘫痪阈值；然后独立击毁 core，避免把普通单块移除或 hull kill 当断连验收。所有事件和逻辑状态在计时外摘要后清空。

不含 CombatView/GPU 特效上传、真实弹丸发射、HUD、声音、AI。真实 VehicleSpec/CarUnit/Debris 模块无替身，但这仍是隔离夹具。最新 Web profile 初始化及计时通过，完整战斗性能尚未据此验收。

## 离线验证

已运行：

```powershell
& 'C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' tools/migration/g1-web-cpu-selftest.py
```

通过 timing/profile/equivalence 调度、返回值、多帧 chunk、观测次数、状态/RNG、受控错误只发一次、Lua/JS 编译；另 16 项 chunk/结果负控通过。Lua54 的假原生适配器仅验证工具结构，测试中 7 ms 步长是人为时钟，不是性能证据。随后真实毁伤在 Web Runtime 完整运行通过，离线替身结果与真实耗时明确分开。

两个派生 manifest CRC32、实际入口 payload CRC32/SHA-256 和全部 542 个源冻结脚本 SHA-256，合计 544 项检查通过，确认源冻结未改。

## root 独占窗口执行命令

以下为最新已通过毁伤派生包的复测命令。服务与 runner 不与剧情/其他基准同时执行。runner 完成关闭专属 Chrome，记录 `shutdown=CLOSED` 后停止服务。

```powershell
node tools/migration/g1-web-cpu-serve.cjs .tmp/g1-web-cpu-damage-sections-ready/identity.json 4496
node tools/migration/g1-web-cpu-bootstrap-audit.cjs .tmp/g1-web-cpu-damage-sections-ready/identity.json http://127.0.0.1:4496 docs/migration/evidence/g1-web-cpu-sections-damage-retest/bootstrap-audit.json
node tools/migration/g1-web-cpu-run.cjs http://127.0.0.1:4496 docs/migration/evidence/g1-web-cpu-sections-damage-retest
```

第一行在服务终端运行，后两行在另一终端依次运行，重测证据目录必须使用新名称。任一 Runtime ERROR、HTTP 错误、OOM、缺 chunk、身份漂移或调用数不符即整轮 FAIL，保留原日志；不能放宽门禁凑结果。加载遮罩没有正常游戏关闭信号，可能保持显示，不影响 CPU 隔离测量，也不能据此验收游戏加载 UI。

独立重算已保存结果，不启动引擎：

```powershell
node tools/migration/g1-web-cpu-verify-damage.cjs docs/migration/evidence/g1-web-cpu-sections-damage/report.json
```

## 后续验收

先检查无错误的真实 profile / damage 分段，再选择一个占比明确的候选。之后锁同 Web Runtime 字节、资源、车辆、seed、输入和步数，完成状态/射线/RNG 等价及无包装交替对照。完整战斗、首用 shader 冻结、击杀 GPU/音效表现、845/TapTap 持续 30 FPS 仍是独立开放项。

## MergeBoxes 数字索引隔离候选（未实测收益）

真实局部 profile 中，1611 零件巨型车三次单块 Flush 为 26/26/27 ms，其中每次 MergeBoxes 为 6 ms，内部排序约 2–3 ms、扫盒约 3 ms。当前仅把扫盒时反复创建 `x..','..y..','..z` 字符串列为可测候选；这不是持续低帧归因，且扫盒内部仍包含多种操作，不能先认定字符串占完 3 ms。

`tools/migration/g1-web-cpu-merge-numeric-prepare.cjs` 生成独立 `VehicleSpec.lua`，纯整数规范坐标采用 `left[y][z][x]`，其他情况回退逐字保留的原 MergeBoxes。Lua 的 `1` 与 `1.0` 在原字符串键中不同，因此浮点整数、分数、非规范键、坐标别名、缺失质量均走回退。零质量合法；质量仍按原遍历顺序相加，不改变盒排序、扩张顺序、checkpoint、RNG 或输入对象。

离线真实完整模块验证 `evidence/g1-web-cpu-merge-numeric-offline.json` 为 PASS：83 种输入、3 次重复、249 次比较。覆盖负坐标、空输入、零/负/浮点质量、2 倍质量边界、稀疏连通区域、浮点/整数键别名、分数和非规范键。比较盒顺序、数值位与 Lua 数字子类型、输入不变、checkpoint 次序及 32 个 RNG 尾值。依赖使用离线适配器，不包含引擎或性能数据。首次通过后把测试中的每次 checkpoint 深比较输入改为调用前后全比较，降低离线重复成本；此轻量版本等待下一次允许 CPU 验证的窗口复跑。

生产文件未改，真实 Web A/B 尚未运行，未宣称提速。候选 SHA-256：`13cd41b0ce5756c179773094b0f94a57e8fb6fce520f9a2e2b6a9454789cb6ec`；原模块 SHA-256：`c11d04f77fc0899d5837cccc2db853be5d3bf560cbffe9c401aa582c0b4a7336`。root 调度真实浏览器独占窗口后再锁定同 fc1c 源冻结验证，不能与其他计时并跑。

### 已备 A/B 冻结，等待硬件窗口

两包均为 `mode=timing / scenario=damage / seed=1016`，同 fc1c 源冻结、同 542 Lua、同五毁伤夹具。离线身份核对只有 `drive/VehicleSpec.lua` 不同，主入口 SHA-256 同为 `d789627e3dc6af0245f07d714fe5eddfcd33dbe8e1011abf91f8e680c8d75437`。未启动服务、浏览器或 Runtime，未重跑 249 比较。

| 变体 | 身份 |
| --- | --- |
| A 原始 | `.tmp/g1-web-cpu-merge-numeric-A-timing/identity.json` |
| B 数字索引 | `.tmp/g1-web-cpu-merge-numeric-B-timing/identity.json` |

专用汇总器 `tools/migration/g1-web-cpu-merge-numeric-abba.cjs` 固定目标模块和上述两份 SHA，逐项比较 Runtime 字节、源冻结、probe、全部其他脚本、配置、初始/逐阶段 range、全部状态摘要、32 项随机尾序列和 12 条流式进度。每轮必须 PASS/CLOSED、Runtime/HTTP 错误 0、无 profile 包装。13 项负控通过，合成测试只校验门禁，不产生新性能结果。

root 放行后按 A1/B1/B2/A2 顺序，每轮使用独立证据目录；同一轮先开服务，再审计启动字节，最后跑 runner。runner 结束确认 CLOSED 后停止服务，确认窗口释放，才能开下一轮。例如 A1：

```powershell
node tools/migration/g1-web-cpu-serve.cjs .tmp/g1-web-cpu-merge-numeric-A-timing/identity.json 4496
node tools/migration/g1-web-cpu-bootstrap-audit.cjs .tmp/g1-web-cpu-merge-numeric-A-timing/identity.json http://127.0.0.1:4496 docs/migration/evidence/g1-web-cpu-merge-numeric-A1/bootstrap-audit.json
node tools/migration/g1-web-cpu-run.cjs http://127.0.0.1:4496 docs/migration/evidence/g1-web-cpu-merge-numeric-A1
```

B1/B2 将服务身份换成 B、证据目录分别换成 `g1-web-cpu-merge-numeric-B1` / `-B2`；A2 使用 A 身份与 `g1-web-cpu-merge-numeric-A2`。第一行运行在独立服务终端，不能直接在同一阻塞终端连贴三行。任一启动、字节、资源或行为门禁失败即停止整轮并保留证据，不以重试替换失败资料。

全部四轮成功后：

```powershell
node tools/migration/g1-web-cpu-merge-numeric-abba.cjs docs/migration/evidence/g1-web-cpu-merge-numeric-A1/report.json docs/migration/evidence/g1-web-cpu-merge-numeric-B1/report.json docs/migration/evidence/g1-web-cpu-merge-numeric-B2/report.json docs/migration/evidence/g1-web-cpu-merge-numeric-A2/report.json --out docs/migration/evidence/g1-web-cpu-merge-numeric-ABBA-summary.json
```

主目标仍为巨型车非战斗三次单块 Flush 总和。候选均值不低于原版则 `REJECT_NO_TARGET_BENEFIT`，拒绝生产合入；即使更低，也只是 `REQUIRES_MORE_VALIDATION`，不能宣称持续 FPS 或 845 真机达标。

## 8 车 102 分段：Vehicle.Step 子树归因（仅重算归档）

root 要求在其真实硬件测试期间只读分析。`tools/migration/g1-web-cpu-vehicle-owners.cjs` 从 `performance-trial-sections-match-1792173507902/drive-sections.jsonl` 重算输入后第 6–252 帧，共 247 帧，完整结果与原摘要逐项相等；原记录 CLOSED、测量 PASS、Runtime/HTTP 错误 0。每帧逐项验证 Vehicle 直接子树与腿部子树守恒，输出 `evidence/g1-web-cpu-vehicle-owners-102.json`。未运行浏览器、Runtime 或新性能测试。

Vehicle.Step 总 2315 ms / 4928 调用 / 247 帧 = **9.372 ms/帧**。616 固定步、每步 8 辆车；平均每整组 8 车步约 3.758 ms。以下是直接子树的 inclusive 数据，互不嵌套，合计 2103 ms，加 Vehicle.Step 未细分 self 212 ms 正好等于 2315 ms，247 帧分别守恒。

| Vehicle.Step 直接范围 | 总 ms | ms/帧 | 范围含义 |
| --- | ---: | ---: | --- |
| leg.Step | 773 | 3.130 | 最大直接子树，1232 调用 |
| suspension.Sample | 304 | 1.231 | 含支撑射线 |
| suspension.Apply | 264 | 1.069 | 现有最大独立命名终端范围，尚无内部细分 |
| hover.Step | 245 | .992 | 含悬浮射线 |
| contact.Step | 219 | .887 | 已有内部控制细段 |
| legHitboxes.Update | 139 | .563 | 尚无内部细分 |
| stability.Step | 89 | .360 | 含稳定支撑射线 |
| thruster.Step | 51 | .206 | 尚无内部细分 |
| hover.Motion | 17 | .069 | 无其他已包装下级 |
| wing.Step | 2 | .008 | 无其他已包装下级 |
| Vehicle.Step self | 212 | .858 | 函数自身和未包装调用，不能全叫数学运算 |

物理射线的全局 `physics.Raycast` 554 ms 不是全归车辆。依冻结实际调用结构，Sample、stability.Step、hover.Step 和 leg.Cast 的唯一已包装直接下级是 physics.Raycast，故它们 inclusive 减 self 分别 129/25/146/146 ms，共 446 ms（1.806 ms/帧），全局剩余 108 ms 在这些路径外。此为由现有 scope 和冻结调用结构重建，不是独立 caller trace；不能把全局 2.243 ms/帧再次加到上述父树。

### leg.Step 的真实 owner

leg.Step 773 ms 中，全部 `leg.* / gait.*` self 合计 627 ms，加 leg.Cast 内部射线 146 ms 正好 773 ms，逐帧也通过。最大现有未分段 owner 是 **leg.Step self 143 ms（.579 ms/帧）**；最大已有步态状态段是 **gait.swing self 109 ms（.441 ms/帧），inclusive 322 ms**。两者不能与其下级重复相加。

| 腿部 owner / 范围 | inclusive ms | self ms | 实际调用数 |
| --- | ---: | ---: | ---: |
| leg.Step | 773 | 143 | 1232 |
| gait.Step | 561 | 14 | 1232 |
| gait.swing | 322 | 109 | 3702 |
| gait.foothold | 207 | 23 | 2644 |
| leg.Cast | 188 | 42 | 24344 |
| leg.Clear | 133 | 66 | 2824 |
| gait.stance | 130 | 29 | 3926 |
| leg.Reachable | 104 | 96 | 7114 |
| gait.kinematics | 49 | 49 | 1232 |
| gait.finish | 26 | 13 | 1232 |
| leg.Target | 24 | 24 | 17330 |
| gait.init / phase | 12 / 7 | 12 / 7 | 1232 / 1232 |

free 7 次、1 ms inclusive / 0 ms self；plant 27 次、0 ms。0 表示毫秒分辨率下未积到整毫秒，不能称免费。

### 下一层只测什么

已有 `build-drive-sections-probe.cjs` 的 LegGait、ContactControl 分段可原样复用，不必再做一套泛化 102 包装。已量到 gait.swing 是步态最大内部 self；ContactControl 内部最大命名段是 telemetry 51 ms，其次 handling 30 ms，Contact.Step 尚有 self 60 ms 未归具体代码。不能根据行数或源码宣称某一运算已是瓶颈。

下一轮若继续归因，只应在已证实较大的范围增加定点计时：

- `suspension.Apply`：分别计第一遍支撑冲量、第二遍接触轴/冲量计算、第三遍施加轮胎冲量与转速；在第二/三遍内进一步把 body 原生方法聚合计数/耗时与 Lua 运算分开，保持先算后施加原顺序。
- `physics.Space:Raycast`：计 Ray/向量构造、真正 `world:Raycast` 原生调用、命中筛选及返回结构；按调用 owner 记录，避免全局混算。现有数字不能判定是原生查询还是 Lua 结果处理。
- `leg.Step self`：在 Gait.Step 之前按“姿态与输入/支撑采样/附着估计/支撑力/驱动力/跳跃”分段，在 Gait.Step 之后单独计 telemetry；这些是插段边界，尚无各段性能结果。
- 保留既有 gait.swing/foothold/Reachable/Clear 计时；仅再包 IK.Solve/IK.Reachable，才能区分 Reachable 的 self 96 ms 中有多少来自 IK，不能现在归因为 IK。
- `Vehicle.Step self`：拆前置姿态/帧组装与后置 telemetry 合并；`legHitboxes.Update` 另测 IK 与矩阵/包围盒阶段。二者目前只分别量到 212/139 ms 总范围。

最大调用 23–33 ms 出现在多个不同 owner，而其通常单帧中位在 0–2 ms。Vehicle.Step 单帧 inclusive 中位 7、P95 34 ms；有 20 帧出现某次调用 ≥10 ms，合计这些帧的 Vehicle inclusive 691 ms。Suspension.Apply 仅 3 帧出现调用 ≥10 ms，这三帧该 scope 合计 82 ms。计时包含包装、GC 与调度抢占，现有数据不能把这些尖峰全当算法 CPU 热点，也不能静态猜 845 长稳帧率或优化收益。

## 51f4 Apply / Raycast 定点包（准备完成，待 root 实测）

遵照 CURRENT 继续已测车辆热点，不再调整 MergeBoxes。读取 Lua 开发指南、物理碰撞示例、第三人称 Standalone 更新/射线示例、程序化天空 Update 示例后，复用现有 G1 真实六车陨坑夹具与 `perf-drive-sections-scope.lua` 的嵌套计时器。生产脚本无修改；只派生入口和两份被测模块。没有启动浏览器、Runtime 或服务。

身份：`.tmp/g1-web-cpu-support-51f4-profile/identity.json`，源 `.tmp/outgame-cached-1792174992428/identity.json` / `manifest-51f429df`。`mode=profile`、`scenario=crater`、seed1016、60 预热步、120 被测步、每实际 Update 一步。六车与陨坑生产碰撞直接复用；无 App/战斗 AI/开火/画面/音频/UI，不能拿它验收整场 FPS。

| 项目 | SHA-256 |
| --- | --- |
| 派生 main | `edf85466cb51f463761c88e6c5d7a488b5e84f27b80678ed7ad36752d1d5ce0c` |
| 独立 probe | `7b0e925232698ca6e31effab1fc4e21548942a1959f22af5a5b043799131be2b` |
| RaySuspension 原版 | `a18bc313a4eb2627a3ab1b964f43c4c443c74fbf5d5fabd860bfd31eff3f53e2` |
| RaySuspension 定点 | `d4b325932d0b63635b34a6d021163aa609f2b838897088a1cc0fcd3fb872ebd1` |
| Space 原版 | `232bc96cb65bea9bec926959c637e20a0716a0a9243c48bff1808ad18ec166da` |
| Space 定点 | `a23f6653acf15fd4d6b4a81b24b40cd1bc09ea412c4d4568afca62558b0b1570` |

`g1-web-cpu-support-identity.cjs` 独立检查 542 脚本的冻结来源、派生源码和实际 manifest payload SHA，验证 manifest CRC，精确只有 `main.lua`、`drive/RaySuspension.lua`、`physics/Space.lua` 三处脚本差异，0.25 秒完成 PASS。证据 `evidence/g1-web-cpu-support-identity.json`；这不是 HTTP 或实际 Runtime 验收。

### Scope 契约

保留现有 14 个 G1 coarse scopes，另外返回 `supportScopes`：

- `apply.support`：Apply 第一轮支撑冲量。
- `apply.contact`：第二轮计算全部接触轴、摩擦和制动冲量，尚未施加它们。
- `apply.impulses`：第三轮施加前向/侧向冲量、计算转速。
- `stability.Step` / `hover.Step`：增加这两处已有真实方法的粗范围，只为提供准确 caller 栈。
- `ray.<caller>.construct/native/filter`：向量/Ray 构造；原 `world:Raycast` 调用；筛选命中并创建原返回结构。caller 只允许 `suspension.Sample`、`leg.Cast`、`stability.Step`、`hover.Step`、`other`。caller 取最近实际已进入的支撑方法范围，不根据参数猜测；未观测 caller 可没有行，不能将其称为零成本。

真实语句、运算分组、分支、Raycast 参数、命中筛选、提前返回及三轮计算顺序不变。计时会带来包装、字符串标签、时钟与分配开销，profile 仅用来归因。没有对生产算法做任何优化，没有推算收益。

`g1-web-cpu-support-selftest.py` PASS：真实完整两模块与原版比较 32 种轮胎条件（0/1/4/16 轮、落地/悬空、驱动/制动、移动地面、转盘）及 400 组射线条件（排除自身、trigger、动态/kinematic、fixedOnly、owner 排除、空结果、无 body、已/未注册 body、0/default mask）。共 36105 断言，比较数值位/类型、返回、原生适配器调用次序、冲量日志、最终状态；同现有 G1 协程集成 60 步和嵌套 self 守恒通过。使用离线适配器与假时钟，不是 Bullet 或 CPU 时间。

`g1-web-cpu-support-gates-selftest.cjs` 的 13 项负控 PASS：重复/未知标签、阶段计数漂移、射线阶段漏配、self 不合法、父树不守恒、模块/probe 身份漂移、资源错误、错误场景及两个源锚漂移。独立 `g1-web-cpu-support-verify.cjs` 还强制每个 ray 恰归一个 caller、每 caller 三段调用数相等、Raycast inclusive = 自身 self + 全部 caller 阶段、Apply inclusive = 自身 self + 三循环、全部 self = 三个不重叠根范围之和，且总根不超过外层夹具时间。

### root 独占窗口命令

第一行单独作为服务进程运行。后续逐条执行，任一资源、身份或 Runtime 错误立即停止，不放宽门禁。证据目录已存在时使用新的目录名，保留失败记录。

```powershell
node tools/migration/g1-web-cpu-serve.cjs .tmp/g1-web-cpu-support-51f4-profile/identity.json 4496
node tools/migration/g1-web-cpu-bootstrap-audit.cjs .tmp/g1-web-cpu-support-51f4-profile/identity.json http://127.0.0.1:4496 docs/migration/evidence/g1-web-cpu-support-51f4/bootstrap-audit.json
node tools/migration/g1-web-cpu-run.cjs http://127.0.0.1:4496 docs/migration/evidence/g1-web-cpu-support-51f4
node tools/migration/g1-web-cpu-support-verify.cjs docs/migration/evidence/g1-web-cpu-support-51f4/report.json
```

runner 结束必须 CLOSED，停止服务并释放独占窗口；真实输出回来后才按各段实际 self/calls 选下一候选。当前仅关闭这份定点包的离线准备，真实归因、完整战斗及 845/TapTap 持续 30 FPS 仍未关闭。

## 51f4 支撑分段实际运行与资源准备修正

前节“待实测”已由本节更新。首次运行 `evidence/g1-web-cpu-support-51f4/report.json` 为 **FAIL/CLOSED**：初始化阶段 `HeightField.New` 打不开 `Crater/VisualHeight.bin`，没有进入被测循环，因此这轮没有任何 CPU 结论。原始失败文件保留，不能以重跑覆盖。

原因是测试夹具绕过正常 App/SceneLoader，直接构造 CraterWorld，漏掉下载准备。51f4 正式 manifest 中该文件正确映射为 `ELuksXngR79RiDAVDNowS5Dc-58379f80.bin`，1643544 字节，SHA-256 `077a8e26e54ffad47a634b52ed4e1a3aa10001938ab99bb3c8a2b1a8f1483b54`，与工作区正式资源字节一致。它没有 `#blocking` 分组，但正式 `DriveMaps.crater.resources=Crater/Resources.json` 清单含该文件，SceneLoader 在构造世界前用 ResourceGate 下载。首次 bootstrap 审计验证磁盘与启动文件，不能代替这段动态下载契约。

最小修正只在 support 探针加入同生产 `app.ResourceGate`：计时前请求该真实高度文件，跨 Update 推进旧绑定的完成查询，成功后校验文件长度与 VHF1 头。失败、超时、长度或头不符仍结束为 FAIL；没有伪造高度、缩小地图、改 manifest 分组或修改生产脚本。其余所需 JSON 已属于阻塞资源。异步完成后取消自有 gate；车辆初始化与测量保持原路径。

新派生身份 `.tmp/g1-web-cpu-support-51f4-preloaded/identity.json`，main SHA-256 `9e671fad507dbae82b0cf853d25dcc38d9d1367c0b85e6f2fa32cd47dc5c0709`，probe SHA-256 `5937101fe942d42bf653ee5694eb61dcbb700153357551e5cfc8894879a0d9d8`。两份被测模块 SHA 与前节一致，542 源脚本/实际 payload/manifest CRC 审计通过，仍只有 main、RaySuspension、Space 三处脚本差异。32 种悬挂加 400 组射线等价、36105 断言和 60 步假原生协程检查通过；新增异步预载回调检查及第 14 项“资源未就绪”负控通过。这些离线结果不是性能数据。

### 真实 Web 结果

证据 `evidence/g1-web-cpu-support-51f4-preloaded/`：`bootstrap-audit.json`、`height-http.json`、原始 `report.json`、独立重算 `verified.json`。Bootstrap 7926 个本地资源及 22 个启动 HTTP 身份 PASS，另高度资源 HTTP200、长度和 SHA 单独一致。Runtime/HTTP 错误 0，runner PASS/CLOSED，服务 4496 随后停止且无残留监听或专用 Chrome。用户 4471、普通 4500 服务和用户 Native 均未操作。

测试发生于 UTC 2026-10-16 18:41:22.962 至 18:41:52.126。Windows 上当时还存在用户 Native PID69116，约 1 GB WorkingSet；未确认其内部负载。故本轮与其他环境轮次不可直接相减宣称收益，全部计时也包含调度、GC 和包装开销。

真实陨坑 **2064 物理体 = 100 地形块 + 1883 作者碰撞 + 81 碎石**，cameraBodies=0，初始化1470ms（不计入测量）。6 车、60 预热步、120 个被测固定步；每实际 Update 只执行一组六车固定步。外层合计 **467ms**，平均 **3.892ms/步**，中位4/P95 4/P99 5/最大46ms，仅一被测步达到10ms。这里没有正常战斗、AI、开火、音效、HUD、场景绘制或补跑，不是整帧数据，不能换算实战 FPS 或 845 性能。

| 范围 | inclusive ms | self ms | calls |
| --- | ---: | ---: | ---: |
| Vehicle.Step | 292 | 62 | 720 |
| physics.Step | 170 | 167 | 120 |
| Vehicle.PostStep（包含于 physics.Step） | 3 | 3 | 720 |
| Vehicle.StepRotors | 0 | 0 | 720 |
| leg.Step | 90 | 15 | 240 |
| gait.Step | 50 | 15 | 240 |
| gait.Foothold | 25 | 1 | 278 |
| leg.Cast | 40 | 7 | 3372 |
| leg.Clear | 12 | 7 | 278 |
| leg.Reachable | 8 | 5 | 688 |
| leg.Target | 7 | 7 | 2406 |
| suspension.Sample | 51 | 16 | 720 |
| suspension.Apply | 68 | 3 | 720 |
| apply.support | 1 | 1 | 720 |
| apply.contact | 55 | 55 | 720 |
| apply.impulses | 9 | 9 | 720 |
| stability.Step | 14 | 5 | 480 |
| hover.Step | 7 | 7 | 720 |
| physics.Raycast | 77 | 23 | 7212 |

父子 inclusive 互相包含，不可把表中所有行相加。三个互斥根为 Vehicle.Step292 + StepRotors0 + physics.Step170 = **462ms**；全部28范围 self 总和也是462，外层未包5ms。Apply三段65+self3=68；Ray所有阶段54+self23=77，全部调用归属守恒。

| Ray 实际调用 owner | calls | construct ms | native ms | filter ms |
| --- | ---: | ---: | ---: | ---: |
| suspension.Sample | 3360 | 3 | 12 | 6 |
| leg.Cast | 3372 | 4 | 16 | 4 |
| stability.Step | 480 | 0 | 6 | 3 |
| 合计 | 7212 | 7 | 34 | 13 |

每个 caller 的三阶段 calls 相等，阶段均为终端 self。未观测到 hover 或 other caller，不应写成这些路径免费；本阵容无悬浮支撑。0ms只是整数时钟未积到1ms。

### 决策

本轮不能支持“射线筛选是主要稳定瓶颈”：其全部 Lua filter 只有13ms/120步，原生查询34ms/120步，构造7ms/120步，另23ms在 Raycast 方法、包装与未分段开销。即便有小幅优化，也不足以解释完整对局33ms以上的整帧时间，且包装扰动相对这些细段不可忽略。

Apply.contact 看似55ms，但其中**一次调用42ms，占76.4%**，余下719次合计13ms。最大外层步46ms与该尖峰一致。本轮只能定位“尖峰发生在接触计算范围”，不能据此判定是某条数学语句、原生方法、GC或外部抢占造成；不对这一范围盲改。没有新增生产优化候选，不再扩展硬件测试，后续交由低包装扰动的完整帧测量定位实战剩余预算。

复核已归档结果无需启动引擎：

```powershell
node tools/migration/g1-web-cpu-support-verify.cjs docs/migration/evidence/g1-web-cpu-support-51f4-preloaded/report.json
```

本节关闭 support 定点归因与夹具资源准备错误；完整实战长稳帧率、真实击毁压力、845/TapTap持续30FPS仍未通过。
