# HeightField 有界缓存隔离候选

状态：离线等价及真实 Native ABBA 通过，已精确合入本地生产，实际 Web 生命周期验证通过；整局持续性能未达标。日期：2026-10-17。

## 依据与边界

真实 Web 特效十三段采样中，粒子整段平均 1.4756 ms/完整帧，为 effects.Update 的 55.91%，最大 2 ms。该段同时包括粒子运动、地高采样与原生几何提交。目前没有把这三项分别计时，不能把 1.4756 ms 都算成 HeightField 开销，也不能用此项解释全部 80–129 ms 长帧。

实际 HeightField.Sample 每次读取静态四角地高，原生调用为两次 Seek 与四次 ReadFloat。候选仅对已解析格的四角值建立每实例 4,096 槽直映缓存，槽保存完整 k，冲突后重新读取。保留原 fx/fz/i/j/u/v、clamp、Disposed 断言与最后四项插值表达式的顺序；不量化采样位置、不缓存最终高度。只有四次读取全部成功后才发布缓存 key。Dispose 清空缓存。

源代码检索未发现运行期间修改视觉地高 buffer 的入口或其他消费者直接依赖其读取游标。缓存命中会改变内部 buffer 游标的最终位置，这是内部状态差异；如果未来增加外部 buffer 读写，必须重新审核缓存契约。

## 已完成验证

`tools/migration/check-heightfield-cell-cache.py` 使用实际二进制资源的 float 字节，在 Lua 5.4 执行原/候选 Sample。48,498 次最终 double 字节比较全部相同。两张图为 Crater/VisualHeight.bin（n640）和 Salvage/Height.bin（n512）；EnginePit 不使用这个模块。

另有 48 次直映槽冲突交替、8 条已有槽被冲突读取第 1–4 个 float 异常打断的原子性路径、12 项同路径独立实例/释放隔离检查，全部通过。覆盖边界、边界外、邻格、无穷、无效参数、缺文件/错误 magic/长度/范围、重复 Dispose 与释放后采样。两个真实代码变异负控（提前发布 key、模块共享缓存）均被预期断言拒绝。

候选 SHA-256：`6e595e1a0f7fce56013ddbff63aca3ce9e2c60b86734990e105c9530675e4872`。原模块 SHA-256：`9e95855a228e49fd6c3b7fd8b7b7091a713d5478e0e3ca2fc112f1a096b8946a`。本 CPU 基准运行时生产 core/HeightField.lua 未改，后续采用由 root 单独执行。

为防采用后测试变成候选自比，当前 checker 默认读取持久证据内 `source-baseline/scripts/core/HeightField.lua`，并硬校验原模块 SHA；显式 `--baseline` 也必须是同一原 SHA。故意以候选当 baseline 的负控已被拒绝。归档保留采用前原工具和 `offline-verification.json`，另存锁基线版工具与 `offline-fixed-baseline-verification.json`。归档工具副本用于恢复到项目工具目录后复现，当前项目入口为 `tools/migration/check-heightfield-cell-cache.py`。

## 原生实测夹具

`.tmp/heightfield-effects-2a97-A` 与 `-B` 派生自 2a9723f0 的 548 份冻结 Lua。只有 core/HeightField.lua 一个生产模块不同，另加同样 QA 入口/原模块副本。原生真实 buffer 对两图做 4,862 次位等价检查与释放断言，然后使用真实 CombatEffects、CustomGeometry、Crater VisualHeight.bin、固定 Burst/Puff 负载和原生产粒子上限。120 帧热身、480 个实际 Update，正常自动 GC，无逐粒子/逐顶点计时、无强制回收或模式变更。入口及派生入口已通过 Lua 5.4 compile。

主计时仅包围原 effects:Update。事件生成、帧计数和每 60 帧完整粒子/烟雾 digest 在计时外；它们的分配仍可影响正常 GC，属于匹配 A/B 固定诊断负载，不能冒充真实匹配或最终 Web 性能。记录每帧粒子/烟雾数、各批次数、8 份完整状态 digest 和末尾 RNG，分析要求全部完全一致。

root 独占真实硬件窗口，依次运行 A1/B1/B2/A2。复用 `run-vehicle-allocation-probe.ps1 -ExclusiveCpuWindow -NormalTiming`，identity.entry 选择新入口，不需要 roster。分析器 `analyze-heightfield-effects.cjs` 验证四轮等价、正常 GC、480 帧与耗时合计，同时校验所有实际 launch/process/ERROR、冻结、工程、Runtime、资源和资产 SHA；除 HeightField 和 QA 入口的 variant 常量外，不允许源差异。

## 真实 Native ABBA 结果

| 轮次 | 480 次 Update 累计 ms | 平均 ms/Update | P95 ms | 最大 ms |
| --- | ---: | ---: | ---: | ---: |
| A1 原模块 | 3,379 | 7.0396 | 9 | 18 |
| B1 有界缓存 | 3,147 | 6.5563 | 8 | 19 |
| B2 有界缓存 | 3,221 | 6.7104 | 9 | 19 |
| A2 原模块 | 3,341 | 6.9604 | 8 | 19 |

原模块均值 7.0000 ms，候选均值 6.6333 ms，减少 0.3667 ms，即 5.2381%。A1/A2 基线漂移 1.1310%。四轮均 exit 0、Native ERROR 0，正常 GC guard 恢复，4,862 原生高度检查通过；全部 480 帧种群/批次数、8 个完整粒子烟雾状态 digest 与末尾 RNG 完全相同。四轮最终 digest 均为 `8eedd3ab54b745a1`。

该固定高粒子负载下测到窄 CPU 收益，幅度高于本轮基线漂移；P95 没有一致下降，最大耗时没有改善。不能说已经消除长帧，也不能把 5.24% 套到整局或 Web FPS。heapBefore/heapAfter 是含正常 GC 未回收垃圾和诊断分配的瞬时堆读数，不能把终点较低值宣称为缓存节省内存。

另一个 agent 先独立逐帧重算再读取本分析器结果，两者一致；其来源 SHA、入口仅 variant 差、正常 GC 日志、每帧种群/批次、状态/RNG及退出审查通过，结果为 `independent-audit.json`。B1/B2 漂移 2.324%，一并保留，不能只展示 A 的漂移。

实际首次热身结束为 866 粒子/232 烟雾、生产上限 1,000/240；这是较高负载的固定特效压力夹具，和先前 Web 平均 1.4756 ms 粒子段的工作量不同。证据已持久归档于 `evidence/heightfield-cache-native-2026-10-17/`，包含四轮原始 JSON、启动/退出/校验/原生日志、完整一份冻结脚本树、A/B 入口和 HeightField、复现工具、离线输出与独立分析。资产和 Runtime 仅保存 SHA/原路径，不复制体积大的二进制；原 `.tmp` 保留。

root 已将精确已验候选移入生产，新统一冻结为 `.tmp/outgame-cached-1792206583227` / `manifest-0baeef97.json`，指纹 `ef2e30f211a85a1fbe1191b2233539b3e9af21718f1533e415b4554ae508f132`。549 份生产/冻结/identity/打包 Lua 全部 SHA 相等，普通 4584 的 manifest 与 13 个关键模块、QA4581 的 HeightField 实际 HTTP 字节通过独立检查，证据 `evidence/independent-unified-0bae-4584-a.json`。该包还包括此前转轴等功能改动，不能当只变 HeightField 的 Web FPS 对照。

实际 Web 复用普通 monitor-combat 八车交火 45 秒、原监控、公开返厅，仅验生命周期与实际显示；没有增加特效分段包装。`evidence/monitor-combat-heightfield-0bae-a/report.json` 为 PASS/CLOSED，root 实际观察 runner exit0，运行/HTTP 错误均为0。实际848次shots、1710次world hits、玩家受伤931、最少705零件，完整返厅；root已查看after-combat与returned两图，地图和特效非空，返厅完成。

1285完整帧平均35.0856ms，约28.50FPS，P95 68ms、最大117ms，11帧大于80ms。此轮仍有明显长帧，不能说整体卡顿已解决。截图右上PERF的瞬时18FPS与包含加载历史的最大值不属于本段45秒完整帧均值，分别保留不能混用。工作量与旧轮次不同，不是匹配 FPS A/B。QA4581服务器及测试浏览器已结束，普通4584保留供用户验证。845/TapTap 长时间稳定30FPS仍OPEN。
