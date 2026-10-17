# e854 当前 Web 八车战斗独立审计

日期：2026-10-17。root 完成实际运行 `evidence/monitor-combat-e854-1017-a` 后通知审计；原运行 **PASS / CLOSED / exit 0**，Runtime / HTTP 错误均为 0，性能记录解析警告为空。本审计只读取已经完成的文件，没有启动浏览器、Runtime 或额外性能采集进程。

## 当前结果与验收边界

完整帧 1,392 个，排除首尾 2 个不完整帧，对应 engine frame 3769--5160，总计 45,040ms。平均 **32.356322ms / 30.9059 FPS**，P50=28ms、P95=65ms、P99=73ms、最大106ms，4帧超过80ms。平均超过30FPS仍不等于稳定30FPS；本窗没有通过长时稳定30FPS，也没有验证骁龙845在TapTap中的运行或热稳定。

真实8车、7个AI，玩家持续开火。世界 shots 增970、hits增938、damage增210、kills增0；玩家战斗 `stats.damage` 同样增210，表示造成的伤害，不表示玩家受伤210。世界hits不能当作只由玩家造成的命中。零件总数由初始1,277降至最低975，包含实际命中和结构破坏。

受控布阵保留真实车辆、AI、武器、物理和破坏系统，并检查车辆尺寸不重叠、地形/静态射线合法、双方可见。默认生产监控开启，额外只有3个粗粒度监控wrapper；初始化、布阵和观察器序列化在采集外。它不是自然对局、CPU/GPU分离或移动端验收。

原版基线在运行身份中记录为 Three.js 分支 `2026-10-15`，提交 `b276064942ae09c0227ec28d4cfda1d5ff006455`。迁移版记录的提交为 `f94827b26fc12b707e6d6904d093e16358caaf41`；本次实际脚本内容以 `report.json` 内逐文件SHA为准，不能仅凭提交号忽略工作区变化。HTTP主脚本和模块与冻结身份一致。

此前4a3a窗为29.6799FPS，但两窗射击、命中、伤害、零件损坏及轨迹不同，**不得用30.9059与29.6799计算优化提帧百分比或宣称因果收益**。VehicleRay候选的语义与定量收益需要对应的相同输入回放和普通GC基准单独证明。

## 同帧映射

`capture.json`使用引擎frameNumber，生产监控使用自己的BeginFrame计数。原始runtime中376条带frame的VOX_PERF记录，日志前缀engine frame减pending monitor frame全部为1,028。`PerformanceMonitor:Finalize()`在下一次真实Update中输出前一帧，因此当前映射为 **engineFrame = monitorFrame + 1,027**，不是旧窗的偏移1,011。

全部1,392个完整帧对应成功：1,370帧起止时长完全相同，其余22帧最大差1ms，符合两处整数墙钟边界；无重复compact frame。审计独立重新计算总时长、均值、分位、长帧数量与工作量，和原分析一致。采集帧i的完整起点到起点时长使用 `wallMs[i+1]`，排除首尾不完整帧。

## 实际存在的分段

以下均对应同一1,392完整帧。单位为整数毫秒墙钟，包含其子调用；P95/最大值为该帧该段的累计时长，不是独立CPU/GPU时间。

| 实际标签 | 平均包含时间 ms/帧 | P95 | 最大 | 调用总数 |
| --- | ---: | ---: | ---: | ---: |
| main.Update | 18.8621 | 48 | 86 | 1,392 |
| trial.Tick | 18.5201 | 47 | 86 | 1,392 |
| combat.BeforeStep | 9.1128 | 34 | 66 | 2,703 |
| vehicle.Step | 5.1710 | 10 | 46 | 19,520 |
| legs.Step | 1.5704 | 4 | 45 | 4,505 |
| legHitboxes.Update | 0.3477 | 1 | 38 | 19,632 |
| weapons.Step | 1.0654 | 3 | 41 | 19,520 |
| ai.Step | 1.4842 | 6 | 52 | 17,120 |
| combatView.Update | 2.1760 | 3 | 41 | 1,392 |
| playerView.Update | 1.2407 | 3 | 41 | 9,979 |
| weaponView.Update | 0.6437 | 2 | 41 | 9,894 |
| vehicleView.UpdateIdle | 0.3520 | 1 | 2 | 8,740 |
| effects.Update | 1.8132 | 3 | 40 | 1,392 |
| hud.Update | 0.9102 | 1 | 33 | 1,392 |
| main.PostUpdate | 1.9217 | 2 | 48 | 1,392 |

`main.Update`包含`trial.Tick`；Tick内固定步循环的`combat.BeforeStep`包含车辆、AI和武器步进。Tick随后执行视图、特效和HUD更新。`combatView.Update`包含多车视图更新，但玩家自己的部分共享标签也被Tick直接调用；不能把所有共享标签看成combatView内的独占时间。`main.PostUpdate`是另一回调。父子项不能相加凑成整帧预算。

本窗最大的已命名更新区域仍为BeforeStep，平均9.11ms/帧，2,703次固定步，约每帧1.94次。车辆步进是其中最大列出的子项，平均5.17ms/帧；腿部步进是其中一个可继续按实测分析的消费者。AI平均1.48ms/帧，存在开销，但本窗没有证明其为持续低帧主因。

不同消费者出现33--52ms单次峰值，不证明该消费者本身执行或分配了全部峰值。本窗没有新的WASM CPU栈，不能将所有峰值归因为GC。

**UI.Render没有出现在该生产日志的标签字典中。** `hud.Update`是状态/UI数据更新，不代替UI绘制；整帧减main.Update的差额不能直接归为渲染、GPU或UI。

3个粗粒度wrapper单独统计：monitor.Finalize平均0.1580ms/帧；monitor.Emit平均0.0503ms/帧（48次，包含在Finalize内）；bindings.Context平均0.0647ms/帧。Emit帧条件与其他帧不同，关联不证明日志为持续低帧主因，也不证明关闭监控的FPS收益。

## 证据与后续

- 独立结构化结果：`evidence/monitor-combat-e854-1017-a/independent-current-audit.json`。
- 可复用审计器：`tools/migration/audit-current-web-4a3a.cjs`，通过目录参数审计新窗，动态推导偏移，拒绝覆盖既有独立结果；本次完成耗时约0.28秒。
- report SHA：`4e2878dbbb99eee13a190b005caf41b14382c2ec394e30c300e883cf4f9c871e`。
- capture SHA：`fafb5035621291cab2a286a0664f0253a17b9447c7776f302b765b57ebcd9b02`。
- production-perf SHA：`d46456dc9a2b122eda1096d828669851014aaf0ca391cc604953a233950de206`。
- runtime SHA：`8733ad5ba66e754dc26012b06f4ce0b471e9cf97d1390430100e83c57bde5837`。

继续围绕BeforeStep、车辆步进和腿部消费者按实际分段取证；保留视图、特效、未测UI绘制及引擎等待的边界。新候选须先以相同状态、RNG、射线顺序和工作量验证，再做普通GC对照。本报告没有关闭迁移全部验收、手机持续性能或长帧问题。
