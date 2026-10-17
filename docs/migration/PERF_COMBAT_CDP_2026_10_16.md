# 实战 CDP 长帧定位

2026-10-16。本轮只分析已经结束的测试；没有重新启动浏览器或 Native，没有改生产代码。

结论：驾驶期仍有首次 shader 编译与 WebGL 同步查询等待，已确认能贡献长帧。174 / 171 ms 的主循环不能全部归因于该等待，也不能从尚无符号的 WASM 样本断言剩余开销属于哪段 Lua。本轮是有 CDP 扰动的诊断运行，不证明候选比旧版更快，也不证明稳定 30 FPS。

## 原始证据

证据目录：[performance-uninstrumented-match-1792163190043](evidence/performance-uninstrumented-match-1792163190043)。

- [result.json](evidence/performance-uninstrumented-match-1792163190043/result.json)：PASS / CLOSED，`manifest-fb3e73b7.json`，监控和 QA battleTiming 均关闭，真实匹配入口及持续 W / 左键。
- [drive.trace.json](evidence/performance-uninstrumented-match-1792163190043/drive.trace.json)、[drive.cpuprofile](evidence/performance-uninstrumented-match-1792163190043/drive.cpuprofile)：浏览器原始事件和统计采样。
- [console-timeline.jsonl](evidence/performance-uninstrumented-match-1792163190043/console-timeline.jsonl)、[runtime-alignment.jsonl](evidence/performance-uninstrumented-match-1792163190043/runtime-alignment.jsonl)：控制台与主机单调时钟对齐。
- [windows.json](evidence/performance-uninstrumented-match-1792163190043/windows.json)、[states.jsonl](evidence/performance-uninstrumented-match-1792163190043/states.jsonl)、[cdp-summary.json](evidence/performance-uninstrumented-match-1792163190043/cdp-summary.json)：引擎 TimeStep 窗口、运行状态和线程概览。

正式输入从主机单调时钟 `121108125 ms` 到 `121138355 ms`。起止 CDP Timestamp 与主机请求前后界均已保存，开始界宽约 1 ms。以下两帧发生在输入期间，不是进入对局前。

## 两个最长 MainLoop

| 项目 | 第一帧 | 第二帧 |
| --- | ---: | ---: |
| trace FunctionCall 起点，微秒 | 121109054091 | 121109394266 |
| 相对输入起点 | +929.091 ms | +1269.266 ms |
| `MainLoop_runner` wall 耗时 | 174.132 ms | 171.315 ms |
| 该区间 CPU profile 样本数 | 113 | 110 |
| `GetProgramiv` 最大子段 wall | 38.888 ms | 9.056 ms |
| `getProgramParameter` 采样权重 | 38.638 ms，25 次 | 9.477 ms，6 次 |
| `_emscripten_get_now` 采样权重 | 20.396 ms，13 次 | 9.404 ms，6 次 |

两帧的外层 RunTask / BeginMainFrame / FireAnimationFrame / FunctionCall 是同一调用的嵌套记录，不能相加。GetProgramiv 内的 GetBucketContents / WaitForCmd / Finish / WaitForGetOffset 也是同一段同步等待链，不能重复相加。采样权重只是按采样间隔加权的统计归属，不是函数精确 CPU 计时；可能包含等待。

第一帧还出现 GetShaderiv 1.880 / 1.463 ms；第二帧为 0.669 / 0.567 ms。第一帧采样除 GL 查询外，还落在无符号 WASM 767、28149、15584 等位置；第二帧主要另见 WASM 629、767、985 和时钟查询。不能把这些编号写成某个 Lua 函数，也不能把未归因部分全部记成 GPU。

## 驾驶后仍发生 11 条 shader 编译

console-timeline 记录了 11 条 `Succeed to compile shader`。相对输入起点的接收时间为：996、1054、1361、1423、1554、1593、4195、5981、7568、7932、11553 ms。接收时间是日志观测时刻，不能当精确编译起止时间。

最前两条发生于第一长帧附近，资源 UUID `AtVPmSrO6hq_hOpHbGjjLYBv` 可准确对应现有 `assets/Shaders/BLGL/Equipment/Thruster.shader.meta`，是推进器 shader 的 VS / FS。1554 / 1593 ms 的 `DlIHeSI61Gygpjm0uPuo21yl` 对应 `Equipment/Mote.shader.meta`。第二长帧附近的 `BRxG8T6shu9NGQ68UtF_Lkgf` 未在现有 assets 的 meta 中找到，暂不猜来源。

后续还有 PBR 和 light / shadow 变体。由成功日志、相邻 GL 查询和等待事件可以确认“驾驶开始后还在编译 / 查询程序状态”，但不能声称每条编译都导致同样长的停顿。下一步应把实际使用的变体纳入加载屏障内的真实绘制预热，再用同构建相同路线验证这些驾驶期日志及同步等待是否消失。

## GC、线程和监控扰动的边界

全 trace 有 94 个 GetProgramiv 完整事件，最大 50.142 ms。Renderer 主线程最大 RunTask 174.390 ms；Browser 主线程最大事件 9.314 ms；GPU 进程 CrGpuMain 最大事件 49.944 ms。后者是 GPU 进程的线程 wall 事件，不是显卡硬件执行时长。

V8 MajorGC 共 1 次，最大 3.089 ms；MinorGC 22 次，最大 1.304 ms。这些已命名的 JavaScript GC 记录不支持“这两帧主要被 V8 GC 卡住”，但无法排除 WASM 内部的 Lua GC，因为它没有对应符号和独立计时。

合并相同函数名的采样终端后，WASM 9978 为 2559 个样本 / 3775.978 ms 权重，3264 为 1463 / 2153.235 ms；这是本次采样中的热点，尚不能解释成具体 C++ 或 Lua 职责。实际 `.tmp/web-engine/UrhoXRuntime.wasm` 为 36,101,246 字节，无任何 custom section，因此本文件没有 name / DWARF；同目录 JS 没有 sourceMappingURL。未找到这些索引的可靠符号映射。需要匹配此构建的引擎符号表，或在已确认的游戏 / 引擎入口补分段实测，不能靠编号猜测。

Gameplay PerformanceMonitor / battleTiming 关闭不等于没有观测成本：现有 QA app timing wrappers、每 500 ms F8、自动状态打印、CDP 采样和多类别 trace 仍存在。采样中 `print` 有 39 次 / 61.274 ms 权重，时钟查询也有样本；这些不能全部归为 QA，不能用来推算 QA 总开销。trace 本身约 176 MB。本轮数据只适合定位，不能与无 trace 的一次驾驶直接算优化收益。

## FrameStats 不能当原始墙钟帧长

本次 FrameStats 最大仅约 72.685 ms，实际浏览器 MainLoop 已有 174.132 ms。两长帧位于有效窗口覆盖的驾驶时段：第二窗口于输入后 1132 ms 收到，第三于 2044 ms 收到，前者 max 68.992 ms，后者 max 72.685 ms。

原因边界明确到观测源：probe 使用 Update 事件的 `TimeStep`，不是相邻呈现帧或 MainLoop 的原始墙钟间隔。引擎暴露 `timeStepSmoothing` 等 API，但本轮没有记录实际平滑 / 钳制设置，因此不猜具体变换。应将这些窗口称为“引擎 TimeStep 统计”，不能以“窗口无 >80 ms”证明实际没有 >80 ms 停顿。

驾驶结尾车靠近墙且速度约 0.069 m/s，路线没有持续覆盖高压近距离交火；命中、破坏、死亡和长时间运行仍未验证。旧新各一次的随机阵容 / 轨迹 / 遮挡差异也仍存在，参见 [无监控对比报告](PERF_UNINSTRUMENTED_COMPARE_2026_10_16.md)。只能确认 shader 首用等待是一个已测到的问题，持续 CPU 模拟开销和无符号引擎部分需要继续拆分，不能承诺不回归或骁龙 845 / TapTap 稳定 30 FPS。

## 推进器与浮尘预热后的新实测

新增证据：[performance-uninstrumented-match-1792164528056](evidence/performance-uninstrumented-match-1792164528056)。包为 `manifest-8d107d95.json`，QA 端口 4483，H5 基线仍为 `2026-10-15@b276064942ae09c0227ec28d4cfda1d5ff006455`。真实匹配入口、持续 W / 左键、返回大厅的 19 项功能检查通过，错误 0，最终 `PASS / CLOSED`。下述分析使用已经结束的同一次运行的 `result.json`、`runtime.log`、`runtime-alignment.jsonl`、`drive.trace.json` 和 `drive.cpuprofile`，没有再开第二个硬件测试。

原始 Update 入口墙钟采样覆盖 781 个间隔、30,779 ms；相对实际输入时段 30,840 ms 的覆盖率为 99.802%，没有排除窗口。均值 39.410 ms，P50 / P95 / P99 为 36 / 65 / 80 ms，最大 139 ms，严格大于 80 ms 共 7 个。它包含引擎、等待与观测开销，不是 CPU 耗时或呈现 FPS；不能用均值倒数宣称游戏帧率已通过。

### 预热已实际覆盖的变体

旧包 `runtime.log` 第 2598 行于 23:08:55 关闭陨坑加载页，推进器 `AtVPm` 的 VS / FS 在 2644 / 2646 行、23:09:04 才编译，浮尘 `DlIHe` 在 2658 / 2660 行、23:09:05 才编译。

新包推进器 VS / FS 在第 2333 / 2335 行、23:31:11.336 / .387 编译，浮尘在第 2345 / 2347 行、23:31:11.592 / .631 编译；陨坑加载页直到第 2629 行、23:31:30.774 才关闭。驾驶输入期间没有再观察到这两种 shader 的编译。这证明这四个已观察变体被移入加载屏障，不能证明全部变体已预热。

### 驾驶期间仍有地图变体编译

以主机单调时钟 `122463503 ms` 为输入起点，日志接收相对时间为 +1391、4160、6673、6995、8148、10387 ms，共 6 条。全部是 VS；前两条来自 `Crater/Scatter.shader` 的点光 / 阴影变体，随后可对应 `Map-MAP_ROCK-MAP_VBAKE.shader` 和 `Map-MAP_BAKE-MAP_PANEL-MAP_SOOT.shader` 的 shadow 变体。其余 UUID 为 `FNsCAaKHZLMOTJrbrNkfVvKN`、`D7Wz4TZ7pK_vv6_gMuK9pMI1`，本轮未确认资产映射，不推测来源。日志接收时刻包含传输延迟，不是精确编译起止时间。

### 最长帧仍分为同步等待和 CPU 忙两类

| MainLoop 相对输入起点 | wall | trace 记录的线程 CPU | 最大 GetProgramiv 子段 wall / CPU |
| --- | ---: | ---: | ---: |
| +1321.402 ms | 138.347 ms | 99.026 ms | 35.280 / 0.257 ms |
| +4090.973 ms | 88.248 ms | 75.336 ms | 10.276 / 0.094 ms |
| +10455.910 ms | 83.551 ms | 82.830 ms | 无长查询，仅小于 0.1 ms 的 Flush |
| +22867.580 ms | 82.141 ms | 77.999 ms | 无长查询，仅小于 0.1 ms 的 Flush |

第一帧 `GetProgramiv → GetBucketContents → WaitForCmd → Finish → WaitForGetOffset` 是同一嵌套等待链，不能相加；35.280 ms wall 中记录的线程 CPU 只有 0.257 ms，支持同步查询阻塞的归因。CPU profile 同期 `getProgramParameter` 为 22 个样本、34.588 ms 权重，与该等待位置一致。第二帧的 10.276 ms 查询亦是同类等待。

后两帧线程 CPU 接近整帧 wall，且没有长 GL 同步子段，证明还有独立的 CPU 忙帧。采样主要仍落在无符号 WASM 9978、5650、629、767 等索引，不能从索引断言某个 Lua 函数或具体机制是根因。新 trace 输入期 `GetProgramiv` 共 61 个、最大 35.280 ms；`GetShaderiv` 1 个、0.746 ms。已命名 V8 MajorGC 2 个、最大 9.474 ms，MinorGC 53 个、最大 1.877 ms；不支持把上述最长帧全部归因于 V8 GC，Lua GC 仍未独立归因。

### 本次可以关闭与尚不能关闭的验收项

可关闭的是“推进器与浮尘上述 VS / FS 在驾驶时首次编译”的已复现缺口。地图点光和阴影变体预热仍未完整；CPU 忙帧仍需真实 Lua / 引擎分段计时或该构建的符号映射，继续定位车辆模拟、固定步补跑及其他 CPU 工作的各自占比。

旧包阵容合计 941 个零件，新包 939 个，随机阵容与运行轨迹没有锁定。新包驾驶结尾车辆堵在箱体附近，缺少持续近距离交火、破坏与重生覆盖。这两次不是受控 A/B，不能将长帧或均值差异宣称为优化收益。CDP、QA 状态采集及 trace 本身仍有观测扰动。骁龙 845 在 TapTap 内长时间稳定 30 FPS 的验收尚未进行，也未通过。
