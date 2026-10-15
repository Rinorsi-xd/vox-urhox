# 战斗物理读取缓存进度

## 2026-10-15 本批

- 继续当前 G1 / G6 性能闭环，冻结源仍为 `2026-10-14 / 2b169a9964645f5f346a7158bcb14447f040814a`。
- root 唯一 Web 实测 before：`evidence/combat-performance-2026-10-15T11-42-04-683Z`；6 车、476 fixed steps、2856 次 Vehicle.Step。Vehicle 2556ms，其中 LegControl 991ms、RaySample 555ms、RayApply 285ms。该数字不是本补丁改善结果。
- 本批生产仅修改 `physics/Body.lua` 和 `drive/Vehicle.lua`；`RaySuspension.lua` 保持原样。上批 Nav 缓存保留。

## 接口与边界

- Body 新增 `beginReadScope()` / `endReadScope()`；Vehicle.Step 在钻头接管早退之后、全部控制器执行之前开始，使用 Lua 5.4 `<close>` 在正常和异常出口自动结束。
- scope 内复用 native position、rotation、centerOfMass、世界 center、逆 rotation、mass 和速度读取。
- Bullet 只在后续 `Space.Step -> PhysicsWorld.Update` 中积分；Vehicle.Step 内控制器同步运行，没有积分。body 包装 setter 是该阶段的姿态变化入口。
- position setter 清 pose / 世界 center；rotation setter 清 orientation / 世界 center / inverseRotation；setBodyType 清全部；setLinvel / setAngvel 分别清速度。
- ApplyImpulse 清 linear；ApplyTorqueImpulse 清 angular；ApplyImpulseAtPoint 清两者，逐轮悬挂冲量之后下一次速度读取仍看到新值。ApplyForce / ApplyTorque 只积累力，不改变即时速度。
- scope 退出清全部读取；外部读取不缓存，因此下一次 native 积分、外部直接修改 mass / COM / pose 后不会使用上一步缓存。
- invalidate 同时关闭 scope、清全部缓存、断 native 和 wrapper.native；已经失效的包装不会继续持有缓存中的 native 值对象。
- 当前接口为 Vehicle.Step 单层专用，不支持嵌套 scope；没有在其他调用点开始 scope。

## 异常出口状态

- 已补 Lua 5.4 原生 `<close>` guard；每个 wrapper 在创建时预建一次，begin 返回同一 guard，不增加每物理步的表分配或 pcall。
- Vehicle.Step 的正常 return 和控制器 error 都自动执行 __close，立即清掉缓存。错误继续原样向上抛出，没有吞错。
- __close 只赋值和清引用，不访问 native；即使 scope 内已 invalidate，也不会在关闭阶段再访问已释放对象或覆盖原错误。
- 黄金测试真实执行 Lua 5.4 正常 return / error，关闭后直接改 native 的 position、rotation、COM、mass、速度再读取，全部观察到新值；invalidate 后抛错再 close 也通过。

## 离线黄金验证

- `.tmp/nav-python-deps` 隔离的 lupa **Lua 5.4**；没有打开浏览器或引擎窗口，没有修改项目依赖。
- 执行 `tools/migration/verify-body-cache-offline.py`，旧模块来自 `.tmp/outgame-cached-1792063134142`。
- **1,120,714 / 1,120,714 PASS**：Body 混合 30 步 × 12 触点，逐次读取、力/冲量/扭矩、速度 setter、姿态 setter、外部模拟积分、最终状态完全相等，并覆盖上述异常关闭。
- 实际旧/新 RaySuspension 24 组 × 90 步：4/8/16 轮，平地/倾斜，静止/动态支撑，接地/空中；完整轮胎状态、全部 native 调用序列、末状态、射线数量精确相同。
- 静态体分母为零、kinematic placement、invalidate 断引用均通过。
- 混合 Body 场景 native getter 次数：position 1980 -> 120，rotation 2340 -> 120，COM 1980 -> 90，linear/angular 各 750 -> 240。它们是离线调用计数，不能当实际 Web 时间。
- 证据：`evidence/body-cache-offline.json`，包含所有生产/旧模块 SHA256 和每组调用次数。

## 尚未关闭

- 新统一构建的实际 Bullet / Web 性能与驾驶曲线需由 root 同路径对照；离线 mock 不能代替它。
- 暂未改变 LegControl、射线数、物理频率、车轮摩擦或驾驶规则。
