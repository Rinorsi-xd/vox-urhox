# 4a3a 当前 Web 八车战斗实测

日期：2026-10-17。root 实际运行 `evidence/monitor-combat-4a3a-1017-a`，**PASS / CLOSED / exit 0**，Runtime / HTTP 错误均为 0；root 已实看 after-combat / returned。独立审计仅解析已有文件，没有启动浏览器、Runtime 或后台审计进程。

## 当前结果与验收边界

完整帧 1,338 个，排除首尾 2 个不完整帧，对应实际 engine frame 3509--4846，总计 45,081ms。平均 **33.692825ms / 29.6799 FPS**，P50=30ms、P95=67ms、P99=75ms、最大125ms，7帧超过80ms。当前桌面 Web 仍未达到稳定30FPS，更不能签署骁龙845在TapTap长时稳定30FPS。

真实8车、7个AI，玩家持续开火；本窗世界 shots 增749、hits增1,449、damage增805，玩家战斗stats.damage同样增805。这是造成的伤害计数，不是玩家受伤805。零件总数由初始1,279降至最低758，包含真实命中/结构破坏。世界hits不能当作只由玩家造成的命中。

受控布阵保证实际尺寸不重叠、地形/静态射线合法与双方可见；沿用真实车、AI、武器和破坏系统。默认生产监控开启，额外仅3个粗粒度监控wrapper；初始化、布阵、观察器序列化在采集外。它不是自然对局、CPU/GPU分离或手机验收。此前整窗28.502FPS与本窗工作量、损伤和轨迹不同，**不能据此宣称优化提帧或计算收益百分比**。本批武器单次更新的42.75%仅属另份Lua微基准。

## 同帧映射

`capture.json`使用引擎frameNumber，生产监控使用自己的BeginFrame计数，不能直接按相同数字关联。原始runtime的388条带frame的VOX_PERF记录中，日志前缀engine frame减pending monitor frame均为1,012。`PerformanceMonitor:Finalize()`在下一次真实Update中输出前一帧，因此对应关系为 **engineFrame = monitorFrame + 1,011**。

该关系将全部1,338帧一一对应；1,312帧起止时长完全相同，其余26帧只差1ms，符合两处整数墙钟读取边界。错误偏移1,012只有101帧时长相同，最大误差86ms；原始相同数字配对也不成立。独立审计不以猜测帧号补齐数据。

## 实际存在的分段

以下使用正确对应的同一1,338帧，每项分母相同。时间为整数毫秒墙钟，含其子调用；P95/最大值为该帧该段累计时间，不是独立CPU/GPU时间。

| 实际标签 | 平均包含时间 ms/帧 | P95 | 最大 | 调用总数 |
| --- | ---: | ---: | ---: | ---: |
| main.Update | 20.6420 | 51 | 69 | 1,338 |
| trial.Tick | 20.3266 | 51 | 68 | 1,338 |
| combat.BeforeStep | 10.2982 | 38 | 57 | 2,704 |
| vehicle.Step | 5.4141 | 10 | 51 | 19,113 |
| legs.Step | 1.2818 | 3 | 41 | 4,507 |
| legHitboxes.Update | 0.3857 | 1 | 43 | 19,247 |
| weapons.Step | 1.4297 | 3 | 46 | 19,113 |
| ai.Step | 1.9447 | 9 | 46 | 16,833 |
| combatView.Update | 2.7534 | 3 | 53 | 1,338 |
| playerView.Update | 1.3311 | 3 | 52 | 9,310 |
| weaponView.Update | 0.9604 | 2 | 46 | 9,195 |
| vehicleView.UpdateIdle | 0.3737 | 1 | 3 | 8,155 |
| effects.Update | 2.3416 | 3 | 38 | 1,338 |
| hud.Update | 0.7504 | 1 | 2 | 1,338 |
| main.PostUpdate | 1.8857 | 2 | 49 | 1,338 |

`main.Update`包含`trial.Tick`；Tick内有固定步循环的`combat.BeforeStep`，后者包含车辆、AI和武器步进。Tick在固定步之后执行视图、特效与HUD更新。`combatView.Update`包含各车的playerView、weaponView和idle更新，但玩家自己也有Tick直接调用，因此这些共享标签不能全部视为combatView内的独占耗时。`main.PostUpdate`属于另一个回调。表中父子项**不能相加凑成整帧预算**。

本窗最大的已命名更新区域是BeforeStep：平均10.30ms/帧、2,704次固定步，约每帧2.02次；车辆步进是其中最大列出的子项。AI平均1.94ms/帧，是存在的成本，不能凭单个46ms最大值认定AI为持续低帧根因。各段最大值发生在哪个Lua消费者，并不自动证明该消费者本身分配或执行了全部峰值；本窗没有新的WASM CPU栈，不能把所有尖峰命名为GC。

**UI.Render并不存在于该生产日志的标签字典中**。hud.Update只是数据/UI状态更新，不能代替UI绘制；也不能把整帧减main.Update的差额全部叫渲染、GPU或UI。需要独立同帧绘制/引擎取证后才能继续分配这些时间。

3个粗粒度wrapper单独记录的平均墙钟：monitor.Finalize=0.1345ms/帧，monitor.Emit=0.0531ms/帧（51次，已包含在Finalize内），bindings.Context=0.0688ms/帧。Emit帧与非Emit帧条件不同，其时长关联不证明日志是持续低帧主因，也不证明关监控能获得某个FPS收益。

## 归档与下一步

独立结果 `evidence/monitor-combat-4a3a-1017-a/independent-current-audit.json`；可复用审计器 `tools/migration/audit-current-web-4a3a.cjs`，拒绝覆盖既有证据，O(n)解析并于0.23秒完成。raw capture SHA `c914a1f2e3cc2d21005712c6fecbf2f2b8db36505775ec186533dbb8aa51df5d`，production-perf SHA `ab456e77a8286d674ecbea8cd5c3e7d7df0ebbf270b22abab2143a9f4dc24925`。

下一步应围绕同帧BeforeStep与车辆步进继续归因，另保留effects/视图开销及未测UI绘制边界；任何候选优化仍需相同状态、RNG与工作量的对照。当前结果没有关闭持续30FPS、真机热稳定或全部迁移验收。
