# G3: 连锁破坏邻接缓存清理

日期：2026-10-16。对齐 H5 2026-10-15 基线 `b276064942ae09c0227ec28d4cfda1d5ff006455`。

## 状态与边界

生产源码已修改，Lua 5.4 离线等价性与负控通过。尚未构建进入 Web/原生试玩包，没有真实设备帧时间验收。

此修改发生在父任务冻结 `.tmp/outgame-cached-1792112558349` / `manifest-f56e5c62.json` 之后，**不包含在 f56e 包内**。

## 已确认的重复工作

`CarUnit:Flush()` 对脱落组件逐个调用 `Blueprint:Remove()`。原实现每次删除都遍历整个 `_neighbors` 缓存，从所有缓存行删除该 ID。邻接图已缓存，但清理缓存仍随每次脱落重复扫描整车。

使用实际生产 `CarUnit`、`Blueprint`、`Prefab`、零件数据；只以适配器替代原生载具/碎块工厂。对冻结的 f56e Blueprint 与新实现执行相同伤害和 Flush：

| 预设与攻击目标 | 删除次数 | 原整表缓存行扫描 | 新整表缓存行扫描 | 新处理入边 | 剩余零件 |
| --- | ---: | ---: | ---: | ---: | ---: |
| vanguard / 159 | 63 | 20,034 | 0 | 119 | 287 |
| scorpion / 1540 | 7 | 10,871 | 0 | 23 | 1,550 |

这证明消除了此处的整表重复遍历，不等于证明原生或 Web 破坏卡顿已消失。

## 修改

仅修改 `scripts/construction/Blueprint.lua`：

- 为已缓存的邻接行维护入边反向索引 `_neighborOwners[target][source]`。
- 删除零件时，立即清理自己的缓存行与真正引用该零件的缓存行。
- Add 仍按原空间相邻范围失效缓存，同时清理反向索引；Clear 同时清空两者。
- 不依赖 socket 图对称性，不改变删除顺序或延迟任何破坏操作。

没有修改 CarUnit、伤害值、碎块上限/寿命/碰撞、物理步长、随机序列、特效或可见表现。

## 验证

运行：

```powershell
& 'C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' tools/migration/check-neighbor-removal.py
```

通过内容：

- 10 辆预设车，每车前 16 件逐次删除/还原，再 Clear/重新添加核心。
- 每步 Graph 与逐零件重新查询 socket 的完整图一致；调用方修改 Graph 不污染缓存。
- 每步反向索引精确对应缓存中的实际边，无悬空/过期索引；删除后不重新计算 socket。
- 人工非对称与部分缓存的删除、还原验证。
- 两辆桥接断裂车，实际伤害、脱落数量、Blueprint、车辆描述、HP/护盾、事件、碎块分组、状态和后续 RNG 相同。
- 复用完整 `check-damage-rebuild.lua`，以冻结 f56e Blueprint 和当前其他生产模块作对照，**1,924 项检查通过**，包含 10 预设逐次伤害、核心死亡、战斗重装及修复。
- 两个负控均失败于对应不变量：漏注册反向入边、失效缓存行时漏清除反向索引。

证据：`docs/migration/evidence/neighbor-removal-2026-10-16T01-08-57-573873Z.json`（本地忽略的运行证据）。细粒度结构断言数是 11,345,713，主要来自逐边双向不变量检查，不作为功能验收项数量。

生产 Blueprint SHA256：`25abcd3130c3518b733a5745da374ff402c38e245d39debfb841b7f28b2e76cf`。

对照 Blueprint SHA256：`306169085c5f6c18d96743b179cb824ab80c7763e4322ed65f8d805c2310e529`。

## 历史检查限制

同时运行原 `check-vehicle-checkpoints.py --damage-rebuild` 时，它对 `.tmp/damage-before-2026-10-15` 的旧四模块快照，在 pristine raceCar 的 `spec.boxes.1.half.2` 已失败，尚未进入伤害流程。该旧 VehicleSpec 的 MergeBoxes 尚无当前已提交的质量约束，碰撞盒本就不同。没有放宽该历史断言，也没有将其标记通过。

本批完整回归使用 f56e Blueprint 加当前生产其他模块，隔离本次缓存清理改动。历史 H5 碰撞盒基线差异应由驾驶/物理验收另行跟踪。

## 热加载与协程所有权

`app/HotReload.lua` 只热替换 `scene/HangarMotion.lua`，以及触发机库 XML/材质重载；不热替换 Blueprint 模块或给现存实例改 metatable。因此本批需完整新构建/重启生效，F5 场景重载不是 Blueprint 代码热替换，没有为旧实例添加推测性的兼容分支。

`Graph(checkpoint)` 在 `Neighbors` 返回后立即完整登记反向边，再执行其行级 checkpoint；反向登记本身没有 yield。当前带 checkpoint 的载具构造归 `SceneLoader` 准备协程所有：候选 TrialSession 在 prepare 完成后才 Activate/安装，`HangarApp:Update` 在 loadingFlow.active 时返回，不继续驾驶或建造更新。开篇同理，`OpeningHost.Update` 在 `not I.ready` 时不 Tick；运行中 CarUnit Flush 的 Graph 没有传 checkpoint。因此当前调用链不会在候选车的图计算暂停时并发 Add/Remove；没有增加锁或改变单线程执行规则。

## 后续验收

由父任务打入下一构建后，在真实战斗重现 vanguard 桥接摧毁及 scorpion 尾部摧毁，确认碎块/伤害反馈和输入连续性，并测量主线程长任务、实际 Flush、原生载具与碎块工厂。此离线检查不关闭上述运行性能验收。

## 已执行的 Web 破坏回归

root 在 `manifest-5b8cf21c.json` / QA4406 执行公开工坊选赤焰 GT、试车、正常 N 靶区切换及实际鼠标瞄准开火。证据 `evidence/destruction-web-2026-10-16T01-12-31-166Z/`；21 检查通过，运行错误0，未解决的资源请求错误0，浏览器进程正常结束。

- 实际靶车初始209零件，观测降至150后核心死亡；没有注入伤害或销毁。
- 实际命中光效截图、逐块破坏、击杀确认音1次、得分音12次、得分300完成。root检查了命中及击毁截图。
- 62次实际 Flush 最大17ms；开火区间含抓图/观察开销的1400帧，P95 33.410ms、P99 50.055ms、最大50.225ms，超过100ms为0，按该工具阈值通过。

这只是本机桌面 Chrome 的赤焰 GT 靶车回归。没有把旧包与本包做受控性能 A/B，不能把这些帧时间全部归因于本次索引优化；也不关闭350/1557零件预设真实破坏、多人混战、开场/回厅连续性或手机性能。
