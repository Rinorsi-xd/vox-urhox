# 0bae 实际八车长帧逐帧归因

日期：2026-10-17。此项仅离线重算已有实际采样，未启动 Runtime/浏览器、未改生产。

输入 `evidence/monitor-combat-heightfield-0bae-a/capture.json` 与 `production-perf.jsonl`，独立结果 `independent-spike-attribution.json`。实际 manifest 为 `0baeef97`。沿用已有完整帧解码器，从原始日志重算字典、所有 compact samples、上下文与 slow_frame，未把旧包阶段平均值拼到新包帧。

## 对齐和全帧成本

1,285 完整帧 / 45,085 ms，平均 35.0856 ms（28.5017 FPS），P95 68 ms、最大 117 ms、11 帧大于 80 ms。engineFrame→monitorFrame 的唯一最佳偏移为 -1005；1,263 帧完全相等，其余 22 帧差 1 ms，最大差 1 ms。次佳偏移只精确匹配 93 帧，故没有靠任意挪帧凑归因。

测量脚本范围平均 23.0879 ms/帧，Update 起点到 EndFrame 平均 34.3751 ms，其余约 11.2872 ms 在此窗口内但不属于已包装脚本；下一帧起点前另有约 0.7105 ms。它们均为墙钟剩余时间，不是已测 GPU CPU 或 GC 时间。每帧平均 2.1058 个固定步。

最大持续 inclusive 范围为 BeforeStep 10.1214 ms/帧，其中 Vehicle.Step 5.2700 ms；这些包含下属，不能相加。较大的独占范围为 Effects 2.1307、AI 1.8148、物理 1.6132、武器 1.5502、环境 1.4809、全车 DriveView 1.1728 ms/帧。名称 `playerView.Update` 实际聚合所有 DriveView，不能理解成只有玩家车。

## 11 个长帧

以下“脚本”是 monitor 已测顶层脚本墙钟；“End内余”是 EndFrame 窗口扣脚本，“End后”是该窗口结束到下帧。三者按原记录相加等于对应 monitor 帧间隔；表内 engine 帧间隔可能有 1 ms 时钟量化差。

| engineFrame | 总 ms | 脚本 ms | End内余 ms | End后 ms | 最大记录独占段 | 实际变化 |
| --- | ---: | ---: | ---: | ---: | --- | --- |
| 3398 | 93 | 43 | 13 | 37 | Contact 23 ms | 零件不变 |
| 3399 | 88 | 27 | 15 | 46 | Physics/Objectives 各 3 ms | 命中 +2 |
| 3445 | 82 | 67 | 14 | 1 | BeforeStep self 28 ms | 命中 +1 |
| 3449 | 82 | 39 | 42 | 1 | AI 10 ms | 命中 +4 |
| 3890 | 86 | 19 | 11 | 56 | Objectives 3 ms | 命中 +2 |
| 4001 | 82 | 71 | 11 | 0 | Effects self 44 ms | 零件 -1、Flush 11 ms inclusive |
| 4234 | 82 | 72 | 10 | 0 | Hover 47 ms | 零件 -1、Flush 8 ms inclusive |
| 4291 | 81 | 70 | 10 | 1 | Thruster 48 ms | 零件 -1、Flush 8 ms inclusive |
| 4406 | 117 | 67 | 11 | 39 | Environment 52 ms | 零件 -1 |
| 4464 | 85 | 76 | 8 | 1 | BeforeStep self 58 ms | 零件 +152、AddPart 152 次 |
| 4648 | 92 | 35 | 57 | 0 | Flush self 15 ms | 零件 -1、Build 4 ms |

4464 有真实重生装配证据，是明确仍需处理的同步生成路径；但它不能解释另十帧。多个看似很轻的控制/显示方法偶发占有 20–50 ms 墙钟，现有数据只能确认停顿发生在其边界里，无法判定是该算法计算、Lua GC、原生调用或线程停调度。尤其 3890 的 86 ms 仅 19 ms 测量脚本，直接继续微调某个 Lua 算法不能解释其 67 ms 差额。

Finalize 平均 0.2202 ms（含 Emit 0.0591），Context 0.0661；最慢 117 ms 帧这三项都为 0。归因不能把它当成日志序列化卡顿。55 份上下文的大厅/建造/预览/开场均无存活标记；backgroundResources 有 1 份为真，不能宣称后台资源始终为 0。堆下降不构成 GC duration 证据。

## 下一项真实采集

复用同一 monitor-combat 公开八车入口，保留原生产监控与三粗粒度 observer，不新增 Lua per-method wrapper；只给浏览器 runner 增加可选 CDP 采集。采集 MainLoop 原生墙钟、可用线程 CPU 时间、V8 GC trace、WASM/JS 统计栈、同步 GL/着色器事件及线程元数据，同时记录带误差界的 CDP 单调钟/epoch 锚点。

必须保留缺失事件、未知符号、没拿到 tdur 和未匹配帧。CPU profile 是统计样本，不是精确 Lua 函数计时。V8 GC 事件缺席不排除 Lua GC，因为 Lua VM 与其回收器运行在 WASM 中；未被命名的 WASM 样本需要引擎符号才能进一步定位。Trace 里的等待不直接代表 GPU 执行。实际 trace 完成并解析之前不宣称新的根因或收益，845/TapTap 持续 30 FPS 仍 OPEN。
