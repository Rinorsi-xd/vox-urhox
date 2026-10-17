# Web 车辆内部详细计时

2026-10-16，2026-10-17 复核。本工具只注入 QA 入口，不修改 `scripts/`、模拟频率、射线、车辆数量、物理或玩法。已执行四轮 Web 尝试：第一轮按键失败；第二轮功能通过，但分段归因因重复包装判废；第三轮修正后的 57 个唯一绑定实测通过；第四轮扩展 102 个绑定再次通过独立逐帧审查，进一步定位 Trial 与展示内部开销。没有受控旧新 A/B，不能声称已有性能收益或骁龙 845 达标。

## 最新 102 段实测及独立审查

证据为 `evidence/performance-trial-sections-match-1792167434262/`，Native/Web 硬件进程由主协调者单独调度。本节只读重解析该目录的 result、原始 JSONL 和 summary，未修改任何原始文件，也未额外启动硬件测试。服务 QA4488，冻结包 `manifest-e1bd07fa.json`，冻结目录 `.tmp/outgame-cached-1792166173967`，probe SHA-256 `9890eaaea5451d837cb68e7f9b91b9486060732893b0eed0f4aa5571e298b59d`。运行 PASS / CLOSED，22 项检查，错误 0，正常返厅。

独立重算 summary 逐字段完全一致，35 项源身份与冻结包一致，运行时 102 个唯一绑定及五个 HUD 标签均符合清单。输入 anchor5，详细帧 **6..1104，共 1099 帧**，不是 FrameStats 另一窗口的 1077 帧。详细帧连续、首尾完整、dropped0；固定步分布为 1 步447帧、2步598帧、3步54帧，合计 **1805 固定步**。

逐帧额外验证全部零失败：Trial.Tick/Update 各一次；BeforeStep、AfterStep、world.Step、ConsumeWorldEvents、CombatView.Consume/SavePose 各等于 physics.Step；Vehicle.Step 为六倍、ai.Step 为五倍。每帧 DriveView/WeaponView/EquipmentEffects/WeaponEffects 各六次，NPC VehicleView.UpdateIdle 五次，CombatView/Effects/HUD 各一次；DrivingAudio.Observe、DrivingEvents.Observe、DriveView.SavePose 各为固定步六倍。每个 scope inclusive 均不超过所在帧 Update，全部 scope self 之和逐帧恰等 Update inclusive，计时树与调用次数守恒。

实际入口墙钟为1099间隔/30088ms，均值 **27.378 ms**，P50 25/P95 49/P99 57/最大69ms，无超过80ms的间隔，覆盖30092ms输入期的99.987%。生产 Update平均 **14.833 ms/帧**。该测量包含102段观测器、QA及引擎/等待；不是呈现 FPS 或无观测基线。P95仍超过30FPS的33.33ms预算。主协调者查看截图确认玩家末尾抵墙；所有伤害、击杀、破坏计数为0，因此这不是近距离交火、击碎或击杀验收。

### 当前可行动范围

以下计时为整数墙钟，包含包装/分配/GC/抢占开销，不是精确线程 CPU。每步列只对固定步更新范围使用1805步归一；Vehicle、AI分别为六车、五AI合计，不能误读为单车。父子 inclusive 不能相加。

| 范围 | 调用数 | inclusive ms/帧 | self ms/帧 | inclusive ms/固定步 |
|---|---:|---:|---:|---:|
| vehicle.Step | 10830 | 4.894 | 0.331 | 2.980 |
| physics.Step | 1805 | 1.693 | 1.693 | 1.031 |
| physics.Raycast | 144240 | 1.348 | 1.348 | 0.820 |
| suspension.Sample | 10830 | 0.705 | 0.303 | 0.429 |
| suspension.Apply | 10830 | 0.786 | 0.786 | 0.479 |
| legHitboxes.Update | 10830 | 0.389 | 0.389 | 0.237 |
| ai.Step | 9025 | 1.139 | 0.444 | 0.694 |
| effects.Update | 1099 | 1.438 | 1.438 | 不适用，每Update一次 |
| combatView.Update | 1099 | 1.856 | 0.066 | 不适用 |
| driveView.Update | 6594 | 1.192 | 0.779 | 不适用，六车合计 |
| weaponView.Update | 6594 | 0.495 | 0.349 | 不适用，六车合计 |
| vehicleView.UpdateIdle | 5495 | 0.427 | 0.277 | 不适用，五NPC合计 |
| equipmentEffects.Update | 6594 | 0.216 | 0.216 | 不适用 |
| weaponEffects.Update | 6594 | 0.161 | 0.161 | 不适用 |
| hud.Update | 1099 | 0.819 | 0.029 | 不适用 |
| hud.overlay.Update | 1099 | 0.714 | 0.421 | 不适用 |
| trial.Tick | 1099 | 14.517 | 0.126 | 不适用，含固定步和逐帧展示 |

本轮把原 Trial.Tick 未拆的工作明确归到特效、视图、HUD和音频。Trial.Tick 剩余 self 仅139/1099=0.126ms/帧，说明归因范围细化，**不表示这段代码实际变快**。CombatView 的1.856ms中自身仅0.066ms，其余落在车辆/武器/材质展示的子调用；DriveView总数包含玩家和NPC，不能按六等分后宣称NPC各自成本。HUD的0.819ms主要在overlay.Update的0.714ms子范围。

已包 WeaponAudio、DrivingAudio、CombatFeedbackAudio、CollisionAudio以及DrivingEvents的所有 self 合计407ms，即 **0.370ms/帧**；其中相互嵌套已使用self去重。本轮这些音频更新不是最大的持续开销，不能据此排除未测的音频解码或加载尖峰。

有证据支持的后续优化顺序是：车辆支撑/射线与物理积分、CombatEffects.Update、DriveView.Update、HUD overlay。每个范围仍须按内部实测决定生产改法。例如CombatEffects.Update含chips/missiles、批次Begin/Finish、弹道几何、粒子地面采样，当前计时没有进一步证明哪一项占1.438ms的大头；DriveView self也尚未逐项量化轮子/履带变换；overlay仍包含瞄准射线和标签更新。可以对这些实际入口继续分段，不能用静态阅读猜出具体耗时，也不应直接降特效、射线或频率来掩盖成本。

本轮与第三轮57绑定之间增加了包装、改变了车辆/射击轨迹，因此不作相减收益。长期30FPS验收仍须真实TapTap骁龙845、完整交火破坏及热机持续测试；本报告只完成桌面Web诊断归因。监控本身有开销，额外堆内存扫描/控制台诊断也不能常驻混入无观测FPS验收。

## 修正后第三轮独立审查

证据目录：`evidence/performance-drive-sections-match-1792166475802/`。本节只读审查原始文件，没有修改该目录。包为 `manifest-e1bd07fa.json`，冻结目录 `.tmp/outgame-cached-1792166173967`，QA 4486，probe SHA-256 `2485d05b06038d7158c15239470392a9c8a1f0edbc48a0c571832748c55cb980`。运行 PASS / CLOSED，22 项功能检查，错误 0，正常返厅；六车歼灭战，非八车争夺战。

从原始 JSONL 重算完整 summary，与存盘 summary 完全相同，并额外逐帧检查：

- 输入 anchor 为 5，保留 6..1057 共 1052 帧，连续且首尾完整，epoch 仅为 1，dropped 为 0，运行时 57 个唯一绑定。
- 每帧 Trial.Tick、Trial.Update 各一次；BeforeStep、AfterStep、world.Step、ConsumeWorldEvents、CombatView.Consume 各等于同帧 physics.Step 次数，全部通过。
- 每帧 Vehicle.Step 为 physics.Step 的 6 倍，ai.Step 为 5 倍；1806 个固定步完整覆盖六车阵容。每帧固定步分布：1 步 362 帧、2 步 627 帧、3 步 62 帧、4 步 1 帧。
- 所有 scope 的 inclusive 均不超过所在帧 update.production；每帧所有 scope 的 self 之和与 update.production inclusive 恰好相等，均无异常。原来的重复包装污染未复现。
- 模块源身份为 LegGait `2da50517efb533160620e8df3ef914f14787d55683fa0be34db82d0a0d860e59`、ContactControl `cb9ad164a6380a5fa02fdc0238638f1eb033a6fc7282873b1a60bb19c0f3c03b`，原始记录与运行时一致。

实际 Update 入口墙钟：1052 个间隔 / 30102 ms，均值 28.614 ms，P50 26 / P95 51 / P99 58 / 最大 84 ms，1 次超过 80 ms；覆盖 30112 ms 输入期的 99.967%。这些是带观测器的入口节奏，不是呈现 FPS、精确 CPU 或无插桩基线。合成校准每轮 3000 次，direct 为 1/0/1 ms、disabled 为 0/1/0 ms、active 为 4/3/4 ms；不能将此机械扣除实际游戏的包装开销。

### 完整更新中的实际热点

单位是每个 Update 帧的平均整数墙钟毫秒，含观测开销与抢占。inclusive 包含子调用，表中父子不得相加。

| Scope | 调用数 | inclusive ms/帧 | self ms/帧 | 判断边界 |
|---|---:|---:|---:|---|
| update.production | 1052 | 15.402 | 0.199 | 仅原始 HandleUpdate |
| trial.Tick | 1052 | 15.093 | 2.818 | self 是尚未细分的工作，不可直接归给某一模块 |
| combat.BeforeStep | 1806 | 7.658 | 0.684 | 包括车辆、AI、武器等 |
| vehicle.Step | 10836 | 5.045 | 0.345 | 每固定步六车，下面腿与悬挂属于其子项 |
| combatView.Update | 1052 | 1.943 | 1.943 | 未拆内部子段，不能直接解释为 GPU |
| physics.Step | 1806 | 1.864 | 1.864 | 与射线计时分开 |
| physics.Raycast | 144624 | 1.411 | 1.411 | 分散于车辆、AI、武器等调用树，不能再与父项相加 |
| ai.Step | 9030 | 1.189 | 0.469 | 每固定步五个 AI，部分时间在射线子调用 |
| vehicleRay.Cast | 75015 | 0.805 | 0.805 | 与 physics.Raycast 是不同包装项 |
| suspension.Sample | 10836 | 0.768 | 0.337 | inclusive 包含地面射线 |
| suspension.Apply | 10836 | 0.651 | 0.651 | 施力 |
| legHitboxes.Update | 10836 | 0.382 | 0.382 | 含无腿车辆的函数入口 |

这轮可将排查重点缩到车辆支撑、物理、战斗展示，以及 Trial.Tick 中还未拆开的 2.818 ms/帧。车辆总 inclusive 最大，但仅腿部摆动或接地 handling 都不能单独解释全部成本。完整入口 28.614 ms 与 Update 15.402 ms 的差值仍含引擎、呈现、QA 及等待，不能全部归为渲染或 GPU。

### 步态与接地 19 个范围

包含两个 Step 外层与 17 个内部范围。gait.air 未在此阵容/轨迹中调用，不能以零耗时证明该路径廉价；另行包装的 gait.foothold 不算新增内部范围。

| Scope | 调用数 | inclusive ms/帧 | self ms/帧 |
|---|---:|---:|---:|
| gait.Step | 3612 | 1.428 | 0.053 |
| gait.init | 3612 | 0.020 | 0.020 |
| gait.air | 0 | 未进入 | 未进入 |
| gait.kinematics | 3612 | 0.106 | 0.106 |
| gait.phase | 3612 | 0.018 | 0.018 |
| gait.stance | 11187 | 0.342 | 0.073 |
| gait.swing | 11229 | 0.827 | 0.249 |
| gait.free | 25 | 0.004 | 0.000 |
| gait.plant | 69 | 0.000 | 0.000 |
| gait.finish | 3612 | 0.058 | 0.022 |
| contact.Step | 10836 | 0.529 | 0.067 |
| contact.inputs | 10836 | 0.024 | 0.024 |
| contact.loads | 10836 | 0.024 | 0.024 |
| contact.steering | 10836 | 0.048 | 0.048 |
| contact.wheelCommands | 10836 | 0.053 | 0.053 |
| contact.handling | 10836 | 0.124 | 0.124 |
| contact.damping | 10836 | 0.047 | 0.047 |
| contact.bottomout | 10836 | 0.024 | 0.024 |
| contact.telemetry | 10836 | 0.119 | 0.119 |

另行方法 gait.foothold 为 7963 次、inclusive 0.543 / self 0.093 ms/帧；其内部 LegControl 射线仍有子项。19 个范围的 self 排名前五为 swing、handling、telemetry、kinematics、stance；若将额外方法也列入则 foothold 位于 stance 之前。亚毫秒短调用受 1 ms 时钟及包装开销影响大，0 不代表实际免费。本轮不能与上一轮判废数据或旧 fb3 会话直接相减，阵容轨迹、冻结包及计时边界均未受控一致。

## Trial / 展示分段工具及验证

2026-10-17：针对有效第三轮中 Trial.Tick self 2.818 ms/帧、CombatView.Update self 1.943 ms/帧，增加独立可选 `trial-sections-v1`。工具后来由主协调者实测，其结果和独立审查见本文开头“最新102段实测”，没有改 `scripts/`。

保留原 57 个绑定路径。只有服务同时带 `--qa --monitor-disabled --profile-drive-sections --profile-trial-sections` 才启用新段；runner 必须同时带 `--drive-sections --trial-sections`。服务身份 `trialSectionsProfile=true`，其余路径为 false/旧服务缺省 false；禁止与 loading-failure、CDP 等实验混用。

新范围在 `trial-section-bindings.cjs` 中只有一份清单：40 个唯一模块方法，加 5 个 HUD 实例方法，合计 **102**。安装原 57 后先验证计数，再安装 40；第一个有效采样帧前绑定当前 HUD 的 Update、readouts.Tick、readouts.Refresh、match/story.Update、sniper.Update。实例绑定完成后断言 102，runner 输入前及输入期状态均检查 profile、102 计数和完整 5 个标签。HUD 主对象、子对象或已包方法在采样期间变化会显式失败；同对象多个方法分别绑定，不按不同访问路径重复包装。

覆盖的实际调用包括：

- 音频：WeaponAudio、DrivingAudio、CombatFeedbackAudio 的 Update/SetActive，以及实际 Consume/Observe；CollisionAudio 的 BeforeStep/AfterStep、DrivingEvents.Observe。
- 车辆视图：DriveView.Update/SavePose，CombatView.SavePose，VehicleView.UpdateIdle/UpdateWeaponEffects，Rotor/Actuator/Leg/Mech/Wing 视图、EquipmentEffects.Update。
- 车辆表面与武器：JoinedMesh.Update、LiveryLayer.Update、WeaponView.Update、WeaponEffects.Update、WeaponPresentation.Update。
- 世界特效、反馈与 HUD：CombatEffects.Update/Consume、RestoreFlash.Update/Consume、PartHitFlash.Update、SafeReset.Update、TrialMetrics.Timing、DriveOverlay.Update/Consume、ReticleState.Update，以及上述五个 HUD 实例入口。
- 补足当前循环入口：TrialSession.Aim、BattleController.SyncPlayer。

builder 对冻结包内新增方法所属模块及私有 HUD 源模块逐个核对 SHA，并把 33 个相关模块哈希加入原始 sourceIdentity（加原 LegGait/ContactControl 共 35 项）。不替换这些模块正文；只在 QA 的模块表或当前 HUD 实例包方法。原 57 的 observer 文件没有修改，新变体在 builder 的局部字符串副本上扩展。输入首帧/连续/尾帧、生产 Update 范围、关监控及无 dropped 等已有约束保留。

离线 `verify-trial-sections-web.py` 通过：两项 Lua54 语法检查；新增 40 个方法确实在对应冻结源码中导出；102 个绑定、五帧三批、多返回 nil/false 保留；重复原/新增模块绑定、HUD 主实例被替换、HUD 方法被替换的负控全部拒绝。更关键的是，默认 57 分段完整 suffix 的 SHA 与已测第三轮的 probeSha256 完全相同，证明默认路径未变化。runner self-test 与 server/audit 的 Node 语法检查通过。未运行新的 Web/Native，也未将离线工具验证当成性能结果。

使用时先由主协调者分配唯一硬件窗口及新 QA 端口，启动新服务后进行普通/QA HTTP 字节身份核对，再跑同一六车匹配。若要测八车争夺战须先明确选择该实际模式，不能更名报告替代真实路线。增加的包装可能改变整体节奏，所以本轮只用于找 Trial 与展示内部归因，不与第三轮直接计算优化收益。

```powershell
# Reuse an explicitly frozen prepared identity; root allocates a fresh port.
node tools/migration/serve-outgame.cjs --qa --monitor-disabled --profile-drive-sections --profile-trial-sections
node tools/migration/check-performance-uninstrumented-web.cjs --drive-sections --trial-sections
```

## 前两轮证据

- `evidence/performance-drive-sections-match-1792165640466/`：真实匹配加载完成后，Playwright 拒绝 F16 键名；未开始详细计时，FAIL / CLOSED。已改用 ScrollLock，保留失败证据。
- `evidence/performance-drive-sections-match-1792165933978/`：21 项功能检查通过，运行错误 0，返厅通过，PASS / CLOSED；运行的是六车歼灭战，不能当八车争夺战验收。其分段归因为 **REJECTED**，见同目录 `analysis-rejected.json`。
- 判废原因：TrialSession、BattleController、TrackWorld、CombatView 四组在 QA 安装表中重复，69 个包装实际只有 57 个唯一绑定。698 帧中 Trial.Tick 被记 1396 次、inclusive 累计 36125 ms，大于外层 update.production 的 18359 ms。不得除以 2 后宣称恢复有效，也不得将独立底层项包装成正式排行。
- 只读复核原 JSONL：输入 anchor 为 5，详细帧为 6..703，698 帧连续、首尾完整。新增首帧负控没有发现这轮实际漏帧，但不改变重复包装导致的判废。
- 可以保留的原始节奏：697 个连续 Update 入口间隔、30170 ms，均值 43.286 ms，P50 40 / P95 67 / P99 87 / 最大 155 ms，9 次超过 80 ms。这包含观测器、引擎和等待，不能称为 CPU 或呈现 FPS；不是无观测基线、旧新 A/B 或骁龙 845 验收。
- 旧版 update.production 边界还包括 QA EnsureBattleTiming / EnsureUpdateTiming。修正版将 BeginFrame 移到这两步之后，只包原始 HandleUpdate；这也是必须重新实测的边界变化。

早前独立的 fb3、753 live 帧记录：trial.Tick 平均 26.103 ms、combat.BeforeStep 13.941 ms、vehicle.Step 8.919 ms（均 inclusive），physics.Step 4.035 ms；车辆子项 self 为步态 1.863 ms、悬挂采样 1.446 ms、悬挂施力 1.432 ms、接地 0.950 ms、腿命中盒 0.790 ms，ai.Step inclusive 2.147 ms。它们也指向固定步模拟中的车辆支撑和物理工作，但父子不能相加，且不能与修正后的内部 19 段结果直接 A/B。原证据和限制见 `PERF_TARGETED_2026_10_16.md`。

## 为什么需要新增实测

已有 Web 753 帧记录平均 45.139 ms、Lua 29.219 ms、2.67065 固定步 / 帧；Vehicle.Step 平均 8.919 ms（inclusive）、LegGait.Step 1.863 ms（self）、Contact.Step 0.9495 ms（self）。父子不能相加。Native 无渲染陨坑六车的 600 步基线仅约 2.81 ms / 步，没有复现完整 Web 的持续开销，而且缺少渲染、音频、UI、完整规则、玩家、护盾和补跑循环。因此需要在完整 Web 地图与车辆中测内部段，不能拿 Native 数字推算 Web 或骁龙 845。

## 实现与测量边界

- `build-drive-sections-probe.cjs` 从指定冻结快照读取 LegGait / ContactControl，先核对该包源码 SHA-256，再按与 Native 完全相同的 19 段边界插桩，作为 QA suffix 中的独立模块闭包执行。不会覆盖磁盘生产脚本，也不改变下载清单里的生产模块。
- `qa-drive-sections.lua` 默认关闭，ScrollLock 首次启用时才把详细函数装到运行时模块表；57 个唯一方法 wrapper 覆盖 trial、combat、vehicle、physics、AI、weapons、腿、悬挂与相关世界方法。安装器拒绝重复对象/方法绑定与重复标签，并断言 57 个绑定；runner 输入前也验证 57。Gait.Step 闭包使用的新模块表与对外模块表共享同一个包装后的 Foothold，避免闭包漏计。
- 每帧只包住原始 HandleUpdate 的生产更新区间，记录 `{scope id,calls,inclusive ms,self ms,max ms}`。排除调用前的 QA Ensure 阶段，但生产方法中原有的 QA 实例包装仍在。PostUpdate 或呈现时间不在此范围；没有被测子段仍留在父段 self 中。
- 使用引擎整数毫秒墙钟，包含 clock、wrapper、临时表、GC 和抢占成本，不是精确 CPU 时间。inclusive 父子重叠，不能相加。
- 第一次开关前单独进行三轮各 3000 次 direct、disabled wrapper、active wrapper 合成校准，保留原始毫秒总量。它只说明仪器开销边界，不能从实际游戏时间中机械扣除。关闭采样后仍留有已安装的 wrapper / section 分支，不能把该状态当原始无插桩基线。
- 每两个原始帧组成一条独立 `VOX_DRIVE_SECTIONS` 日志，在状态 drain 时输出；物理步内不打印。最多暂存 4096 帧，超出会显式 dropped，runner 必须拒绝。原始记录写入 `drive-sections.jsonl`，不截断或忽略解析错误。
- `check-performance-uninstrumented-web.cjs --drive-sections` 只能连显式 detail QA 服务，禁止与 CDP profile / trace 同时开启。默认无插桩分支会拒绝 detail 服务，所有性能路径拒绝 loadingFailureTest 恢复注入服务。保留输入前真实墙钟 drain、首输入窗口与覆盖检查。

## 当前离线验证

`verify-drive-sections-web.py`：完整冻结 main + 全部 QA suffix 的 Lua 5.4 语法通过；Web / Native 转换逐字节一致；274002 项实际步态 / 接地算法状态、射线和施力顺序断言通过。受控模块与时钟夹具覆盖 57 个唯一绑定、开关、多返回值中的 nil / false、5 帧拆成 3 批、关闭后停止采集。额外注入重复 Vehicle.Step 绑定的负控被拒绝。

`analyze-drive-sections-web.cjs --self-test`：原始帧编号连续、不重复、已知唯一 scope、调用数、self / max 范围、冻结源身份及 dropped 拒绝通过；显式验证输入首帧等于 anchor+1，首帧缺失负控被拒绝。runner 的恢复注入服务、错误 detail 身份、CDP 与 detail 混用负控通过。夹具与语法通过不等于修正后 Runtime 执行或性能通过。

判废测试的服务器为 4484，冻结 `.tmp/outgame-cached-1792164278829` / `manifest-8d107d95.json`，指纹 `ecd0e420f46a613c72123454a405172e9470c0ec5a8734cddf6cde9ddc05154d`。普通 4481 与 QA 4484 当时的实际 HTTP main / manifest / identity 校验通过；QA main 的生产前缀与普通包完全一致，仅追加明确计时 suffix 并调整 main.size。证据为 `evidence/http-snapshot-manifest-8d107d95-4481-4484-audit.json`。该存量服务的 suffix 已陈旧，不能验证最新 57 绑定修正；下一轮须重建独立服务并重新核对 HTTP 身份。

## 运行命令

等待唯一硬件测试窗口释放后，使用以下命令。不得与其他 Native、浏览器或 GPU 测试并行。

```powershell
$env:VOX_PREPARE_FILE='.tmp/outgame-cached-1792164278829/identity.json'
$env:VOX_PREVIEW_PORT='4484'
node tools/migration/serve-outgame.cjs --qa --monitor-disabled --profile-drive-sections
```

```powershell
$env:VOX_QA_BASE='http://127.0.0.1:4484'
$env:VOX_EXPECT_MANIFEST='manifest-8d107d95.json'
$env:VOX_PERF_ROUTE='match'
node tools/migration/check-performance-uninstrumented-web.cjs --drive-sections
```

通过公开匹配入口，加载完成后开 ScrollLock，保存合成校准，再进行真实 W / 开火并保留所有输入期详细帧，最后关 ScrollLock 正常返回大厅。完整结果、原始墙钟与 detailed summary 一并归档。即使成功，也只用于定位，不能当成无观测 FPS、受控旧新 A/B 或骁龙 845 / TapTap 长期稳定 30 FPS 验收。

第一轮 `evidence/performance-drive-sections-match-1792165640466/` 在真实加载完成、尚未开启诊断时因 Playwright 不支持 `F16` 键名而 FAIL，浏览器已关闭，未产生驾驶计时结果。改用引擎和 Playwright 均已确认的 ScrollLock；原失败记录保留，不作性能证据。
