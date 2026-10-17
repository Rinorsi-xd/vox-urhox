# Native 八车车辆更新与分配实测（2026-10-17）

本轮确认了实际车辆模拟的分段成本，但没有获得足够可靠的新 CPU 优化收益。`LegControl.Clear` 点变换融合与 `Math3.Mix/Reject/Unrotate` 融合都只保留为独立实验，结论为 **REJECTED_NO_RELIABLE_CPU_GAIN**；生产 `LegControl.lua` 和 `Math3.lua` 保持原样。没有禁用生产 GC、减少车辆、改物理步频或改变玩法。

## 实际样本与边界

- Runtime：`0.9.0-beta.40_20261015.121839.6dc5c357cced`，SHA-256 `f6a2ae8893bebb66b0dce1f6687a6ba0cd98454a20069541b5557cbf5f79772c`。
- 真实 `CraterWorld`、`CarUnit`、`Vehicle`、`EnemyDriver`、`WeaponSystem` 和 Bullet。双方各 assault/heavy/sniper/assault，共八辆 T3 variant0；两辆六足车，其他为车轮/履带车。没有机甲腿、悬浮或飞翼样本。
- 固定随机种子 1016，先预热 120 个固定步。分配采集为 6 批 × 4 步，随后另跑 **600 步正常自动 GC**计时。两组数据分开，不把停 GC 时的内存增长当成 GC CPU 时间。
- 每批停 GC 有 8 MiB 增量、128 MiB 绝对 Lua 堆、250 ms 保护；所有七次运行均恢复原 GC 模式和 running 状态，进程均退出。
- AI 开启、武器更新开启但不开火。没有目标规则、完整战斗流程、渲染、音频或 UI。这里不能验证 Web、TapTap 或骁龙 845 的持续帧率，也不能解释破坏/开火特效的全部尖峰。
- 每个方法使用同一可复用 scope token 记录整数毫秒墙钟；其中包括观测、原生绑定、GC 和操作系统调度。不是线程 CPU 精确采样。父段 inclusive 已含子段，**不能把父子 inclusive 相加**。

基线为 `.tmp/perf-vehicle-allocation-20261017-b` 的冻结脚本。持久证据中的 `baseline-source-identity.json` 保存全部 547 个生产脚本哈希，仅另外保存了被实验修改的两个文件原文，没有复制整个工程。

## 正常 GC 的 21 个实际边界

下表取完整原始基线 `helper-allocation-timing-1.json`，600 步总墙钟 **2112 ms（3.52 ms/步）**。时间和分配来自不同阶段；两列调用数分别列明，不能混除。

| owner | 正常 GC 调用数（600 步） | inclusive ms | self ms | 分配采集调用数（24 步） | self KiB |
|---|---:|---:|---:|---:|---:|
| drive.Vehicle.Step | 4800 | 1135 | 82 | 192 | 614.09375 |
| drive.Vehicle.StepRotors | 4800 | 6 | 6 | 192 | 0 |
| drive.Vehicle.PostStep | 0 | 0 | 0 | 0 | 0 |
| drive.RaySuspension.Sample | 4800 | 195 | 101 | 192 | 698.4609375 |
| drive.RaySuspension.Apply | 4800 | 163 | 163 | 192 | 1661.765625 |
| drive.ContactControl.Step | 4800 | 93 | 93 | 192 | 966.65625 |
| drive.ChassisStability.Step | 3600 | 67 | 36 | 144 | 384.9375 |
| drive.HoverControl.Step | 4800 | 15 | 15 | 192 | 189 |
| drive.HoverControl.Motion | 4800 | 9 | 9 | 192 | 16.5 |
| drive.ThrusterControl.Step | 4800 | 31 | 31 | 192 | 524.0625 |
| drive.WingControl.Step | 4800 | 1 | 1 | 192 | 10.5 |
| drive.LegControl.Step | 1200 | 389 | 251 | 48 | 2929.0703125 |
| drive.LegControl.Cast | 21743 | 138 | 22 | 882 | 99.9453125 |
| drive.MechControl.Step | 0 | 0 | 0 | 0 | 0 |
| drive.LegHitboxes.Update | 4800 | 90 | 90 | 192 | 1193.625 |
| drive.MechHitboxes.Update | 0 | 0 | 0 | 0 | 0 |
| physics.Space.Raycast | 68158 | 409 | 409 | 2833 | 1495.7890625 |
| physics.Space.Step | 600 | 361 | 361 | 24 | 0 |
| physics.Body.Wrap | 0 | 0 | 0 | 0 | 0 |
| combat.WeaponSystem.Step | 4800 | 36 | 36 | 192 | 246 |
| combat.EnemyDriver.Step | 4800 | 493 | 325 | 192 | 4667.9453125 |

互斥 self 合计 2031 ms，另有循环、选目标、未覆盖方法等约 81 ms；整数时钟和观测开销仍在。最大的 self 边界为 Raycast 409、Space.Step 361、EnemyDriver 325、LegControl 251 ms。不能从本样本推出“只有 AI”或“只有物理”的结论。

`Vehicle.Step` 的分配 inclusive 为 10199.8671875 KiB / 192（53.12 KiB/调用），其自身余项只有 614.09375 KiB / 192（3.20 KiB/调用）。LegControl 自身分配 61.02 KiB/调用，但其 self 时间仅占整段约 11.9%；**分配占比不能当 CPU 占比**。

24 步净 Lua 堆增量 16472.0078125 KiB，已归属 self 15698.3515625 KiB，未归属 773.65625 KiB；逐帧守恒通过。`Body.Wrap` 总调用、未登记、静态和动态分支均为 **0**，所以“这套样本反复给静态碰撞创建 Body 包装”的假设没有实测支持，没有修改 Space/Body。

## 两个没有合入的实验

### Clear 点变换

保持 `ApplyRot → Scale → Add → RotateUnit → Add` 的全部运算分组，仅减少四个 IK 点的中间表，不复用可变输出。完整实际 LegControl/Gait/IK 对照通过 8,627,430 个断言，另含 28,800 组点变换压力测试。状态、力、射线坐标及顺序使用 packed double 对照，覆盖混合地形、跳跃、恢复、破坏、原地修改输入与异常清理。

完整 controller 的 ABBA：leg3 平均 0.5475→0.534 秒（2.47%），leg5 0.51675→0.514 秒（0.53%）。Native 单次 2112→2078 ms（1.61%），净分配 16472.0078125→16320.8828125 KiB，仅少 **151.125 KiB（0.92%）**。不足以证明可靠 CPU 改善，拒绝合入。

### Math3 三函数融合

仅融合 Mix/Reject 的标量中间计算及 Unrotate 的临时共轭四元数，保留所有浮点分组、不正规化四元数、不引入共享输出表。独立数学边界检查 39,131 次调用、117,393 分量通过，覆盖整数/浮点类型、负零、非单位和零四元数、NaN 分类与溢出；五个错误候选负控均被拒绝。完整 controller 另通过 8,512,230 个断言。

完整 controller ABBA：leg3 0.5685→0.53325 秒（6.20%），leg5 0.525→0.51725 秒（1.48%）。Native 初次仅 2112→2037 ms，不据此合入；随后相邻四轮使用同一冻结 A 和仅 Math3 修改的 B：

| 顺序 | 正常 GC 600 步墙钟 ms | LegControl self ms | 24 步净 Lua 增量 KiB |
|---|---:|---:|---:|
| A1 | 2717 | 330 | 16472.0078125 |
| B1 | 2033 | 223 | 15701.8125 |
| B2 | 2016 | 243 | 15701.8125 |
| A2 | 2064 | 214 | 16472.0078125 |

A1 有明显漂移，原样保留，不删除后取更漂亮的均值。B 相对贴近的 A2 仅约 1.9%，LegControl self 也没有一致下降；不能宣称整段改善 15.3%。分配下降 **770.1953125 KiB（4.68%）**可以重复，但没有证明稳定 CPU 改善，按本轮门槛拒绝合入。没有开启 Web B 或替换当前普通包。

## 验证与后续测量入口

`verify-native-vehicle-candidates.py` 对七次原始运行的 metadata、全部六个中间快照、最终八车状态和 Body.Wrap 数据做无容差的规范化 JSON 数值/结构对照，全部相同；所有 21 个 owner 的调用次数和零错误一致，Raycast 均为 68158 次。Runtime/探针哈希一致；两个候选与基线各只有声明的单文件差异。生产两个模块哈希仍等于基线。

已经有证据支持的下一层边界为：Raycast 409 ms 中的原生查询与结果处理尚未拆开；EnemyDriver self 325 ms 未细分；LegControl self 251 ms 仍包含完整 Gait/IK，Clear 小改不覆盖其大部。它们是**待分解边界**，不是已确认的新算法根因。完整 Web 正常 GC 的尖峰仍须结合实际整帧证据；本报告不把 Native 的 3.52 ms/步换算成 Web FPS。

全局战斗优化、近距交火/破坏、完整移动方式、骁龙 845 / TapTap 长时间稳定 30 FPS 均保持 OPEN。

持久归档：`docs/migration/evidence/native-vehicle-allocation-2026-10-17/`。其中包含七次原始 JSON、launch、stdout/stderr，基线/候选 hash manifest、原探针、两个被修改文件的 baseline、候选和 `verification.json`。离线完整 controller 结果为相邻的 `leg-clear-scalar-offline.json`、`math3-scalar-controller-offline.json`，独立数值结果在归档内 `math3-scalar-parity.json`。工具只读验证可重跑，既有 verification 文件不自动覆盖。
