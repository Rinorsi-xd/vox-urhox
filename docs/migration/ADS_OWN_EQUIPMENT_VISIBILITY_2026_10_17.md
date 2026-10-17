# ADS 自身装备粒子可见性调查

日期：2026-10-17。状态：**来源定位、离线行为及当前候选四类武器的实际 ADS 装备粒子可见性检查通过；完整战斗与性能验收未完成**。

## 已确认的画面来源

原始证据：[ads-pixel-3030-1017-e/report.json](evidence/ads-pixel-3030-1017-e/report.json)。该次 Web 运行状态 `PASS`，退出 `CLOSED`，Runtime 错误与 HTTP 错误均为 0。

这是对同一实际 ADS 帧中已提交几何的分类重放。相机、FOV、时钟、随机状态和参考几何保持固定；没有通过再次执行 `Effects.Update(0)` 制造对照。

截图尺寸为 1600×900；下表统计中心矩形 `x=400..1199, y=225..719`，共 396,000 像素。像素差异表示该类别在本帧中心区域的贡献，不表示优化耗时。

| 对照 | 实际移除的几何 | 中心变化像素 | 最大通道差 |
| --- | --- | ---: | ---: |
| B-motionOnly | 自身 WeaponView 发射的 2 个 spark | 0 | 0 |
| C-allEquipment | 上述 2 个 spark，加自身 WeaponEffects 持续特效发射的 2 个 spark | 1,374 | 87 |
| D-noStreak | 26 个 Streak 几何 | 3,218 | 93 |
| A2/A3/A4-restored | 恢复全部原始几何，与 A1 比较 | 各 0 | 各 0 |

基线 Glow 共 32 个提交；B 保留 30，C 保留 28。Smoke 为 0。Streak 基线 26，B/C 均完整保留，D 才移除全部 26。

各阶段 `digest/referenceDigest` 均为 `28b7670d`；`randomDelta` 与 `randomSeedDelta` 均为 0。实际处于 ADS，玩家模型可见数 0/92，持续装备 batch 不可见。

因此，本帧中心区域的两点装备亮斑来自 `ownPersistent` 的 Swirl 发射链。只过滤 `ownMotion` 无法消除它们。Streak 是另一个独立画面类别；这次生产修改没有删除整类 Streak。

已人工查看 [A1 基线](evidence/ads-pixel-3030-1017-e/A1-baseline.png) 与 [C 差分](evidence/ads-pixel-3030-1017-e/C-allEquipment-diff.png)：差分集中于准星下方的两处亮点。完整对照包括 [B 图](evidence/ads-pixel-3030-1017-e/B-motionOnly.png)、[C 图](evidence/ads-pixel-3030-1017-e/C-allEquipment.png)、[D 差分](evidence/ads-pixel-3030-1017-e/D-noStreak-diff.png)。这不构成所有武器和战斗画面已一致的结论。

## 当前生产候选

装备粒子使用明确的 `sourceView` 身份，而弹丸仍使用已有的 `ownWeapons` 身份，两者分别存储。

- `WeaponView.Update` 将实际 `vehicleView` 传给 `EquipmentEmit`。
- `WeaponEffects.Swirl` 将构造时持有的 `self.view` 传给 `EquipmentEmit`，覆盖此次真正造成中心亮斑的持续特效链。
- `CombatEffects` 仅给装备 spark/mote 记录 `sourceView`。ADS 时，在生命周期、移动、碰地、尺寸更新完成后，跳过来源为 `ownView` 的绘制。
- `TrialSession` 两处启用第一人称状态的调用明确传入 `self.view.view`。死亡关闭第一人称；Dispose 清除 `ownView` 和 `ownWeapons`。

`VehicleView` 创建 `WeaponEffects.New(self)`，与 `WeaponView.Update` 的 `vehicleView`、`TrialSession.self.view.view` 是同一个对象。`PlayerViewSync` 在重生或修复时调用原 view 的 `Rebuild/SyncBlueprint`，没有换用另一个身份。

没有提前停止粒子生成、年龄推进或随机调用；fizzle/boot 及敌方、未标记粒子的绘制行为保持原有逻辑。粒子列表仍受原容量和寿命限制。

归档时生产文件 SHA-256：

| 文件 | SHA-256 |
| --- | --- |
| `scripts/app/TrialSession.lua` | `901078d0e2d6bf4813dcca49494a72e119eecc30ff8c712c5bd7a32450ef7e6a` |
| `scripts/render/CombatEffects.lua` | `64549a73ba0cda3a53b9dc56c112990161668846c3a378f1c0ae4d9436ed655f` |
| `scripts/render/WeaponView.lua` | `935d2248abcdd279eedf094e1e87356aea7942d62dafaeb497982b38da684845` |
| `scripts/render/WeaponEffects.lua` | `a732d53445ac3ab80e40e069729925670b59a830e4c2e3195d3a76d6db41083a` |

## 离线行为检查

检查：[check-ads-equipment-particles.py](../../tools/migration/check-ads-equipment-particles.py)。证据：[ads-equipment-particles-offline-2026-10-17.json](evidence/ads-equipment-particles-offline-2026-10-17.json)。

实际加载当前 `CombatEffects`、`WeaponView` 和 `WeaponEffects.Swirl`，在内存中重建移除归属信息前的方法作对照。20 组案例，每组 180 帧，总计 3,873,756 项断言通过。

覆盖容量 0/1/8/1000、自身/敌方/无归属、ADS 常开/关闭/进入退出/频繁切换、ADS 缺少 ownView、spark/mote/fizzle/boot、到期回收。逐帧粒子状态、位置、速度、尺寸、地面查询次数、绘制参数和后续 RNG 序列一致，仅预期自身装备粒子的绘制不同。

实际 WeaponView 与 Swirl 均验证精确 view identity。Swirl 对照的随机调用次数、Quad 数、发射数一致；Dispose 的归属清理通过。图形和服务使用离线适配器，不能由此签署 GPU 画面或帧率验收。

## 保留的失败记录

| 原始记录 | 状态与失败原因 |
| --- | --- |
| [b/report.json](evidence/ads-pixel-3030-1017-b/report.json) | FAIL/CLOSED；actual hall 阶段 Scope telemetry timeout；Runtime/HTTP 错误 0 |
| [c/report.json](evidence/ads-pixel-3030-1017-c/report.json) | FAIL/CLOSED；MG real spin 阶段观察工具读取未定义对象的 count；Runtime/HTTP 错误 0 |
| [d/report.json](evidence/ads-pixel-3030-1017-d/report.json) | FAIL/CLOSED；已进入 ADS 后，F8 与生产 DebugPanel 快捷键冲突，打开面板并 Pause 导致退出 ADS，随后冻结断言失败；1 条 Runtime 错误，HTTP 错误 0 |

d 的 [runtime.log](evidence/ads-pixel-3030-1017-d/runtime.log) 在 sequence 93 附近先记录 `firstPerson=true, scope=true, visible=0/92`（12:51:56.548），随后记录 `firstPerson=false, scope=false, visible=92/92`（12:51:56.700）。[DebugPanel.lua](../../scripts/ui/DebugPanel.lua) 的 F8 入口调用 `SetOpen(true)`，打开面板时调用 `trial:Pause()`；因此该失败是进入 ADS 后被快捷键冲突打断，不能描述为从未进入 ADS。原始失败记录保持不变。

e 的通过不覆盖、删除或改写 b/c/d 的失败。

## 当前候选实际运行

原始记录：[ads-source-c074-1017-a/report.json](evidence/ads-source-c074-1017-a/report.json)。独立复核：[ads-source-c074-1017-independent.json](evidence/ads-source-c074-1017-independent.json)。该次候选运行 `PASS/CLOSED`，Runtime 与 HTTP 错误均为 0。

四类武器 mg/laser/sniper/missile 均通过实际鼠标开火、右键 ADS、释放右键流程；保存了每类 normal/scoped/released，共 12 份 JSON 和截图。独立检查确认 12 份 JSON 与报告样本逐项完全相同。

| 检查项 | 实际结果 |
| --- | --- |
| 四类武器 ADS | `firstPerson/scope=true`，玩家模型可见数 `0/92`，持续装备 batch 不可见 |
| 归属身份 | 四份 scoped 样本均 `ownViewMatches=true`，来源违规与模型隐藏违规均为 0 |
| 自身装备提交 | 每类 scoped 样本中 `ownMotion/ownPersistent` 的本类 ADS 已接收绘制数均为 0 |
| MG 非空验证 | scoped 样本实际存活 2 个 ownPersistent 粒子，该阶段累计发射 17 个；其自身装备绘制仍为 0 |
| 释放 ADS | 四类均 `scope/firstPerson=false`，`ownViewCleared=true` |
| 原粒子恢复 | MG 释放后的同对象恢复计数为 18 次已接收绘制；不是 18 个不同粒子 |
| 构建身份 | 四个生产文件 SHA 与冻结源文件、identity 及运行时实际 HTTP 取回的 payload SHA 一致 |

观察器用弱键表记录实际粒子的 position table；只有在 ADS 期间记录过的同一对象，在释放后再次提交绘制，才计入恢复。因此恢复不是靠重新发射另一批粒子代替。释放后累计统计的阶段标签可能沿用更新前的 `TrialSession.firstPerson`，不应把后续 release 样本的历史 `scoped` 标签当成 ADS 期间违规；四份实际 scoped 快照均满足零提交。

归档服务器已关闭；独立复核时重新访问 `127.0.0.1:4581` 返回 `ECONNREFUSED`。HTTP SHA 依据原始运行中实际取回的记录，与当前文件及冻结文件分别计算的 SHA 对照，未重启服务器或改写原始证据。

此候选验证使用合成的四种 T5 武器连通试车车体。e 仍仅是修改前来源定位，候选通过依据本节的新运行。保留的弹丸、光束等画面不属于本次自身装备粒子隐藏范围，不能据此宣称整个 ADS 视野或所有武器特效均已解决。

## 尚未验收

实际敌方粒子、自然对局中的命中特效、死亡/重生、完整战斗仍需覆盖；离线检查不替代这些实战验收。释放后模型可见数也不应概括成全部 92 个都恢复：导弹 normal/released 样本分别为 89/92、80/92，本次只验收其 ADS 隐藏与归属状态清除。

本报告没有验证 FPS 改善、CPU 降幅或骁龙 845 持续 30 FPS。这次修改解决的是装备粒子在第一人称视野中的可见性，不是战斗 CPU 瓶颈的性能验收。
