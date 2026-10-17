# BeforeStep 下一步目标：腿摆动临时分配

本次仅短时离线读取已归档数据，未启动Runtime、浏览器或持续诊断进程；未修改生产。主线正在验证VehicleRay静态bounds候选，本报告不重复该路线。

## 当前实测进一步缩小的范围

使用`monitor-combat-4a3a-1017-a`原始1,338帧，沿已核engine=monitor+1011映射，对已存在的stageTimes重算。以下为所有车辆合计的整数墙钟，包含子项；每次调用均值不具有1ms以下单次精度，仅是累计时间除调用数。

| BeforeStep内部已测范围 | ms/帧 | 调用数 | 累计ms/调用 | 帧累计P95 / 最大ms |
| --- | ---: | ---: | ---: | ---: |
| vehicle.Step | 5.4141 | 19,113 | 0.3790 | 10 / 51 |
| ai.Step | 1.9447 | 16,833 | 0.1546 | 9 / 46 |
| weapons.Step | 1.4297 | 19,113 | 0.1001 | 3 / 46 |
| legs.Step | 1.2818 | 4,507 | 0.3805 | 3 / 41 |
| suspension.Sample | 0.8363 | 19,228 | 0.0582 | 2 / 47 |
| legGait.Step | 0.8236 | 4,507 | 0.2445 | 2 / 39 |
| hover.Step | 0.7339 | 19,113 | 0.0514 | 2 / 39 |
| suspension.Apply | 0.6741 | 19,113 | 0.0472 | 2 / 41 |
| contact.Step | 0.5067 | 19,113 | 0.0355 | 2 / 48 |
| legHitboxes.Update | 0.3857 | 19,247 | 0.0268 | 1 / 43 |

Vehicle包含腿、悬挂、hover和接地，腿包含步态，不能相加。vehicle.Step单独self平均0.4611ms/帧，legs.Step排除已测步态后self0.4581ms/帧；所以“改Vehicle循环本身”与“全部改AI”都没有测量上的充分依据。unit.Flush调用40,748次但总inclusive仅0.4103ms/帧，频次最高不等于耗时最大，不优先做它的空调用跳过。

## 旧的更细实测提供了什么

`PERF_DRIVE_WEB_SECTIONS_2026_10_16.md`中有效57绑定实测为六车、1,052帧、1,806固定步：gait.swing累计0.827ms/帧（11,229次），另包gait.foothold为0.543ms/帧（7,963次）；stance0.342、kinematics0.106、finish0.058ms/帧。其原始身份与当前LegGait SHA均为`2da50517efb533160620e8df3ef914f14787d55683fa0be34db82d0a0d860e59`。可以用来选内部范围，不能与当前八车数值相减；当前legGait标签没有这些内部子段。

`evidence/vehicle-allocation-fd97-c-independent-1.json`是实际Native单步分配诊断（8个采样，GC在每个受限同步步内暂停，**全部计时INVALID_FOR_PERFORMANCE**）：

| 实际记录的分配owner | exclusive KiB/固定步 | 实调次数/8步 |
| --- | ---: | ---: |
| drive.LegGait.Step | 32.8545 | 16 |
| combat.EnemyDriver.Step | 14.3828 | 56 |
| combat.EnemyDriverMotion.Crowd | 10.4229 | 46 |
| drive.LegGait.Foothold | 9.1338 | 20 |
| combat.EnemyDriver.Missiles | 1.3125 | 56 |

这份数据把Foothold作为Step的已测子owner排除，故32.8545和9.1338属于不同记录边界；不能与当前监控的self名义直接等同。该采样Think、Path等为0次，不能据此认定它们免费。它表明步态有实际垃圾生产，**不证明Web GC尖峰由步态分配造成**。另有Web结构指纹已确认的三个GC尖峰，只证明回收发生在某消费者内；不能倒推那一消费者分配了全部垃圾。

AI内部更细的实际Web归因`PERF_WEB_SEMANTIC_SCOPES_2026_10_17.md`中Visible为12,608次 / 1.021ms/帧，Think自身仅97ms总量、Crowd自身356ms总量。Visible会走当前主线正在处理的VehicleRay，因此在该候选结束前再改AI判断频率或寻路，不是独立且已归因的优化。

## 可执行下一候选与门禁

**建议下一条独立候选为LegGait摆动/落点搜索的私有临时输出缓冲，而不是改变步态规则。** 从实际调用与分配看，它比Missiles扫描、空Flush或再次改GC模式更值得尝试。第一版只碰Foothold内部生成的射线origin/direction与候选容器，不碰持久的foot/previous/sw/contact/hit、数学运算顺序、射线数量与顺序、命中选择或随机数。由每个LegControl拥有私有缓冲，禁止模块级共享。

但数据尚未细到证明“具体哪一个Add/Scale或容器”占9.1338KiB的大头，因此**不能直接承诺收益，也不建议先大改整个LegGait**。可执行顺序：先在隔离实际Lua夹具中逐类计数Foothold内部临时结果/逃逸位置，证明所选缓冲没有被Cast/Reachable/Clear或返回hit保留；只有计数有实质覆盖才制作窄候选。若缓冲只能消除少量tries/dirs数组，立即停止，不因父scope较重继续死磕。

已有`verify-leg-clear-points-cache.py`使用的实际LegGait/LegControl回放覆盖T3/T5六腿、十腿波形、平地、墙面、跳跃、坡面、转向、停车、重置和破坏；新候选可复用其真实输入与严格双精度bits、状态、施力及有序射线检查，但不能复活已拒的Clear缓存。必须新增输入数组别名/保留引用、同controller重入、另一controller并行调用和错误展开后再调用负控。仅普通GC下完整Step配对计时有可重复收益，且共享状态/RNG/工作量通过，才交给root真实同包Web验收。

风险是缓冲逃逸覆盖hit/foot或共享引用，造成踩墙、腿抖与后续轨迹变化；另有风险是省分配却增加Lua写入，最终更慢。以前rest-world坐标缓存、Clear缓存、Math3融合、Cylinder标量、空hover和GC模式候选已拒绝，本次都不重试。候选若仅分配下降而正常GC完整Step无稳定收益，也应拒绝。

本报告只选择有实测依据的下一个内部范围与候选合同，没有修改算法、制作候选或执行游戏。骁龙845 TapTap持续30FPS仍未验收。
