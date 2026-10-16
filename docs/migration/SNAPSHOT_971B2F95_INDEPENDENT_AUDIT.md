# 971b2f95 独立包与命中光壳审查

接续现有 G0-G6。本批独立审查生产接线、重跑原离线工具并核对发布字节；没有修改生产脚本，没有启动 GPU、浏览器、原生引擎，没有提交或上传。

## 包身份

- H5 基线：`2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`。
- 快照：`.tmp/outgame-cached-1792084787150`。
- 清单：`manifest-971b2f95.json`，7469 项。
- 脚本指纹：`b7df73ab4976b96b3d9ceaada73248acc622a4c210cbf6e30fc2609ffd6fed12`。
- 482 份 Lua 的当前源码、快照、identity、manifest 和实际发布 payload 全部逐 SHA 一致，均为 blocking。
- 统一审计纳入 23 份报告、93 条文件 SHA，0 漂移。新增 `part-hit-flash` 与实际重跑的 `endless-spawn-lifetime`；没有直接刷新旧报告 SHA 代替执行。
- `RestoreFlash.shader` 实际发布 payload `C-vNqT6YVGvGZQ-lJg47NRmv-b7fef1c8.shader` 的 SHA 为 `1d1cfe8b1cbf7aa2e6e283d8208647638b4781c0d62d0be98fa38b775d7a7780`，与源码及快照相同。

## 命中光壳独立审查

审查 `CarUnit.RecordDamage`、`CombatView`、`PartHitFlash`、`RestoreFlash` 和 shader，并直接对照冻结 H5 `testDrive._hud`、`vehicleView.paintFlash/_flash` 与光壳更新代码。

| 项目 | 结论与边界 |
| --- | --- |
| 伤害事件 | 原事件丢失的 partId/shield 已保留；CombatView 在清空 viewEvents 前消费。被击碎零件、已销毁车辆和不存在的视图不新建光壳。 |
| 触发条件 | 非玩家目标、玩家来源或无来源、零件仍存在，以及严格大于 80ms 的逐车节流与源一致；180 个实际 H5 `_hud` 情形均对照。 |
| 颜色与动画 | 白色与 0x7fd6ff 均转线性颜色；0.34s、1.1*(1-k)^1.5 透明权重与 0.14 easeOut 扩张一致。非 pop，不写原零件缩放。 |
| 连续命中 | 同零件每次命中保留独立快照与叠加亮度，不重置现有壳；只复用已经过期的池项。逐车约 5 个同时活跃壳，空闲池最多 8 项。 |
| 骨架姿态 | 新命中保存当时组件姿态，旧光壳保留旧姿态；车型根继续跟随车辆，未把轮子/炮塔弹回初始姿态。 |
| 遮挡设置 | 与源一致使用 additive、默认深度测试和禁止写深度；没有 depth_test_disabled。该结论仅证明配置与源码，真实墙体/车辆遮挡仍待 GPU。 |
| 清理 | 视图替换、代际变化、零件移除、单位移除及 Dispose 释放活动壳、缓存壳、私有材质和引用计数模型。NodeVisibility 隐藏恢复使用实际模块，并覆盖池回收。 |

独立执行 `verify-part-hit-flash.py`：850 项通过，包含 180 个实际 H5 情形与原修复光壳 10 个回归场景。最终 RestoreFlash SHA 为 `b7466adab94d57e3d11fc40b6f564a6e8981c5c8a1dca4ef87083678afb915be`。在此次范围内未发现新的生产缺陷。

## 共享模块回归

| 原工具 | 实际结果 |
| --- | --- |
| `check-endless-spawn-lifetime.py` | 22 项与准备阶段 497 项通过；旧报告引用旧 RestoreFlash SHA，已实际执行后生成新报告。 |
| `check-debris-visual-transfer.py` | 28 项通过；证据 `evidence/debris-visual-transfer-2026-10-15T17-20-59-344971Z/report.json`。 |
| `check-vehicle-checkpoints.py --spawn-cache` | 121 项通过；证据 `evidence/spawn-cache-2026-10-15T17-21-36-339198Z/report.json`。 |
| `check-vehicle-checkpoints.py` | 8306 项通过；证据 `evidence/vehicle-checkpoints-2026-10-15T17-21-52-720361Z/report.json`。 |
| `check-vehicle-checkpoints.py --damage-rebuild` | FAIL，旧全对象等价夹具在 `pristine unit raceCar: value.spec.boxes.1.mass` 停止。不能引用旧通过记录证明当前通过。 |
| `verify-merge-boxes-offline.py` | 当前 b276 冻结 H5 对生产 Lua：114 案例、91016 断言通过，110 案例相对旧规则改变。 |

上述 damage-rebuild FAIL 的旧参考 `.tmp/damage-before-2026-10-15/VehicleSpec.lua` 在合盒时不约束质量；当前生产使用 b276 源明确要求的种子质量 0.5 到 2 倍约束。因此 pristine spec 的 mass/盒数组已按当前基线有意改变，见 `BASELINE_B276_MASS_DELTA_2026_10_15.md`。没有修改旧参考或忽略差异把此旧等价测试伪造为通过。本次 CarUnit 的生产 diff 仅追加事件字段；当前命中字段由上述真实 CarUnit/CombatView 路径测试覆盖。完整损伤重建的旧等价夹具仍需按当前基线建立可区分预期变化的参考。

## 不得据此关闭

证据：`evidence/unified-snapshot-manifest-971b2f95-audit.json`、`evidence/part-hit-flash-offline.json`、`evidence/endless-spawn-lifetime-offline.json`、`evidence/merge-boxes-b276-offline.json`。

离线替身不能证明 shader 实际编译、光壳亮度/墙后遮挡、自然战斗音画、真实驾驶手感、真实账号/编辑器操作与手机持续性能。旧重复进陨坑 OOM、冷加载冻结、严重战斗帧率与尚未完成的 UI 字体视觉差异不会因本审计通过而关闭。
