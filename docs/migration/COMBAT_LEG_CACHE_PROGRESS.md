# 战斗机械腿 IK 缓存进度

## 2026-10-15 本批

- 继续当前 G1 / G6 性能闭环；源冻结为 `2026-10-14 / 2b169a9964645f5f346a7158bcb14447f040814a`，没有重开 G0。
- 生产修改仅 `scripts/drive/LegControl.lua`、`scripts/parts/LegIK.lua`；`LegGait.lua` 和 `LegIK.Solve` 数学保持不变。
- root 的 before Web 数据中 LegControl 为 991ms / 952 次调用；这是优化前实测，不能作为本补丁改善后的时间。

## 修改与边界

- 24 种静态装配旋转的 X/Y/Z 基向量在模块加载时生成一次；Target 的逆车体旋转、原点转换、CELL 换算及点乘顺序保持原样。
- 仅在一次 `LegControl.Step` 内共享同一条腿、相同变换目标的 IK 求解。`Clear` 和 `Reachable` 继续各自执行原有有效性判断、角度限制和射线检测。
- 每次查询先重新计算 target，再比较三个标量及 rig info 身份；foot、车体位置、四元数、装配 origin 或 rot 在原表上改动后会重新求解，不以输入表身份判定相等。
- `Reachable` 可接收本次查询的求解记录；未传第三参数的调用与原接口行为一致。
- Lua 5.4 `<close>` 在 Step 正常和异常出口清空缓存；guard 在 controller 创建时预建一次。Step 外查询不使用缓存，错误原样抛出。
- 没有修改物理步频、射线数量与顺序、决策频率、力、扭矩、跳跃、破坏规则或游戏参数。

## 离线逐帧验证

- 验证工具：`tools/migration/verify-leg-cache-offline.py`、`tools/migration/check-leg-cache-offline.lua`。
- 旧模块基线：`.tmp/outgame-cached-1792065106063`。实际执行旧/新 LegControl、LegGait、LegIK，使用真实 leg3 / leg5 rig 与固定源录制 `source-leg-drive-fixtures.json`。
- **8,512,230 项断言通过**。14 个源录制场景覆盖 LegT3 / LegT5 平地、墙面、跳墙、坡地、旋转、停车及 LegWaveT5 平地、旋转。
- 每帧旧/新 telemetry、力调用序列、跳跃后的 body、控制器步态和 IK 状态精确相等；对原 H5 录制的 ray 起点、方向、长度及输出使用已有 `2e-5` 容差。
- 附加 420 步混合场景覆盖输入表原地修改、45 步空中、100 步墙面、跳跃、Snapshot / Restore、Reset 与破坏后只剩 2 条腿。完整输出与旧模块精确相等。
- 单独覆盖 foot / quaternion / position / leg.origin / leg.rot 原地变更，Step 外重复查询，gait 抛错和 Cast 抛错后的缓存清理。

| 场景组 | 旧 Solve | 新 Solve | 减少 |
| --- | ---: | ---: | ---: |
| LegT3 六组 | 14294 | 11130 | 3164 |
| LegT5 六组 | 14480 | 11148 | 3332 |
| LegWaveT5 两组 | 6528 | 4949 | 1579 |
| 混合生命周期 | 1729 | 1308 | 421 |
| 合计 | 37031 | 28535 | 8496（22.94%） |

- 所有射线仍执行，数量完全相同；减少的是相同 target 的重复 IK 运算。
- 机器可读证据：`docs/migration/evidence/leg-cache-offline.json`，含源 provenance、fixture / rig / 旧新生产模块 SHA256。

## 冻结与未关闭项

- LegControl SHA256：`0a44ab8206b44b9c93a701f9806d9002f3233d15e095714579f52e03d09f10d3`。
- LegIK SHA256：`343b5a351c416e6e5fd036dbbc086820e0545a64078861870051d449c03849d6`。
- LegGait SHA256：`2da50517efb533160620e8df3ef914f14787d55683fa0be34db82d0a0d860e59`，未修改。
- 本子任务未启动浏览器或引擎窗口；实际 Bullet / Web 耗时和帧率待 root 在统一不可变构建中复测。离线调用减少不等于整场 FPS 提升 23%。
