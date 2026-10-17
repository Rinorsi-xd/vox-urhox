# Web 战斗同次采集：逐帧与 CPU trace 对照

日期：2026-10-17。证据目录：`docs/migration/evidence/performance-fixed-step-pipeline-match-1792181476009/`。

## 已确认与未确认

本次诊断窗口存在明显的主线程 CPU 计算负担，固定步更新是已测范围内最大的持续开销。周期性尖峰分别落在固定步前处理、普通 Update 和 PostUpdate；目前不能把它们全部归给某个 Lua 模块、Lua GC 或 GPU。

**本次不是优化前后 A/B，也不是发布版 FPS 验收。** 采集同时启用了粗粒度 Lua 包装、控制台时间锚、CDP CPU 采样和 trace。诊断本身有开销，不能用本次约 68 ms 的 MainLoop 均值声称发布版变慢，更不能声称优化已改善。没有骁龙 845 或 TapTap 真机持续性能结果。

## 构建与场景

- H5 基线：`2026-10-15`，提交 `b276064942ae09c0227ec28d4cfda1d5ff006455`。
- 目标提交记录：`f94827b26fc12b707e6d6904d093e16358caaf41`；实际脚本另由包内 SHA-256 固定，不能仅以提交号代表工作区内容。
- 测试包：`manifest-b88e4703.json`，端口 4517；本次不是用户浏览器中端口 4471 的直接采集。
- `main.lua` SHA-256：`9de4747691f59aa1e5ffa2159308955d4bca0b57e520b6a3fa361bed7fa16987`。
- pipeline 探针 SHA-256：`61d75bec51f96bdabfb03a2376f4bffd0a2374ac5d5daf061bdfaefe116ada30`；完整固定步源文件身份见 `result.json.framePipelineIdentity`。
- 真实 `match / conquest` 路线，前台且未最小化，保持驾驶与开火。请求输入 10,000 ms，观测输入 10,955 ms，观测 held-input 10,813 ms。
- 正式 PerformanceMonitor 和 QA 战斗方法计时均关闭；本次启用的是独立 frame-pipeline 诊断，不能称完全无探针。
- `errors`、`httpErrors`、`probeIssues` 均为空，测量状态 PASS；返回大厅后战斗 scene/world/effects/view/HUD 已退休，测试进程 CLOSED。

## 同次 trace 的 CPU 证据

| 范围 | 样本数 | MainLoop wall | 主线程 CPU | wall 减 CPU |
| --- | ---: | ---: | ---: | ---: |
| 完全位于 held-input 内的 MainLoop，均值 | 156 | 68.305 ms | 65.752 ms | 2.553 ms |
| 最慢 MainLoop | 1 | 116.470 ms | 112.076 ms | 4.394 ms |

约 96% 的 MainLoop wall 对应记录到的主线程 CPU 时间，说明这些长循环主要在执行计算。该比例仅描述本次 MainLoop，不能代表整个浏览器、GPU 或其他线程的负担。

Lua 帧与 trace 使用有界时钟锚对齐，epoch-minus-trace 区间为 `[1792042235591.581, 1792042235594.581]` ms，宽度 3 ms。**只有 23 帧具有直接且唯一落在一个 MainLoop 内的控制台时间锚。** 其他帧没有直接配对，禁止按稀疏锚的顺序插值。

| 直接配对帧 | MainLoop wall / CPU | 固定步数 | Lua main.Update | 其中 fixed.BeforeStep | Lua main.PostUpdate |
| --- | ---: | ---: | ---: | ---: | ---: |
| 6074 | 99.049 / 97.566 ms | 4 | 41 ms | 22 ms | 39 ms |
| 6094 | 116.470 / 112.076 ms | 5 | 89 ms | 67 ms | 10 ms |

6074 的尖峰出现在 PostUpdate，6094 则出现在 BeforeStep。`BeforeStep` 的 67 ms 是该帧 5 次调用的合计，最大单次为 41 ms。不能由此说每次都要 67 ms。Lua callback 帧和 MainLoop 的边界不同，表中的两种时间不能相加或互相扣减。

## 连续 Lua 帧构成

帧 6057–6213 共 157 个完整帧，无缺口、无报告丢帧、无分析问题；总计 654 个固定步，平均每帧 4.166 步。

| 已测范围 | 平均每帧 wall |
| --- | ---: |
| fixed.BeforeStep | 28.248 ms |
| fixed.WorldStep | 6.025 ms |
| fixed.AfterStep | 3.006 ms |
| main.Update 自身，扣除上述三个子范围 | 10.834 ms |
| main.PostUpdate | 4.115 ms |
| ui.Render | 3.006 ms |
| ui.Update / main.FramePresented | 0.045 / 0.013 ms |
| 未被上述 callback 范围覆盖的 wall | 14.000 ms |

三个固定步范围合计平均 37.280 ms/帧、8.950 ms/步。`main.Update` 包含它们，不能再将其 inclusive 48.115 ms 重复相加。14 ms 未覆盖时间没有 CPU/GPU/等待归属。其他 Update 还包含固定步周边工作及观察器；8.950 ms 也不等于整个模拟步的全部成本。

大量补步会放大每帧模拟成本，但“长间隔后补步更多”本身不能证明最初尖峰的来源。当前证据支持优先拆解固定步前处理，并独立追查跨阶段的周期性 CPU 尖峰。

## 不能越过的归因边界

- 本次 V8 GC 事件最大 1.581 ms，不能解释已观测的数十毫秒尖峰；这是 JS/V8 GC，**不代表 WASM 内 Lua GC**。
- raw trace 没有 `GetProgramiv` / `GetShaderiv` 名称事件。没有 GL 查询长等待的直接证据；事件缺席也不能据此排除 GPU 或驱动开销。
- CPU profile 热样本包含 `wasm-function[9978]`、`wasm-function[3264]`。目前无符号映射，所属函数未知，不能写成“已定位 Lua GC/物理/某段 Lua”。采样权重是统计估计，不是精确函数耗时。
- 本报告没有关闭、降低或替换任何正式玩法、画面、固定步频率或 GC；没有新增生产优化。

## 下一步实验，尚未执行

在同一真实战斗进程做有界的自动 Lua GC A1/B/A2：正常采集 → 短暂关闭自动收集 → 恢复并单独隔离偿债阶段 → 正常采集。只允许在加载与退休工作完成、无显式 GC、车辆负载稳定且前台的窗口比较；内存增长、超时、异常或进入菜单时立即中止并恢复。`collectgarbage('stop')` 不会阻止显式 `step/collect`，必须同时记录这些调用。

此实验仅用于验证自动 Lua GC 是否参与尖峰，不能把禁用 GC 作为发布优化，也不能承诺帧间守卫能拦住不可中断帧内的内存暴涨。最终收益仍须同构建、同负载、轻量监控或关闭监控的优化前后对照，再单独做 TapTap 骁龙 845 持续 30 FPS 验收。

## 复核与资料

只读加载分析器导出函数，从 `drive.cpuprofile`、`drive.trace.json`、`frame-pipeline.jsonl`、`console-timeline.jsonl` 重新计算，已逐项比对 `cdp-summary.json`、`frame-pipeline-summary.json`、`frame-trace-correlation.json`，全部一致。未重新运行硬件测试或改写原始证据。

原始采集、源身份、输入与返回状态见 `result.json`；完整事件见 `runtime.log` / `states.jsonl`；`before-drive.png` / `after-drive.png` 记录测量时画面。分析器为 `tools/migration/analyze-combat-cdp.cjs`、`analyze-frame-pipeline.cjs`、`analyze-frame-trace.cjs`。本次仅新增本报告。
