# Web 特效与车辆视图分段实测

日期：2026-10-17。沿用 1016/f94827b2 与 H5 10/15 b2760649。正式生产模块未因本次归因而修改。

## 范围与证据

原始冻结包 `.tmp/outgame-cached-1792204236638`，manifest `2a9723f0`，指纹 `857340c44e64654df388c17ad3594abebda42e4f7c00a1782f557c4dcea7fab0`。派生夹具 `.tmp/monitor-combat-effects-2a97-a` 只增加十三个可逆整段标记及七个已有视图/批次方法边界。没有逐粒子、逐顶点、逐射线计时，没有强制 GC 或修改战斗规则。离线实际原/派生 Update 输出、状态、RNG、异常及恢复检查 39,228 项通过。

root 实际运行桌面 Web 八车七 AI、持续交火 45 秒。实际报告 PASS/CLOSED，运行与 HTTP 错误均 0。持久证据为 `evidence/monitor-combat-effects-2a97-a/`，独立解码为 `independent-effects-attribution.json` 与 `independent-effects-attribution-frames.json`。十三子段每帧调用数与父段一致、inclusive 总和不超过父段、完整 FramePresented 对齐检查通过。

额外标记带来测量成本，工作量与旧采样不相同。下述 24.07 FPS 不能与此前 30.43 或 26.58 FPS 相减当作回退或提升。

## 实际结果

1,087 完整帧 / 45,162 ms，平均 41.547 ms，即 24.069 FPS。P50 38 / P95 71 / P99 80 / 最大 129 ms；10 帧大于 80 ms。脚本段平均 27.678 ms，每帧平均补跑 2.4885 个固定步。

| 测量范围 | 平均每完整帧 ms | 最大单帧累计 ms |
| --- | ---: | ---: |
| effects.Update（含子段） | 2.6394 | 5 |
| 粒子段（物理、采地高、几何提交合计） | 1.4756 | 2 |
| 装备视效 Update 独占 | 0.5409 | 44 |
| bolts 段 | 0.2346 | 1 |
| smoke 段 | 0.2116 | 1 |
| 普通腿视图 | 0.1380 | 38 |
| 批次 Finish | 0.0938 | 1 |
| 执行器视图 | 0.0819 | 1 |
| flashes 段 | 0.0635 | 1 |
| flares 段 | 0.0616 | 1 |
| rings 段 | 0.0478 | 1 |
| zaps 段 | 0.0377 | 1 |
| beams 段 | 0.0276 | 1 |
| 转轴视图 | 0.0101 | 1 |
| 战斗临时光 | 0.0083 | 1 |
| 机甲视图 | 0.0046 | 1 |

粒子段占 effects.Update inclusive 的 55.91%；尚未分别量出采地高与原生几何提交的占比，不能宣称 1.48 ms 全来自 HeightField。

同轮较大的持续独占段还包括 AI 2.6421、武器 2.1444、物理 1.8832、环境 1.2732、目标规则 1.1601、腿步态 1.1187、悬挂 Apply 0.9678、HUD 更新 0.9374、悬挂 Sample 0.9347、悬浮控制 0.8666 ms/帧。它们说明当前持续 CPU 成本分散，并非一个特效子段解释全部低帧。

旧 `playerView.Update` 标签包装的是共享 DriveView 元表，实际聚合所有受驱动车辆视图，不只是玩家。该段 7,979 次调用、平均每帧 7.34 次；inclusive 1.6403 / 独占 0.8261 ms/帧。后续解释必须使用这一真实范围。

## 长帧边界

粒子最大 2 ms、整个 effects.Update 最大 5 ms，无法单独解释本轮 80–129 ms 卡顿。129 ms 帧测到脚本 56 ms，其中 AI 39 ms；若干 81–89 ms 帧分别落在 AI、武器、Contact、Thruster 或 UpdateIdle。另有 106/108/91 ms 帧的测量脚本只有 17/20/22 ms，剩余部分未归因，不能直接叫 GPU 或 GC。

八车工作量记录为 1,121 shots、1,698 hits、1,701 player damage，最少 935 零件。54 份存活记录里 hangar/build/mapPreview/opening 均为 0；backgroundResources 有两份为真，不能声称所有后台资源一直为 0。堆回落仅为相关，不是 GC duration 证据。

## 下一项隔离实验

只准备 HeightField 四角浮点有界缓存候选。保持原 i/j/u/v、clamp、最终插值算术和 Dispose 断言，每实例 4,096 直映槽、完整格 key 校验，只缓存不可变四角值；不缓存最终高度或量化坐标。原生四次 ABBA 必须使用真实 `Crater/VisualHeight.bin`、正常自动 GC、真实 Effects.Update，只有 HeightField 一项变化。已有沙盘 sin/cos ground 探针不适用于本次。完成匹配实测前不合生产、不宣称提高 FPS；845/TapTap 持续 30 FPS 仍未验收。
