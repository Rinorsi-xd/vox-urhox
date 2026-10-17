# G1 车辆剩余热点：分段诊断

状态：隔离探针、离线等价检查、平地诊断及真实陨坑六次 Native 运行完成，**尚无已验证优化候选或收益结论**。生产文件未修改；fb3仍为主线冻结包。

## 选择依据

最新fb3匹配753个live帧，Vehicle.Step平均8.919ms包含其子段；已测步态self1.863ms、接地控制self0.950ms。悬挂和腿命中盒已有独立优化，本线不重复。scope是墙钟，不是精确线程CPU；车辆不能与步态、接地子项相加。先拆步态/接地内部实际耗时，再选择改动。

已核对当前LegControl与fb3实际身份一致：`3143b567c0e7ef66a359d50aa7640f79641b739d0a18fcc4717fb65cd47b28d5`。其Target标量化、IK缓存已在当前基线，不算本线新优化。

## 工具与边界

`tools/migration/perf-drive-sections.py`只复制当前540份Lua到独立快照，记录每份SHA，保留原始LegGait/ContactControl与生成的分段版本。场地资源通过junction引用当前assets，没有回退旧提交、旧包或改写生产脚本。

步态阶段：初始化、腾空、运动学、步频相位、stance、swing、free、plant、finish。真实Foothold和其内部LegControl.Cast/Clear/Reachable/Target另用子scope计时。接地阶段：输入/接触计数、载荷分配、转向/摩擦、各轮驱动/刹车/舵角、侧向稳定力、阻尼、触底支撑、遥测。原算法、分支、调用次序、60Hz与射线数量不变。

离线测试直接加载真实LegGait、ContactControl、Math3，使用合成地面/墙壁、可控ray/body边界和假时钟。720个步态步、448个接地步逐字段与调用/施力顺序等价，共274002次标量比较通过；覆盖全部19个scope。修改步频、修改轮力、漏关闭scope三个负控均被拒绝。它不等于真实Bullet运动验收，也没有任何性能测量意义。证据：`evidence/drive-sections-offline.json`。

Native探针准备使用六辆真实T3车、平地/台阶/墙、180步预热+2400步诊断，记录车辆/腿状态/命中盒20个时间快照、调用数及RNG尾部。`perf-drive-sections-compare.py`必须先确认基线与分段行为一致，再查看各段self。分段计时会引入包装/时钟开销，整数毫秒有精度限制，**不得用分段版与无分段版总时长计算优化收益**。选出候选后另做关闭分段的ABBA和逐步等价验证。

## Native 实测结果

使用 `0.9.0-beta.40_20261015.121839.6dc5c357cced` Runtime，六辆真实 T3 车，平地/台阶/墙，180 步预热、2400 个固定模拟步。原始版 PID 42304、分段版 PID 4380 均正常退出，状态 PASS。无 AI、开火、渲染、音频和 UI；本探针没有陨坑的 2070 个碰撞体，不能直接替代完整战斗。

原始版总墙钟 2113 ms，约 0.8804 ms/模拟步。分段版总墙钟 2510 ms；增加的时钟/包装开销不能解释为优化收益或退化。基线与分段版 20 组深冻结状态快照、RNG 尾部完全一致；调用数也一致：vehicle/contact 各 15480 次、gait 5160 次、raycast 131763 次、physics 2580 次、foothold 2765 次（包括预热）。

分段计时只统计 2400 个测量步，主要结果如下。`self` 已扣除本探针计时的子 scope，未计时的引擎调用仍包含在所属段内。下表各段不是完整游戏成本。

| 分段 | 总墙钟 ms | self ms | self ms/模拟步 |
| --- | ---: | ---: | ---: |
| ContactControl.Step（父段） | 349 | 65 | 0.02708 |
| 遥测 contact.telemetry | 76 | 76 | 0.03167 |
| 步态运动学 gait.kinematics | 55 | 55 | 0.02292 |
| LegControl.Target | 49 | 49 | 0.02042 |
| 落足 gait.plant | 62 | 47 | 0.01958 |
| 转向 contact.steering | 44 | 44 | 0.01833 |
| 操纵稳定 contact.handling | 43 | 43 | 0.01792 |
| 各轮命令 contact.wheelCommands | 36 | 36 | 0.01500 |
| LegGait.Step（父段） | 372 | 24 | 0.01000 |

步态父段含子项约 0.155 ms/模拟步，接地父段含子项约 0.145 ms/模拟步。整数毫秒时钟与新增 scope 调用会影响很短的分段，不能把数十微秒排序视为稳定的精确优先级。**这个小型 Native 探针未复现 Web 完整战斗中的车辆耗时，不支持直接重写遥测或步态算法。** 下一步应在相同 Web 完整场地/车辆/输入下使用这些分段，或先在原生探针加载相同陨坑碰撞规模，区分平台、场地和运行循环的影响。

证据位于 `.tmp/perf-drive-sections-20261016-ready/`：`baseline-1.json`、`sections-1.json`、对应 launch/stdout/stderr 记录和 `source-identity.json`。`perf-drive-sections-compare.py` 输出 `PASS_BEHAVIOR_COMPARISON`。

## 真实陨坑补测

复用生产 `CraterWorld.New`、`CraterPhysics.Build`、`CarUnit`、`EnemyDriver`、`WeaponSystem` 与 `Space`，得到 **2064 个地图物理体 + 6 辆车 = 2070 个物理体**。六车为蓝红各 T3 assault/heavy/sniper、variant0，共 870 个零件，在历史 scale-test 使用的南侧交火区摆放。驾驶输入来自六个真实 AI，开火组使用真实世界射线、伤害和破坏；无开火组仅抑制扳机。没有加载画面、音频、UI、对局目标/基地盾/回合规则，也没有固定步追赶循环；每次显式推进一个 1/60 秒模拟步。

这**不是** Web fb3 的同一阵容或输入：`performance-uninstrumented-match-1792163190043/result.json.beforeDrive.state.battle.units` 记录玩家 209 零件、蓝 heavy143/sniper152、红 assault140/heavy145/sniper152，共 941 零件；出生坐标约 ±234。这里玩家被 variant0 assault 替代，红 heavy 也不同，且六车都用 AI，在交火区而非出生坪运行。只能归因本探针内成本，不能把 Native 与 Web 的差值全算为平台开销。

每次预热 120 步、测量 600 步。无分段版仍保留计数器及五次深冻结快照，用于等价检查；并非零开销的整场性能基准。结果如下：

| 运行 | PID（均已退出） | 总墙钟 ms | ms/模拟步 | 存活车数 |
| --- | ---: | ---: | ---: | --- |
| AI，不开火，原始版 1 | 20744 | 1692 | 2.8200 | 始终 6 |
| AI，不开火，分段版 | 46784 | 1981 | 3.3017 | 始终 6 |
| AI，开火，原始版 | 66732 | 1852 | 3.0867 | 始终 6 |
| AI，开火，分段版 | 47024 | 2108 | 3.5133 | 始终 6 |
| 关闭 AI、停住、不开火，原始版 | 63236 | 1190 | 1.9833 | 始终 6 |
| AI，不开火，原始版 2 | 65920 | 1685 | 2.8083 | 始终 6 |

两组原始版/分段版、两次无开火原始版的五个快照、RNG 尾部、全调用数、阵容、物理体及逐步存活车数完全一致，三组比较 PASS。开火两次都记录 381 发（含预热），测量窗发生一次 `unit.Build`，说明伤害重建路径确实执行；没有发生死亡或复活，不能宣称覆盖死亡碎块峰值。地图初始化耗时 659–713 ms，位于测量循环前；这不是生产加载页实际冻结时长。

下面是两个分段版的每模拟步耗时。父段含其子项，**同列不能直接相加**；例如 AI、武器都包含各自调用的 world/vehicle ray。

| 分段 | 不开火 inclusive ms/步 | 开火 inclusive ms/步 | 不开火 self ms/步 | 开火 self ms/步 |
| --- | ---: | ---: | ---: | ---: |
| 六车 Vehicle.Step | 1.7200 | 1.6450 | 0.0967 | 0.1167 |
| 六车 AI.Step | 0.8150 | 0.7083 | 0.2050 | 0.2233 |
| 六车 Weapons.Step | 0.1017 | 0.4200 | 0.0383 | 0.0400 |
| Bullet Space.Step | 0.5483 | 0.5650 | 0.5483 | 0.5650 |
| Space.Raycast | 0.5600 | 0.4600 | 0.5600 | 0.4600 |
| VehicleRay.Cast | 0.2083 | 0.4600 | 0.2083 | 0.4600 |
| 两台腿车 LegControl.Step | 0.6883 | 0.6400 | 0.1733 | 0.1567 |
| LegGait.Step | 0.4267 | 0.3717 | 0.0133 | 0.0117 |
| ContactControl.Step | 0.1750 | 0.1500 | 0.0100 | 0.0300 |

本探针里较大的最底层成本是物理积分、空间射线、车辆命中检测及悬挂施力。开火时 `VehicleRay.Cast` 调用数从测量窗 18550 增至 30630；不开火时 AI 可见性检测也使用车辆命中检测，所以它不是仅在开枪时运行。不能把两行差值当成单项算法成本，因为开火会改变姿态、伤害与 AI 轨迹。

开启分段后整个 simulation.Step 最大为不开火 15 ms、开火 16 ms，未复现生产 Web 的 80 ms 以上长帧；这只说明此 Native 无渲染探针没有复现。现有数据支持下一轮在**相同 Web 完整对局**记录这些细分，并与渲染/着色器首用、固定步次数一起对齐；不支持继续凭静态分析重写步态/接地控制，更不证明骁龙 845 TapTap 持续 30 FPS 达标。关闭 AI 组同时使车停下、改变射线和步态工作量，不能用其与 AI 组的差值直接断言 AI 自身成本。

归档：`evidence/drive-sections-crater-20261016/summary.json`（六次原始 JSON、启动参数/Runtime SHA、stdout/stderr、源码身份和生成变体均一并保存）。`perf-drive-sections-summarize.py` 重新验证三组等价和六次物理体/存活车数，并记录归档时地图资源 SHA。所有进程已退出，未更改生产脚本、未提交或推送 Git。

## 重跑命令

离线验证（Python环境需有Lupa 2.8 / Lua5.4）：

```powershell
python tools/migration/verify-drive-sections.py
```

已运行快照：`.tmp/perf-drive-sections-20261016-ready`。源码与原始/分段/探针变体均记录SHA；更早的仅准备目录保留，不作为已运行证据。下面Native命令只在主线明确释放硬件时间窗后运行；重跑需更换 label，以保留原始输出：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/migration/perf-drive-sections-run.ps1 -Mode baseline -Label baseline-2
powershell -NoProfile -ExecutionPolicy Bypass -File tools/migration/perf-drive-sections-run.ps1 -Mode sections -Label sections-2
python tools/migration/perf-drive-sections-compare.py .tmp/perf-drive-sections-20261016-ready/baseline-1.json .tmp/perf-drive-sections-20261016-ready/sections-1.json
```

未开始车辆候选ABBA，未降低车数、模拟频率、碰撞/射线精度或表现，不宣称Web或骁龙845在TapTap内达标。
