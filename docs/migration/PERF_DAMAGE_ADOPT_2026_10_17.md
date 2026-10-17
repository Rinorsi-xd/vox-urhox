# 破坏重建：复用已计算净空缓存的 Native 与 Web 验证

日期：2026-10-17。状态：`LOCAL_MERGED_DEVICE_OPEN`。
验证状态：`NATIVE_CPU_ABBA_PASS / WEB_CAPTURE_PASS / DEVICE_PENDING`。

## 结论

实际蓝图没有自己的炮管净空缓存，会在首次破坏重建时重新计算。本候选从加载期已经完成的 `Spec.Build` 捕获净空数据，经完整布局校验后，为实际车辆复制独立可变缓存，避免重复计算。

四次独立 Native 进程 ABBA 对照通过。**Flush 累计耗时降低 65.7%，首伤降低 85.8%，加载加三次破坏总计算成本降低 29.7%。** 同时保留不利结果：加载计算增加 **8.34%**，第二次破坏平均增加 **9.49%**；候选仍出现 **77/74 ms** 的 Flush，不能宣称卡顿全部消失。

实际 Web 匹配、开火和破坏采样也已完成：95 次 For 调用最大 6 ms，本轮未再观察到旧样本的 69～70 ms 冷 For 尖峰。当前三个生产模块与通过 Native/Web 验证的原始候选 SHA 完全一致，主 agent 已本地合入。仍有 91/88 ms 整帧，不能声称卡顿全部解决；不同对局不是匹配的 FPS A/B，本地合入也不等于骁龙 845/TapTap 持续 30 FPS 验收或发布完成。

## 基线、候选与审查

沿用冻结 manifest `c9350245`、提交 `f94827b26fc12b707e6d6904d093e16358caaf41` 的实际八辆 K 蓝图与 Native beta40 二进制。不是重新选择一批车，也不是以当前普通试玩构建取代固定 A/B 基线。

A/B 恰好三个候选模块不同。最终原始候选 SHA-256：

| 模块 | SHA-256 |
| --- | --- |
| `CarUnit.lua` | `ea8bf8203f9fcab8667b4a0df7a1f33abee39c6b0fe2540b8b2dcd69a7e5ae4c` |
| `TurretRange.lua` | `b0734f7b2eee60872422ee82517f19224ed50be63bf88a408fdb4c022a769942` |
| `SpawnSpecCache.lua` | `ffe78c8fab81793389e8f5b8c66baaa7b3db37987171c16f81fd442612006939` |

两端都在实验副本中插入相同的 `__ProbeCachePresent` 只读钩子，所以运行副本中 Range 的 hash 与上表原始候选不同；完整运行 hash 在 `identity.json` 中。没有用钩子修改缓存内容。探针 SHA-256 为 `5d580670def560de52cf1b7a226944c81c458452a3030092ad5de2d4f881f0a1`。

审查确认：原有 For/Evaluate 计算未改；Capture 保存独立快照；Adopt 校验全部 part、二进制位置、旋转、owner 和 `_cells/cells`，失败保留正常冷计算路径。rays、occ、context、range 等可变表复制到每个实例；仅原有只读 def/samples 和不可变 packed string 共享。token 与蓝图缓存均使用弱 key，无 value 到 key 的反向持有；场景缓存 Dispose 清理 token 句柄。取消或异常不会发布半个缓存。

v2 离线真实模块检查 **272 项通过**，含两车独立性、连续破坏/修复、完整规格对照、布局及 owner 类型负例、远处 disconnected 零件在 Unit.New 中剔除后重建、同步路径、cache miss、checkpoint 中源变化、Dispose 与协程取消。精确位置校验是审查后新增的补强，v1 结果没有作为最终候选验收依据。

同步重生也会采用缓存；其行为已离线覆盖，但此次 Native 只测加载期 Spawn，没有单独测同步重生的耗时。此限制不能省略。

## 实际负载与门槛

主 agent 串行运行 A1、B1、B2、A2，每进程 8 批全新空场景，每批 8 辆真实车，真实缓存 Prepare/Get、Spawn、每车连续三次 Destroy/Flush，并消费真实 CombatView。每进程 64 次加载、192 次重建；不是一场八车对局的墙钟时间。

自动 GC 保持开启，不强制收集；无地图、AI、武器开火、音频或实际画面呈现。checkpoint 仅验证单调数值、retain 与计数，不真实分帧等待，所以加载数字是累计计算成本，不能当成加载页等待时长或最大连续冻结。

独立分析和原始文件复核结果：

- 四进程全部退出码 0、无 Native ERROR，所有批次 native body 和场景释放检查通过。
- 768 条破坏行为、256 条初始元数据及 256 条加载记录通过；纯 Lua 蓝图/spec/HP/事件和其他车辆状态精确一致。
- A 实际蓝图均为冷缓存，B 均成功采用热缓存；cache hits 每批 1..8、misses 0。两端都没有额外 `.75` 预热 checkpoint。
- 原生状态沿用预先冻结门槛：每分量同时满足 2 个 float32 ULP 与绝对数值差 `1e-4`，位置欧氏偏移不超过 `1e-4 m`，余量 `1e-12`。
- 2,880 对状态、37,440 个分量全部通过，最大分量差及最大位置偏移均为 `0.0000019073486328125`（位置约 1.91 微米）。原始数值全部保留。

## 累计成本

以下是 A1/A2 和 B1/B2 各自平均，单位 ms，每进程累计 64 次加载、192 次重建。父子方法重叠，不能将 For、Spec.Build、Flush 相加；加载与 Flush 分属不同阶段，可相加。

| 范围 | A | B | 变化 |
| --- | ---: | ---: | ---: |
| Prepare | 3398.0 | 3615.0 | +6.39% |
| Spawn | 462.0 | 567.0 | +22.73% |
| Prepare + Spawn | 3860.0 | 4182.0 | **+8.34%** |
| Flush | 4083.5 | 1399.5 | **-65.73%** |
| 其中 TurretRange.For | 3630.0 | 912.5 | -74.86% |
| 加载 + Flush | 7943.5 | 5581.5 | **-29.74%** |
| 全部 setup + Flush | 8803.0 | 6448.0 | -26.75% |

| 每次破坏 Flush 均值 | A | B | 变化 |
| --- | ---: | ---: | ---: |
| 第一次 | 49.03 | 6.95 | **-85.83%** |
| 第二次 | 7.49 | 8.20 | **+9.49%** |
| 第三次 | 7.28 | 6.72 | -7.73% |

所有轮次都保留，未只摘首伤收益。先前 priming 实验的加载 +125%、总成本 +31% 仍保留在独立报告中，不能用本次结果覆盖旧失败；两次实验分开运行，不能把彼此绝对值当作同一次直接 A/B。

## 尾部与剩余热点

P95 为 nearest-rank `ceil(n*0.95)`，不插值；每行每轮有 64 个样本。

| 进程 | 首伤均值 / P95 / 最大 | 第二伤 P95 / 最大 | 第三伤 P95 / 最大 | 全 192 次 >80 ms |
| --- | --- | --- | --- | ---: |
| A1 | 49.34 / 141 / 157 | 14 / 20 | 14 / 15 | 8 |
| B1 | 6.92 / 14 / 15 | 14 / **77** | 14 / 19 | 0 |
| B2 | 6.97 / 14 / 16 | 14 / **74** | 14 / 14 | 0 |
| A2 | 48.72 / 139 / 155 | 14 / 20 | 14 / 77 | 8 |

本样本候选 384 次 Flush 中没有 >80 ms，不能推广为整帧或长期对局不存在 >80 ms。

候选的最大两条都位于 **batch 5 / unit 2 / 第 2 次破坏**：B1 Flush 77 ms，其中 `bp.Graph` 64 ms、For 9 ms；B2 Flush 74 ms，其中 `bp.Graph` 60 ms、For 9 ms。这是下一步应拆分的实际观测区域，不是继续猜 AI。包围计时尚不能区分 Graph 内算法、分配或自动 GC，不能直接宣布根因是 GC。

缓存复制有内存成本：离线统计每份快照/采用涉及 180～2250 个可变表，逻辑 packed string 载荷因车而异，最大约 351 KB，string 本体共享。此统计不是 Lua 实际分配字节，不代表内存已经下降；需要持续游戏和卸载后的内存曲线。当前释放检查证明 native/scene 所有权清理，不证明 Lua allocator 立即归还内存。

## 实际 Web 对局与独立复核

证据目录为 `docs/migration/evidence/monitor-combat-adopt-2a92-a/`。
`report.json` 为 PASS，Runtime 与 HTTP 错误均为 0，运行器最终 CLOSED。
已通过公开匹配入口进入、实际开火破坏及公开返回大厅。受控摆位用于确保
真实车辆互见和交火；这是桌面浏览器的约 45 秒归因采样，不是自然完整一局
或 TapTap 真机长时间测试。

本次是原来的 8 辆真实车和 7 个 AI，并未减少阵容来换取结果。采样记录
1143 发射击、1265 次世界命中计数、玩家受伤 686，零件数从 1275 开始，
最低 915、结束 992；世界命中不是玩家专属命中，结束零件数也会受修复和
重生影响。实际破坏工作量存在，不能把本次数据描述为空场或关闭开火。

独立复核检查了 capture、运行日志、监控 JSONL 和 report 的 SHA，并从
capture 的原始 frameIds/wallMs 重新核对完整帧间隔，从已绑定源 SHA 的
逐帧监控记录重新累计 For。共排除首尾两个不完整观察帧，保留 1371 帧；
engine/monitor 的固定偏移为 -911，1351 帧间隔精确匹配，20 帧差 1 ms，
没有插值或补造缺帧。

| 项目 | 本轮观察值 |
| --- | ---: |
| 完整帧累计时间 | 45051 ms |
| 平均帧间隔 / 换算速率 | 32.860 ms / 30.43 FPS |
| P50 / P95 / P99 | 30 / 60 / 69 ms |
| 最大帧间隔 / >80 ms 帧数 | 91 ms / 2 |
| For 调用 / 累计 / 单次最大 | 95 / 218 ms / 6 ms |
| For 所在帧 | 91 |
| Spec.Build 单次最大 | 7 ms |
| unit.Flush 单次最大 | 28 ms |
| 平均固定模拟步 / 帧 | 1.972 |
| 平均脚本包围计时 / 帧 | 21.570 ms |

以上 FPS 是本轮总帧数除以总帧间隔，不是瞬时 FPS 平均，也不是本次优化
带来的 FPS 增幅。旧对局、观察探针、伤损和重生时序不同，不能将两次整场
FPS 相减归功于本改动。旧冷暖细分原件为
`evidence/monitor-combat-turret-2a92-c/independent-turret-attribution.json`：
5 次实际蓝图冷 For 最大 70 ms，其中 3 次 Evaluate 各 69 ms；本轮 95 次
For 最大 6 ms。这个结果支持“复用已算数据后，本轮未重现该冷计算尖峰”，
不证明所有潜在冷路径或以后每场对局均不存在此类开销。

独立复核还逐一比对了当前生产三模块、Native 归档原始候选及实际 Web
identity 中的脚本 SHA，全部等于前文候选表；原 For/Evaluate 的采样数学未改。
未合入额外 priming 或 sampled-deletion 候选，不能将几个候选收益叠加。

## Web 剩余长帧与持续负载

两帧超过 80 ms 的记录如下；self 值是排除已测子方法后的包围墙钟范围，
仍可能包含该范围中的自动 GC、原生调用或调度。

| engine / monitor 帧 | 帧间隔 | 脚本 | 固定步 | Flush / Spec.Build | 最大已测 self 范围 |
| --- | ---: | ---: | ---: | --- | --- |
| 3769 / 2858 | 91 ms | 49 ms | 2 | 0 ms / 无调用 | ai.Step 33 ms，12 次中最大 27 ms |
| 4465 / 3554 | 88 ms | 56 ms | 2 | 0 ms / 无调用 | legGait.Step 37 ms，4 次中最大 35 ms |

两帧都没有当帧零件数下降或重建，故不能继续将它们归因于炮管净空或
Flush。对应 Lua heap 比前一帧下降约 14044 / 17526 KiB，说明时间上相关，
不证明 GC 就是原因，也不证明 AI 或步态算法本身占用了这些全部时间。
必须继续在这些包围区域内细分，保留自动 GC/分配及调度的归因边界。

持续负载也仍存在。该样本中较大的平均 self 范围包括 effects.Update
2.17 ms/帧、AI 1.66、weapons.Step 1.52、physics.Step 1.36、playerView.Update
1.35、environment.Update 1.30、legGait.Step 0.92。它们是本次实际观测的后续
拆分入口；不能把整帧减去脚本的差额直接命名为 GPU 时间。

47 份带保留状态的上下文中，大厅、建造、地图预览、开篇及后台资源标记均
未见激活或保留；这是对“后台还在跑其他场景”怀疑的当前观察证据，不能
扩展成所有共享资源已卸载、没有内存泄漏或 allocator 已归还内存的证明。
45 秒采样及周期性 heap 回落也不足以验收长期内存和发热。

## 下一步与交付边界

实际 Web 验证已完成并本地合入，下一步重点是剩余 AI/步态包围长帧、Native Graph 尖峰、持续模拟成本，以及缓存取消、换图、退出重进。还需验证同步重生、大车、转子、修复、完整战斗与长期内存。最终持续 30 FPS 仍必须在 TapTap 骁龙 845 真机验证；桌面 Web 短时平均 30.43 FPS 不代替该验收。

Native 实验、Web 实际运行及生产三模块合入由主 agent 执行。本次独立复核只读原始证据、更新报告，没有再改生产代码或原始证明文件，也没有提交或上传 Git。`LOCAL_MERGED_DEVICE_OPEN` 仅表示本地采用通过当前检查的候选，真机与最终发布验收仍开放。

## 持久证据

`docs/migration/evidence/native-damage-adopt-2026-10-17/` 已保存 **49 份原始副本**：

- `originals/`：四进程全部 JSON、stdout/stderr、launch/process/validation、identity、独立分析。
- `A/`、`B/`：实际运行的三个模块、探针和 roster。
- `candidate/`：最终三个原始候选及 API 源；`tools/`：生成、检查、准备、运行、分析和归档工具。
- `offline-correctness.json`：最终 v2、272 项结果；`distributions.json`：原始值派生分布。
- `archive-sha256.json`：每个原始副本的大小与 SHA-256，复制后校验；工具拒绝覆盖已有归档。

全部输入、Runtime 和资源哈希在 identity 中；完整二进制、资源和无关脚本未重复归档，因此不是独立可运行游戏包。

Web 原件和派生分析另在 `evidence/monitor-combat-adopt-2a92-a/`：
`report.json`、`capture.json`、`runtime.log`、`production-perf.jsonl`、
`independent-adopt-attribution-frames.json` 与
`independent-adopt-attribution.json`。独立复核没有覆盖或改写这些文件。
