# 监控整套包装开销：既有证据与下一对照设计

状态：设计，未生成新运行工具、未跑硬件、未改生产。root串行拥有硬件。base仍为 `.tmp/outgame-cached-1792206583227/identity.json` / 0baeef97，真实八车入口派生自 `.tmp/monitor-combat-heightfield-0bae-a/identity.json` / 8f3e398d；H5 b276064942ae09c0227ec28d4cfda1d5ff006455、UrhoX target f94827b26fc12b707e6d6904d093e16358caaf41。

## 先前是否已测完

没有当前构建真实八车的监控on/off matched结果，不能用旧报告免验，也不能把本次Finalize约0.2ms当作整套监控成本。

- `PERFORMANCE_MONITOR_2026_10_16.md`：旧Native六车/Bullet平地、固定seed、180预热/1200计时步，无AI/地图/开火/渲染。disabled1875/1179ms，enabled1639/1429ms，方向反转，未含Web落盘/UI/控制台传输，不能确定当前真实八车扰动。
- `PERF_UNINSTRUMENTED_COMPARE_2026_10_16.md`：旧新两个候选均关闭监控，roster、轨迹、遮挡不一致；不是开关对照。
- `PERF_DRIVE_WEB_SECTIONS_2026_10_16.md`：3000次direct/disabled/active合成校准只验证工具，不能机械扣除真实包装开销。
- 当前CDP包含统计采样和204MB详细trace，不可拿本轮43.256ms对普通35.086ms计算监控开销。

当前 `Monitor.Begin` 已按thread/depth复用关闭后的token。仍活动或yield的scope另持token，首次出现的stack/stage也需创建；不能未经测试便把malloc/free9%解释为“每次Wrap都创建token”。`Bindings.Attach`每帧仍遍历绑定，`Begin/End`执行时钟、协程栈、统计及边界，需一起量。监控还包含Finalize、Context、panel、JSON和传输，归因时应分开。

## 最小三态

所有变体生产549 Lua、资源、实际八车模块一致，只在冻结副本的QA main后缀做一次性控制；不改scripts，不新增每方法或每射线计时包装，不启用CDP、heap扫描或强制GC。

| 状态 | 执行内容 | 能回答的问题 |
| --- | --- | --- |
| A 默认on | 原完整Monitor、Bindings.Attach、生产wrapper、日志 | 当前实际诊断负担 |
| B 无Bindings包装、核心on | 开始Start前仅在隔离后缀将Attach置为无动作；保留Monitor与main已有顶层scope | Attach遍历及其全部动态wrapper与统计的合计影响 |
| C 全off | 原已支持`-vox-perf=0`，从Start开始不装包装 | 完整监控系统与实际关闭监控版本的差异 |

A-B不单独等于函数调用跳转的纯成本：绑定scope数会影响stage数组、JSON体积和panel内容；它量的是整套Bindings观测贡献。A-C还包含Context、panel、Finalize/Emit、日志传输等。若需再隔离panel，应独立同状态F6隐藏后再测，不在首轮增加第四变量。

仅在中途写enabled=false会保留已装的wrapper分支，不能冒充C的“从未安装wrapper”。`Dispose`后重新New会改变弱表、已缓存函数和panel生命周期，不采用这一捷径。A/B/C应各自新进程，从同一冻结入口开始。

## 真正锁定什么

现有8车F11工具不可直接复用为matched开关实验：它assert监控为true，parts/帧提交依赖Context，配置中的seed1016不是当前实际Matchmaker seed；真实Matchmaker默认使用os.time与math.random。F11仅移动车辆，不重建已跑过的AI、武器和随机状态。

最少需在测量外处理以下事项，做不成就不得称matched：

1. 使用一次性入口控制固定Matchmaker显式seed，冻结同一内存profile；序列化完整roster/member（含variant、aimSkill、reaction、avatar、seed）、玩家蓝图、每车source和装配哈希。既有store读值必须一致，不写真实用户数据。一次性Find控制应在捕获前恢复，测量循环中不存在此wrapper。
2. 复用原安全地形/静态碰撞检查得到相同F11八车位置与朝向，并校验速度、HP、零件数、AI初始化状态、武器状态、rules/world time、fixedSteps和accumulator。不能只验证车型名称与parts数量。优先在首次active固定步前锁入口；若已有预跑，必须说明并以真实状态门禁拒绝不一致，不能将F11后数据强行视为相同。
3. 相同视口、画质、音频、前台、缓存策略与鼠标输入。控制所有候选使用相同已冻结包，不重新从有并行修改的生产目录生成。
4. 保留原固定60Hz、真实AI、开火、命中、破坏、重生及FX，不删特效、不降低敌车数。自然渲染帧数不同会改变部分FX随机消耗，也会改变累积步进时序；所以端点同seed仍不能保证整个45秒轨迹完全等价。

## 数据与门禁

继续使用现有QA main里Update/EndFrame控制边界。记录连续引擎frameId、整数墙钟间隔、固定步增量、shots/hits/damage/kills与parts、alive计数；保留相同观察器负担，不新增每帧额外函数包装。序列化和state dump放在输入窗外。A/B/C的同窗原始工作量逐帧保存，时钟与计数来源都写清。

关闭后的生产分段无法继续存在：C下StageRows/Context等数据应明确unavailable，而不是0ms；不能为保留漂亮分段再给C装等价wrapper。A保留既有生产分段，B保留实际仍执行的main顶层分段，比较的共同底数是上述原始帧与工作计数。当前三粗wrapper在所有变体保持相同安装策略，C中未被调用不创建假行；parts来源需要独立同成本采样，不能继续依赖已停用Context。

顺序建议先A/B/B/A，必要时再C/A/A/C；每轮45秒实际交火。前台/运行HTTP错误0、原始传输完整、所有进程CLOSED、真实正伤害/结构损失、roster和开窗状态相同才保留结果。采样和导出时间不混用。

结果同时给完整帧分布、总固定步、每1000固定步墙钟、开火/命中/伤损/重生计数、活车与FX工作量范围。若轨迹/工作量明显分离，结果只能是受控入口的配对探索，不能算单一wrapper收益百分比。要给确定模拟CPU开销，必须另做同样实际模块的正常GC固定步CPU基准，保证逐步状态与RNG相等；这与真实全系统FPS验收分别报告。

## 决策边界

本轮先完成该设计审阅，再准备工具和离线负控。未建立共同观察边界、真实roster冻结及状态一致性门禁前，不安排一轮“看起来一样”的on/off随机实战。

若B/C有重复且可解释的收益，优先调整监控部署/采样策略后再同包复测；它是监控成本问题，不自动证明车辆算法已快。若无明确收益，保留malloc/free实际热点与无符号9978/3264/909，交确切Runtime符号化并继续定位调用者。不能继续猜Lua GC或把CPU主线程成本改称GPU。
