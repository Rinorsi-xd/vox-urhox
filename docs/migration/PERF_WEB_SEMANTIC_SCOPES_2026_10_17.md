# Web 交火 29 段语义归因

日期：2026-10-17。状态：`ACTUAL_WEB_ATTRIBUTION_PASS / PERFORMANCE_CAUSE_OPEN`。

## 实际运行与独立复核

主 agent 串行运行 `evidence/monitor-combat-simulation-fd97-a/`，报告为 PASS/CLOSED，Runtime 与 HTTP 错误 0。本次独立解析确认 29 个已有方法仅安装一次、在采样前生效，源 SHA 与实际包 identity 相符；没有 debug API、强制 GC、GC 模式变更或 per-ray/Quad/vertex 新计时。生产代码没有因此次归因改变。

实际负载仍为 8 车、7 个 AI；记录 1032 次射击、1470 次世界命中、玩家受伤 539，零件最低 800。完整帧共 1200，累计 45139 ms。原始 engine/monitor 偏移 -1031；1182 帧间隔完全相等，18 帧差 1 ms，排除原始首尾 3358/4559 两个不完整帧，没有补造帧。

| 观察量 | 本轮结果 |
| --- | ---: |
| 平均帧间隔 / 总帧除以总时长 | 37.616 ms / 26.585 FPS |
| P50 / P95 / P99 / 最大 | 34 / 69 / 79 / 118 ms |
| >80 ms 完整帧 | 9 |
| 平均脚本包围墙钟 | 25.453 ms/帧 |
| 平均固定模拟步 | 2.257/帧 |
| Finalize / 嵌套 Emit / Context | 0.174 / 0.063 / 0.080 ms/帧 |

这是增加 29 个包围方法后的归因采样，与上一轮 30.43 FPS 的车辆伤损、时序及观察负载不同，不能将两轮差值称为优化收益或性能回退 A/B。正常固定步补跑也会随帧间隔变化。本报告没有匹配的零观察器对照。

## 持续开销

下表是排除本次已测同步子方法后的 self 包围墙钟；仍可能包含原生调用、自动 GC 和调度，不能把表内所有数字直接称作算法 CPU。

| 已测范围 | self 均值 ms/帧 | 调用总数 |
| --- | ---: | ---: |
| `effects.Update` | 2.360 | 1200 |
| `physics.Step` | 1.745 | 2708 |
| `weapons.Step` | 1.584 | 18525 |
| `environment.Update` | 1.388 | 1200 |
| `playerView.Update` | 1.381 | 8106 |
| `objectives.Update` | 1.067 | 2708 |
| `sim.nav.visible` | 1.021 | 12608 |
| `suspension.Apply` | 0.865 | 18525 |
| `suspension.Sample` | 0.830 | 18685 |
| `sim.ik.solve` | 0.451 | 63142 |

AI 细分中 Visible 累计 1225 ms；Think 自身 self 仅 97 ms、Motion 自身 239 ms、Crowd 自身 356 ms。可见性检查是更具体的观察入口，但不能因此省略遮挡规则或降低 AI 质量。IK Solve 的 63142 次调用说明有稳定工作量，既有同姿态缓存等已拒绝候选不能因本表重新宣称有效。

选中的特效子段没有解释 `effects.Update` 的大部分 self：Combat Path 656 次累计 33 ms；Weapon Bands/Arcs/Motes 分别累计 3/7/1 ms，Swirl 与 Projectiles 在整数毫秒计时下累计为 0。**0 表示未跨此计时分辨率，不表示计算免费。** Helix、Weapon Path、Tactics Slide 未实调，明确列为未覆盖，不能将本负载扩大成全部武器特效成本验收。indexed/zap 已拒绝的候选继续拒绝。

## 九个长帧

| engine 帧 | 间隔 / 脚本 ms | 主要已测 self 范围 | 相邻 Lua 堆变化 KiB |
| --- | --- | --- | ---: |
| 3378 | 118 / 18 | 最大已测 self 仅 2 ms | -12491 |
| 3427 | 88 / 73 | legs.Step 30 ms；Visible 8 ms | -10473 |
| 3649 | 85 / 70 | suspension.Sample 32 ms | -12058 |
| 3740 | 96 / 83 | effects.Consume 35 ms | -13588 |
| 3746 | 91 / 76 | legs.Clear 36 ms | -13298 |
| 3753 | 82 / 69 | combatView.Consume 37 ms | -14040 |
| 4169 | 89 / 79 | legs.Step 41 ms | -13742 |
| 4201 | 85 / 73 | turretRange 53 ms | -16103 |
| 4525 | 87 / 17 | 最大已测 self 仅 2 ms | +1326 |

承担长墙钟的标签继续分散。最大 AI 包围调用落在 Visible 40 ms，同帧堆下降约 17.3 MiB；腿步态长调用则可能落在 Clear、Reachable 或未细分 self，仍不能将同帧堆下降当成回收时长证明。

4201 的 For 53 ms 需要保留，但发生在较大堆回落同帧。本探针没有记录冷/暖类别，不得将其直接宣称为缓存未采用或冷净空算法又跑了 53 ms。3378/4525 的长帧有很大部分不在已测脚本包围内；未测差额也不能直接叫 GPU。

## 后续优先级

1. 用有界单固定步分配探针拆 Vehicle、悬挂、Body 读、腿、Hover 及武器的真实分配。该探针停止 GC 的步骤只作分配诊断，所有时长标 INVALID，不与正常 GC 帧率混用。先确认分配来源，再准备保持规则的候选。
2. Visible 及 Effect Update 是实际稳定调用入口，后续只针对已测子段继续拆分；不重复已拒绝的同姿态/索引/zap/额外 priming 候选，也不从一个偶发 40 ms 包围直接改寻路、武器或物理规则。
3. 对两个大部分在脚本之外的长帧，需要单独的实际引擎/呈现证据。CPU 归因不能代替 GPU 计时或 TapTap 骁龙 845 长时间 30 FPS 验收。

53 份带上下文记录中，大厅、建造、地图预览和开篇 retained/active 均无真值；backgroundResources 有一份为 1，其余为 0。这不证明存在另一场景后台渲染，也不能写成“全部后台资源计数始终为零”。

## 证据

同目录 `independent-simulation-attribution.json`、`-base.json`、`-base-frames.json` 是本次新增派生结果，原件未覆盖。输入 SHA-256：

| 输入 | SHA-256 |
| --- | --- |
| `capture.json` | `570db3e93e1246852e6ef33d1727fb4164764e6dcbbe7ce25b370d95a64e5ac0` |
| `production-perf.jsonl` | `524aac7413c85a522a6cda2e83ffe63d798586a1d477787030be780c6fbe44ef` |
| `report.json` | `c891c9f37b54d79685e3e96bf004b75a21912eb71b912a3f2013695aef6b0b27` |
| `runtime.log` | `b0751d91b845da5a94ce2ff4197db39ade60b66038abb948cf43f093ab9d7a30` |
