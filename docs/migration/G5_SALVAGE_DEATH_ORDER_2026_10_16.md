# G5 打捞同一步死亡结算顺序

日期：2026-10-16。目标分支 `1016`，HEAD `f94827b26fc12b707e6d6904d093e16358caaf41`。沿用现有阶段，不重新开始 G0。

## 来源与触发

源固定 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`，实际快照按 `baselines/b276064942ae09c0227ec28d4cfda1d5ff006455.json` 校验。

`three/src/salvage/salvageRun.js:858` 的 `afterStep()` 遍历 `[...this.units]`，按照 Map 入场顺序处理同一个物理步内死亡的敌车。每辆车依次爆炸、分配 K 编号、创建对应车型的残骸表、显示击毁提示、增加热度、警觉据点并移出世界。

原迁移 `scripts/salvage/Run.lua:128` 使用倒序遍历。单车死亡通常不明显；同一步至少两车死亡时，K 编号对应的地点和车型、爆炸/击杀提示、首次据点警觉顺序都与源相反。玩家按 K 编号或等距目标遍历搜索时，后续 RNG 会分配到不同车型的掉落表。

## 生产修改

仅修改 `scripts/salvage/Run.lua` 的死亡遍历。改为从第二个 entry 向前走：活车递增索引，死车通过实际 `Director.Remove()` 删除后继续使用当前索引，避免相邻死亡被跳过。保留原爆炸、掉落、声音/提示、热度、警觉、物理及单位释放逻辑。当前 `Alert/Remove` 不会向 entries 添加单位，前向删除符合源固定快照的消费顺序。

- 修改前 SHA256：`897680da2aa872112316a73b55298c4d2c867d5859f914d74679ec9197d2fef9`
- 修改后 SHA256：`8f9a11f802cb98b4ad7d8d0b11ba528c05fa1d30b9c8b9f1538d9e32b172b281`

## 实际验证

`tools/migration/check-salvage-death-order.py`：**256 个真实源场景，6,136 项检查 PASS；3 个行为负控全部拒绝**。

执行未改写的冻结 JS `afterStep/_alert/_session/_reveal` 与真实 shared 掉落模块；目标执行生产 `Run.BeforeStep/AfterStep`、`Director.Alert/Remove`、`RunRules.Open/SearchStep` 和 `Loot.FromTable/Drops`。不复制结算算法来冒充生产模块。

- 六敌车全部 64 种生死组合，分别覆盖全部 12 种原车型掉落表；保留中间活车、连续死车和全部死亡。
- 实际爆炸位置/大小/精英标记、提示/热度/警觉顺序、K 编号、对应残骸位置与奖励表。
- 实际 `Director.Remove` 同步 entries、world.units、HUD tags；释放一次，释放后调用 Position/Flush 或重复 Dispose 会立即失败。
- 同一对象第二次 AfterStep 不重复结算；重新打开同一残骸不重新抽奖。
- 两组入口：已被击毁的车辆；通过生产 BeforeStep 在受控位置触发掉图。覆盖 `-300.001 m`、恰好 `-300 m`、`-299.999 m`，验证严格边界和原掉图原因。车辆运动和伤害状态由适配器提供，**不是实际飞机/物理坠毁验收**。
- 实际掉落 RNG 次数、生成物品及稀有度、揭示时长；继续通过真实 SearchStep 入仓，比较空舱和 19 格近满舱的最终货物、价值与装不下余货。没有更改或补抽 RNG。
- 负控：恢复旧倒序、删除后仍递增而跳过相邻单位、所有车型错误改用 rat 表，均在业务断言中被拒绝。

首次源夹具使用旧 `sim.units` 数组引用读取结果，未跟上 H5 的 filter 重新赋值；修正为读取实际 `run.drive.sim.units` 后，修改前生产在 case 4（mask=3、双车死亡）出现真实顺序差异。新工具保留旧行为负控，不把夹具错误算作产品缺陷。

证据：`evidence/salvage-death-order-offline.json`。包含实际源 SHA、5 个消费模块 SHA、逐条断言及负控失败点。

## 受影响回归

| 检查 | 检查数 | 结果 |
| --- | ---: | --- |
| `check-salvage-vault.py` | 675 | PASS，4 负控 |
| `check-salvage-encounter-feedback.py` | 104 | PASS，6 负控 |
| `check-g5-result.py` | 29 | PASS |
| `check-salvage-loot-feedback.py` | 476 | PASS，8 负控 |
| `check-g5-extraction.py` | 547 | PASS |

合计旧回归 1,831 项，本批合计 7,967 项。旧 encounter/result/loot/extraction 工具首次重跑在业务执行前因 require 顶置后提前加载原生依赖而失败；仅补工具端严格排除依赖与原有 tween 替身的初始化时机。实际被核验的规则、Director、Cinematics、音频、结算、仓库及 toast 消费继续执行生产代码，未改变断言或生产依赖来绕过检查。

## 验收边界

本批是 G5 的源行为遗漏修复，不是 CPU 热点优化。没有构建新 Web 包、没有占用 GPU 或执行 Native 计时，也没有提交/上传。旧用户 4471 与冻结 fb3 包均不含此修复。root 后续统一包实际多车击毁、自然打捞/成功撤离、最终画面和真实账号仍待验；骁龙 845/TapTap 持续 30 FPS 不因此关闭。

复跑：使用已有 Python 运行 `tools/migration/check-salvage-death-order.py`。需保留冻结源快照及 `.tmp/nav-python-deps` 的 Lua 5.4 适配器，与现有 G5 源对照工具相同。
