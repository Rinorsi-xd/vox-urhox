# 2026-10-16 武器固定步实测与弹丸推进候选

接续 `CURRENT_EXECUTION.md` / `PERF_TARGETED_2026_10_16.md`。匹配实测中 `weapons.Step` self约1.87ms/帧，不能仅凭源码猜测，先在Native真实模块中拆段。本报告不修改60Hz、射线数量、武器规则、视觉、车数或随机顺序。

## 测量对象和边界

- 生产模块：`scripts/combat/WeaponSystem.lua`，由 `BattleController:BeforeStep()` 按车调用。
- beta40 Native headless，真实当前项目模块/蓝图/武器资源，隔离scripts快照。使用Native Bullet静态宽墙目标，实际执行Space.Raycast；记录命中输出，未执行真实车辆积分或伤害破坏。
- 六T3真实竞技预制：蓝/红各assault、heavy、sniper，对应laser3、mg3、sniper3各两件；另测17种全阶武器。
- 固定种子16102026、每步1/60秒、确定性移动瞄准和开火/停火周期。计时先预热600步，再执行12000步。
- 方法包装使用整数毫秒时钟累计，包装本身有开销。分段仅用于选择热点；收益必须另测无包装循环。包含子段的数字不能相加。
- 无AI、车辆悬挂/动力学、渲染、音频、HUD、地图复杂碰撞或真实伤害。钻头保持未按下，仅覆盖其闲置固定步。不能称完整战斗或845/TapTap帧率验收。

## 先测后改：原版方法拆段

首轮 `perf-weapons-profile-2026-10-16/baseline.json`，六车不开火总787ms，开火总2712ms。开火时Integrate累计1780ms、Aim383ms，是最大两个阶段。

第二轮 `perf-weapons-profile-split-2026-10-16/baseline.json` 额外包住环境回调以扣除物理查询：

| 场景 | 全循环 | Integrate包含回调 / self | Aim | 环境回调累计 |
|---|---:|---:|---:|---:|
| 六车不开火 | 825ms | 15 / 15ms | 426ms | 0ms |
| 六车开火 | 3185ms | 2187 / 996ms | 398ms | 1214ms |
| 17种全阶武器开火 | 5361ms | 3002 / 1437ms | 814ms | 1610ms |

六车开火记录836991次真实射线、6068发射击、2279次命中输出；17种武器1217546次射线。环境累计含少量Beam等调用，不与Integrate self直接作精确分解。第二轮总耗时比第一轮增加也说明计时包装不能当作无监控性能。

## 生产候选

只修改 `WeaponSystem:Integrate()`：原先每弹每步先生成位移表，再调用Length/Dot/Scale/Add；候选将位移保存在三个局部数字中，保持原来的乘法、加法分组、平方根及倒数计算，直接创建方向和新位置。

每次推进减少一个临时位移表及对应Lua函数派发。方向表、新位置表仍独立创建，避免环境回调或特效持有旧表后被改写。导弹Curve、射线长度与顺序、命中参数、遍历/移除顺序、冷却/能量/RNG规则保持原样。

## 验证记录

- `verify-weapons-integrate.py`：实际Lua5.4加载修改前/后WeaponSystem和Math3，18场景精确二进制数值、输出、顺序和位置别名检查PASS。覆盖dt0/1:60/.1、零/极小速度、killHeight、寿命过期、金属/地面命中；该边界夹具不覆盖导弹。
- Native逐步完整系统状态、射线/命中/冲量/爆炸摘要、600步间隔原始快照及后续32个随机数对照44项PASS。三场景各2400步，六车开火159055次射线、1130发/421次命中；全阶场景253265次射线、2085发/963次命中输出、2097次冲量、100次爆炸。全阶等价夹具显式在600步周期启动导弹齐射，覆盖其真实Curve/Blast；不是自然锁定成功或实战玩法验收。
- 六车不开火没有弹丸；等价运行的摘要本身耗时较大，不用于性能比较。

## 无包装ABBA结果

同一隔离依赖、四个串行Native进程，顺序原版/候选/候选/原版；每场景600步预热、12000步计时。该阶段没有方法包装，也没有逐步状态/事件摘要工作。四轮射线、射击、命中、冲量计数与RNG尾序列一致，Runtime/探针SHA和两侧WeaponSystem SHA已校验。

| 场景 | 原版两轮总ms | 候选两轮总ms | 原版 / 候选均值 | 均值变化 |
|---|---|---|---|---|
| 六车不开火 | 397 / 408 | 420 / 427 | 402.5 / 423.5ms | +5.2% |
| 六车开火 | 2165 / 2131 | 2085 / 1991 | 2148 / 2038ms | -5.1% |
| 17种全阶武器开火 | 3958 / 3760 | 3916 / 3612 | 3859 / 3764ms | -2.5% |

六车开火两轮候选均低于两轮原版，但幅度不大；无弹丸对照也出现约5%波动，该场景没有执行本次修改路径，反映热机/调度和共享机器噪声。17种计时场景没有显式启动导弹，其完整飞行只由前述等价场景覆盖。结论限于减少临时分配并在该开火夹具观察到小幅下降，**未证明整场持续FPS提升或稳定30FPS**，不把原生约0.18ms/六车武器步直接外推为Web1.9ms阶段或手机性能。

成功运行PID57608、66152、48976、70172、58104、47376、66740、43456均已退出并用Get-Process逐PID复查；失败启动PID65496单独终止。CPU计时窗口已释放，无本agent残留Native/GPU进程。PowerShell部分运行的ExitCode不可用，process sidecar如实为null；均要求WaitForExit完成、新鲜PASS输出、mode/label/seed身份匹配，并独立确认进程不存在，未捏造exit0。

首个候选Native启动失败：runner接受相对Snapshot后在工作目录内重复解析tapcode_dir，探针未加载；仅终止本轮自建PID65496，错误日志保留为 `candidate-1`，不作等价或性能数据。runner已用Resolve-Path归一化绝对目录，新label重跑。

证据完整归档在 `evidence/perf-weapons-2026-10-16/`，包括before原版、候选文件、两轮拆段、完整等价结果及失败启动日志、ABBA结果、Runtime/模块/探针SHA和进程sidecar。`equivalence-verification.json`包含44项精确比较与无包装计时汇总。

## 重跑入口

`tools/migration/perf-weapons-run.ps1` 生成隔离快照，记录Runtime/探针/WeaponSystem SHA、参数、PID及退出情况；不会覆盖已有结果。`-Mode profile`用于拆段，`-Mode equivalence`用于逐步摘要，`-Mode benchmark`用于无包装计时。已有Snapshot必须指向同一冻结依赖；通过 `-WeaponFile` 选择归档原版或候选。仅新建并结束自己的Native进程，其他用户运行实例不终止。

`tools/migration/perf-weapons-compare.py` 比较两份Native等价结果及进程/探针身份；`tools/migration/verify-weapons-integrate.py` 重跑18个边界场景。正式FPS仍以不带监控的完整同场景A/B及最终845/TapTap持续真机实测为准。
