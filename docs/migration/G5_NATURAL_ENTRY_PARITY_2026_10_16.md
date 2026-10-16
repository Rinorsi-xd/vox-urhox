# G5 自然流程入口差异修复

## 范围与生产文件

基线为冻结 H5 `2026-10-15` / `b276064942ae09c0227ec28d4cfda1d5ff006455`。检查器逐个验证源文件 SHA256，再执行原方法；没有把尚未实测的自然流程判成缺失功能。

本轮生产仅改五个文件，已冻结交给主任务构建：

- `scripts/app/SalvageLobby.lua`：`CargoSale/SellCargo`。
- `scripts/ui/SalvagePage.lua`：商人出售页未选商品时显示“卖掉全部货物”，回调落真实交易。
- `scripts/salvage/Director.lua`：恢复逐辆活敌上限与遭遇激活时序。
- `scripts/app/EndlessSession.lua`：下一波接受 `KEY_KP_ENTER`。
- `scripts/app/TrialSession.lua`：真实按键轮询包含 `KEY_KP_ENTER`。

未修改 root 的包工具、共享特效或 `CURRENT_EXECUTION`，未提交或推送。没有启动 Runtime/GPU 或浏览器。

## 最终行为

### 批量售货

冻结源 `shared/ui/salvageHub.js` 的 `_deal` 在出售页未选商品、有散装货物时提供按钮，`_dump` 只售卖 `cat=cargo` 的 `stash.loose()` 数量，并按 `sellPrice` 计价。目标保留该入口、报价、库存结果、单次成功音和汇总通知。购买页、已选商品、无散装货物时不显示；迟到回调还会复查页面状态。

目标按一次完整快照交易保存，返回保存失败或抛异常时恢复原始 `data` 对象、全部物品与金额，不留下本轮部分成交。实际 `BlueprintStore.Write/Read` 用受控文件系统验证成功重读和打开失败。H5 是每种货物调用一次 `save()`，其存储错误被吞掉；本轮明确采用项目既有的保存失败回滚约定，不声称异常行为与 H5 一致。

真实装车零件、材料和带入道具不属于 cargo，均不出售。带入道具列表不会因售货扣减；真实 `Usage` 的当前车与其他车位占用路径也执行了检查。

H5 `Map` 的历史插入序没有保存在目标数量对象协议中。目标使用导出的 `Rules.itemOrder` 稳定遍历，不伪称能还原已丢失的历史顺序。源对照覆盖倒序获得的货物，批量全部出售的最终库存、总价、总数量和汇总通知相同；目标没有逐项成交动画或逐项通知。

### 遭遇容量与时序

源 `_alive/_addUnit/_spawnEncounter/_encounters/_alert/_cleared` 实际执行，目标 `Director.Add/Spawn/Step/Alert` 实际执行。单位、AI 驱动、射线、网格对象是边界适配。

- 12 活敌遇三辆小队：生成两辆，遭遇 active，left 清空。
- 14 活敌、落点全失败或建车失败：当次仍转 active，下一次检查才清除并生成源规则补给；没有擅自保留 dormant 等待。
- 上限统计活敌，残留死亡条目不占用名额。
- 达到上限后仍走完原落点/RNG 遍历，不从小队循环提前返回。
- 伏击警觉发生在 `Step` 调用 `Spawn` 后；源 `_spawnEncounter` 本身不警觉。
- 空 left 回退 squad，营地、狙击哨、巡逻及 380 米严格边界均对照源。

原 `tools/migration/check-salvage-director.lua` 的“直接 Spawn(ambush) 立即警觉”旧断言与冻结源方法边界不符。本轮改为直接 Spawn 不警觉，并新增外层 Step 警觉断言；补齐旧夹具遗漏的 `fx.Loot` 边界。新 runner 实际执行该旧脚本在创建 Scene 之前的完整规则段，**21 条 PASS**，其后原生渲染段未运行。

### 数字键盘 Enter

执行源 `EndlessSession.key`，用当前 `.emmylua/InputEvents.d.lua` 的不同枚举值驱动实际 Lua `TrialSession.PollKeys -> HandleKey -> EndlessSession.HandleKey -> NextWave`。覆盖普通 Enter、数字键盘 Enter、重复键边界及输入框/失焦/最小化/对话框阻挡。

重复键边界在测试输入适配层表示为没有新的 GetKeyPress 脉冲；没有在离线环境验证引擎原生键盘事件。

## 验证

运行：

```powershell
& 'C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' tools/migration/check-g5-natural-parity.py
```

结果：**221 项断言 PASS**（新对照 200 条、旧导演脚本 CPU 段 21 条），实际源 **6 个售货场景、13 个遭遇场景各 2 帧、4 个按键场景**，**9 个行为负控均拒绝**。

负控覆盖错误卖掉非货物、用总库存替代散件、不回滚、缺 UI 入口、整队容量门槛、死亡条目占容量、零生成不激活，以及遗漏按键 handler 或真实轮询。每个负控要求唯一替换锚点和指定业务断言失败，不用任意异常冒充成功拒绝。

工具：`check-g5-natural-parity.py`、`check-g5-natural-parity.lua`、`check-g5-natural-source.cjs`，以及同步契约的 `check-salvage-director.lua`。证据：`docs/migration/evidence/g5-natural-parity-2026-10-16.json`，包含实际源、生产、资源与检查器 SHA。

本检查不签收完整自然无尽、自然成功撤离、真实账号/网络云存档、浏览器新包、声音播放、UI 像素或手机性能。它是上述具体入口与规则差异的离线源消费回归。
