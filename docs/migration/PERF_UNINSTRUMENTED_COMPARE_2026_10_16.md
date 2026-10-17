# Web 关闭玩法监控后的匹配实测对比

日期：2026-10-16。原始结果保留，没有将旧 FAIL 改成 PASS。

本轮候选在这一次自然驾驶中有改善迹象，但不构成锁定场景的严格 A/B，不能证明整场优化比例，也不能排除反向回归。两次均未达到稳定 30 FPS 的验收条件；没有骁龙 845 / TapTap 真机持续性能证据。

## 原始证据与运行身份

| 项目 | 旧构建 | 新候选 |
| --- | --- | --- |
| 发布清单 | `manifest-c4d2c399.json` | `manifest-fb3e73b7.json` |
| 结果 | FAIL / CLOSED，驾驶测量已完成；返回大厅后 QA JSON 截断 | PASS / CLOSED，含返回大厅和释放检查 |
| 持续按住 W 和左键 | 30.099 秒 | 30.062 秒 |
| 有效帧窗口 / 帧样本数 | 51 / 626 | 56 / 719 |
| 有效窗口末次接收时间范围 | 输入后 1596–30085 ms | 输入后 1224–30049 ms |
| 驾驶起止状态之间完整 QA 快照 | 80，全部 trial / live | 83，全部 trial / live |

旧：[result.json](evidence/performance-uninstrumented-match-1792161914060/result.json)、[windows.json](evidence/performance-uninstrumented-match-1792161914060/windows.json)、[states.jsonl](evidence/performance-uninstrumented-match-1792161914060/states.jsonl)、[runtime.log](evidence/performance-uninstrumented-match-1792161914060/runtime.log)。

新：[result.json](evidence/performance-uninstrumented-match-1792162312741/result.json)、[windows.json](evidence/performance-uninstrumented-match-1792162312741/windows.json)、[states.jsonl](evidence/performance-uninstrumented-match-1792162312741/states.jsonl)、[runtime.log](evidence/performance-uninstrumented-match-1792162312741/runtime.log)。

两次 H5 基线均为 `2026-10-15` / `b276064942ae09c0227ec28d4cfda1d5ff006455`。QA probe SHA-256 相同：`7990067d0e6ff6b8c294de10b84884d40de0c747ab2e40744ba6b2ac9d2dc638`；生产 main.lua SHA-256 相同：`3b6d98b5b55bedff42732d656e7394526851a62f3817503a8047bf02265140b7`。

这是普通引擎 URL，通过仅 QA 服务的 `monitorDisabled=true` 模式给 Start 提供禁用参数。每个测量状态均直接观察到 `monitor.enabled=false`，`battleTiming.enabled=false`；无 `VOX_PERF` 记录、HTTP 错误或已识别的游戏 Lua / WASM 运行错误。QA app 方法计时封装、自动状态输出和 F8 仍存在开销，不能称为完全无观测的发布版基准。

## 帧窗口统计

F8 / 自动状态输出调用 FrameStats 后会清空上一段样本。两次均保留所有成功输出的窗口，排除第一个可能混入按键前帧的边界窗口。原始各窗口的 count / P50 / P95 / P99 / max 完整保存在各自 windows.json；没有将不同窗口的分位数合并成全局分位数。

下表“窗口 P50 的中位数”是对各窗口 P50 数值再取中位数，窗口等权；偶数个窗口取中间两项的算术平均。它不是全部帧样本的 P50，也不能换算成整局平均 FPS。

| 指标，毫秒 | 旧构建 | 新候选 |
| --- | ---: | ---: |
| 窗口 P50 的中位数 | 43.385 | 37.424 |
| 窗口 P95 的中位数 | 59.765 | 55.174 |
| 各窗口 P50 最小–最大 | 32.315–68.227 | 29.858–74.250 |
| 各窗口 P95 最小–最大 | 49.025–90.740 | 43.720–100.000 |
| 所有有效窗口中的最大单帧 | 90.740 | 100.000 |
| 窗口 max > 80 ms 的窗口数 | 5 / 51 | 2 / 56 |
| 窗口 P50 > 33.333 ms 的窗口数 | 49 / 51 | 46 / 56 |
| 窗口 P95 > 33.333 ms 的窗口数 | 51 / 51 | 56 / 56 |

旧窗口的 >80 ms 项为 index 1、2、5、11、16；新为 index 2、19。新候选最坏窗口 index 2：P50 74.250 ms，P95 / P99 / max 100.000 ms，接收于输入后 2082 ms。该现象必须保留，不能只报告多数窗口改善。

FrameStats 没有帧时长总和，不能从 count 和分位数恢复平均帧时长。也没有用浏览器 rAF 或接收时间推算引擎平均 FPS。窗口数量、样本数量和 >80 ms 窗口数量不能当作同一长度、同一轨迹下的全局掉帧率。

## 相同条件与实际差异

相同：桌面 Chrome / D3D11 ANGLE，1600×900 游戏视口，crater 地图、elimination 第一回合、第三人称相机初始距离 16.8304、yaw 0、pitch 6.8755；持续 W 和左键输入；六辆车，角色序列为玩家、蓝方 heavy / sniper、红方 assault / heavy / sniper。全程前台、未最小化、指针捕获；六车一直存活且满血，没有命中、击杀或零件减少。开始时玩家均约在 `(-15, 4.9995, -234.0005)`，初始相机位置差小于 0.001 米。

差异：

- 阵容没有锁定随机种子。名称不同，红方 heavy 零件数旧为 145、新为 143；全场总零件旧 941、新 939。其他角色的零件数量对应相同，但相同数量不证明蓝图、装备或行为参数完全一致。
- 起始 battle.time 旧 5.8833 秒、新 5.7833 秒；结束分别 35.5167、35.6500 秒。窗口不是严格相同模拟时刻的配对。
- 玩家最终位置旧 `(-51.365, -12.991, -7.641)`，新 `(-24.601, -12.999, -39.402)`；AI 终点也不同。主会话已查看两张 after-drive 截图，确认墙体遮挡和终点不同。渲染工作不等价：有效窗口批次范围旧 1397–1913、新 1262–1745；三角形范围旧 639–941 万、新 653–910 万。
- 玩家发射计数从 0 增到旧 771、新 777；两次命中和击杀均为 0。这覆盖持续发射、驾驶和六车更新，未覆盖真实交火命中、破坏、死亡、重生、更多车辆或长时间运行。
- 候选同时包含多个脚本变化：LoadingFlow、WeaponSystem、CollectionCycle、PerformanceBindings、CommsCard、LoadingPage、HangarFxWarmup、TutorialFirstLine、CommsWarmup。不能把差值单独归因于武器、GC 或预热中的某一项。监控禁用时 PerformanceBindings 不会挂接玩法监控，但其他实际路径是否贡献必须另测。

## 旧 FAIL 的证据边界

旧测量中的窗口和状态均完整，驾驶检查全部通过。唯一失败为 runtime.log 第 2809 行：`22:49:00.412`，LoadingFlow Closed 后的大厅 OUTGAME_STATE 在 `garage.cards:[[0,0,` 处结束，10859 字节，JSON 不完整。该行是日志末尾；仅凭这份日志无法判断截断发生在引擎日志、WASM 桥还是控制台传输层。

坏行之前已有完整大厅状态，最后完整 sequence 338 的 trial 为 disposed=true，scene / world / effects / view / hud 全 false。不过旧工具当时已因坏行停止，没有完成后续全部验收，因此保留原 FAIL，不能补写成返回检查通过。

工具现已把这类问题单独记录为 probeIssues：测量期间任何截断仍失败；测量外只有后续完整状态恢复且全部检查通过才能通过。两次原始 result.json 未重写。新候选本次没有依赖这一恢复逻辑获得 PASS。

## 能支持与不能支持的结论

能支持：本次新候选的窗口 P50 / P95 中位数更低，超过 80 ms 的窗口更少；实际匹配进场、持续操作和返回释放完整走通。旧驾驶测量可与新样本作探索性对照。

不能支持：严格的整场提升百分比、全局 FPS / P95、单项修改收益，或“没有回归”。新候选最坏帧更慢，且车辆配置、实际轨迹、遮挡、时间点、输出窗口数量不同；单轮顺序运行也不能排除机器负载和缓存差异。需要锁定相同车辆蓝图、初始状态、随机种子和可复现路线后重复交错对照，才能判断改善能否稳定复现。

不能标记骁龙 845 / TapTap 长时间稳定 30 FPS 已通过。即使这台桌面上，新候选 46 / 56 个窗口的 P50 超过 33.333 ms，全部窗口的 P95 超过预算。下一轮优先定位新候选约第 2 秒的 100 ms 窗口，并覆盖真实交火破坏；真机持续帧时间、温升和降频验收仍待进行。
