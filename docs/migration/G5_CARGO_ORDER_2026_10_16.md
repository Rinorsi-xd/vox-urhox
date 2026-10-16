# G5 满仓换货的同价取舍顺序

## 基线与范围

- 实核 H5 当前分支 `2026-10-15`、提交 `b276064942ae09c0227ec28d4cfda1d5ff006455`；相关三个源文件无未提交改动。
- 使用既有冻结清单校验 `three/src/salvage/salvageRun.js`、`shared/salvage/salvageLoot.js`、`shared/salvage/items.js` 的 SHA，再执行实际 H5 `_swapIn`、`roomFor`、`slotsUsed` 和售卖价函数。
- 生产只修改 `scripts/salvage/Loot.lua`。独立检查器 `tools/migration/check-salvage-cargo-order.py`，原始结果 `evidence/salvage-cargo-order-offline.json`。
- 没有启动 Runtime、浏览器或 GPU 测试；没有更改 4453、构建、提交、推送、共享性能模块或统一审计脚本。

## 已修正的玩法差异

H5 货舱使用 `Map`，满仓 F 换货时按单格价值稳定排序。同价时，先入仓的货物先丢；一类物品完全丢光、再次拾取后排到队尾。原 Lua 用 `pairs(cargo)` 选择最低价，在相同价值下结果依赖 Lua 哈希遍历顺序。

实际反例：先取得 `part:drive3`，再取得同价的 `part:hover2`，装满货舱后换入反应堆。H5 丢 `drive3`；旧 Lua 本轮丢 `hover2`。这会改变留下的物资及地上丢弃箱内容，属于 L02 的具体功能差异。

现在 `Take` 记录首次入仓顺序，`Swap` 按这个顺序选择最低价；丢光时移除序位，补充已有堆叠不改变顺序。顺序放在弱键旁表，不给 cargo 数量对象增加元数据字段，因此 HUD、载重、容量、结算和既有存档协议继续读取纯物品数量。

生产运行从空货舱开始，所有拾取通过 `Loot.Take`。预先填充的兼容调用没有原始入仓历史，第一次使用按物品 ID 固定排序；不能声称这类无历史数据能恢复已经丢失的 H5 Map 顺序。结束结算换用净 cargo 后不再进行换货。

## 验证结果

- 实际 Lua 5.4 模块对照 **32 个源执行场景、877 项检查 PASS**，包括两种同价入仓顺序、部分堆叠、材料、两格物资、容量边界、无法换入自身、连续混合拾取与换货。
- 其中两条通过实际 `RunRules.SearchStep` 消费 F 换货，验证生成的地面货箱确实保留 H5 应丢弃的物品；其余针对 `Take/Swap` 的规则序列使用合成货舱，不能代替自然一局的搜刮证据。
- 使用固定旧提交 `48ef15f2c9c95c400f91ee6e34309399d02b3733` 的原 `Loot.lua` 重跑同一套输入，SHA 与改前工作区相同；本轮出现 **73 项差异**，旧实现负控确实被拒绝。Lua 哈希顺序可变化，负控具体差异数可能变动，验收要求是旧实现不能全部通过。
- 弱引用生命周期检查通过：丢弃 raid cargo 的最后引用后，执行 GC，不会被顺序记录永久持有。
- `git diff --check` 本次文件通过。检查结果记录生产、资源、原版输入及检查器 SHA。

复跑：

```powershell
& 'C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' tools/migration/check-salvage-cargo-order.py
```

## 未通过或未运行的边界

原关联 `check-g5-edit-touch.py`、`check-salvage-vault.py` 本轮均尝试运行，但之前 require 提取到文件顶部后，旧离线适配器未补新依赖：前者在 `endless/Edit.lua` 加载 `app.ResourceGate` 时退出，后者在 `salvage/Run.lua → parts.Dependencies → parts.Defs` 的资源适配处退出。没有修改旧工具或把这些失败改写为 PASS。

本修复是功能一致性增量，没有测得性能收益。自然搜刮完整流程、真实账号、Web 新包和骁龙 845 在 TapTap 内长期稳定 30 FPS 仍须统一运行验收，不能由此次离线结果签收。
