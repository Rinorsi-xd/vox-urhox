# G5 当前生产树离线回归补证

本轮从 `fa51051c99d78de5615612e9ef26704a494f82c2` 接续历史 G5 验收缺口，未重开阶段。H5 对照仍是 `2026-10-15@b276064942ae09c0227ec28d4cfda1d5ff006455`。仅修改离线检查器并新增证据，没有修改生产 Lua、`CURRENT_EXECUTION`、旧证据或 Git 提交。

## 实际结果

| 检查器 | 当前结果 | 原始 source 消费 | 负控 |
|---|---:|---|---:|
| `check-g5-edit-touch.py` | PASS，203 断言 | 冻结 JS 实际 `fillShop` 购买回调、`toggleShop`、`reset/rebuild/refresh`；4 组场景、11 个回调帧 | 7 个，均命中指定行为断言 |
| `check-salvage-vault.py` | PASS，675 断言 | 冻结 JS 实际 `_searchStep/_openSearch/update`；14 组、126 帧，另 15 个真实入口帧 | 4 个，均命中指定行为断言 |
| `check-g5-cloud-recovery.py` | PASS，61 断言 | 此检查器只绑定 H5 哈希；执行真实 Lua 保存、恢复、验证和结算方法 | 5 个，均命中指定业务断言 |
| `verify-endless-checkpoint.py` | PASS，50 断言 | 冻结 JS 实际 `persist` 的 10 个状态/失败组合，对照 Lua 持久化和事件入口 | 旧实际包在 source、清波、补给、改装返回 4 条路径均被指定告警断言拒绝 |

合计 989 项断言，20 次负控拒绝。计数只描述这些离线检查，不代表 G5 全部用户路径通过。

证据分别为：

- `evidence/g5-edit-touch-hoist-2026-10-16.json`
- `evidence/salvage-vault-hoist-2026-10-16.json`
- `evidence/g5-cloud-recovery-current-2026-10-16.json`
- `evidence/endless-checkpoint-current-2026-10-16.json`

四份报告绑定本次执行的生产与测试文件 SHA-256。前两份新增资源哈希；云恢复继续记录实际读入的资源。旧同名历史证据未覆盖。

## 修复的验收问题

历史改装检查在 `app.ResourceGate` 导入失败，保险库检查在 `parts.Dependencies` 提前导入资源时失败。扩大保存链复跑后，同样暴露 `GraphicsSettings -> Quality -> TouchMode -> UI` 和 `EndlessSession -> parts.Dependencies` 的导入适配缺口。

新增 `g5-offline-imports.lua` 只隔离当前方法未消费的原生/表现依赖。返回对象一旦被访问成员即报错，因此依赖扩散会使检查失败。真实 `Edit/BuildEditor/BuildInput/EndlessEditBar`、`RunRules/Run.Events/Run.AfterStep`、存储与校验模块仍被执行；没有在生产中添加分支或改变加载顺序。

改装旧检查只有 source 哈希，没有执行 source。新增 VM 消费冻结 JS 类，除去模块 import/export 后方法体保持原样；受控 DOM 与交易回调为边界适配。Lua 侧用实际商店按钮回调比较购买成功/失败、重复购买、满快捷栏、选中槽保持、购买库存和重置。另一个仅启用 source 对照的负控单独确认该新增比较可以拒绝错误的快捷栏赋值。拾取的质量冲量、交换丢物与飞行动画仍是手写期望，不冒称它们已由原始 source 计算。

云恢复旧第 2 个负控的锚点 `valid=require('endless.Records').Run(data)` 在 require 提取后已不存在，原来宽泛的 `except Exception` 将锚点 AssertionError 误记为拒绝。本轮改用当前 `valid=Records.Run(data)`，要求锚点唯一、只接收 LuaError 且包含指定业务断言。当前五个负控实际拒绝缺失 Hydrate、绕过记录校验、旧 ACK 清空新请求、重复结算、失败结算不回滚。检查点旧包负控也收紧到指定缺失告警断言，导入错误不能算成功负控。

## 覆盖与边界

- 无尽：实际清波、选择补给、改装返回驱动 Events/Persist；休整状态是否写入、失败告警、奖励不重放和改装重置/快捷栏有离线证据。没有运行完整自然波次、Boss 或 `Edit.Enter/Leave` 的真实场景生命周期。
- 打捞：保险库停车阈值、按住/松开、8 秒边界、重入、警报效果顺序；入口速度由实际 XZ 位置变化推导，含侧移、倒退、只变 Y、零/极小 dt、暂停/恢复、重建与结束。实际拾取、满载交换、原地丢物、重开、弹簧冲量和批量反馈亦有断言。没有运行完整自然搜撤或判定自然成功撤离。
- 存档恢复：真实 Lua Run/Inventory/Blueprint、Records、BlueprintStore、CloudStorage.Boot/Decode、CloudSync 和 SalvageLobby/StashRules；受控 FS/SDK 中检查新会话恢复、ACK/超时次序、坏记录、删除墓碑、重复结算和账号身份切换。SDK、账号、JSON 桥与 FS 为适配器，不是真实账号、网络或浏览器重载验收。云恢复自身没有执行原始 JS oracle。
- 没有启动 GPU、浏览器或游戏运行实例；没有新增视觉、音频、手机性能或骁龙 845 长时 30 FPS 证据。上述自然流程和目标设备指标继续 OPEN。

## 复跑

使用可用的 Node 和带 `lupa.lua54` 的 Python；本机依赖路径为 `.tmp/nav-python-deps`。从项目根运行：

```powershell
python tools/migration/check-g5-edit-touch.py
python tools/migration/check-salvage-vault.py
python tools/migration/check-g5-cloud-recovery.py --output docs/migration/evidence/g5-cloud-recovery-current-2026-10-16.json
python tools/migration/verify-endless-checkpoint.py --output docs/migration/evidence/endless-checkpoint-current-2026-10-16.json
```

历史冻结 source 与用于检查点负控的 `.tmp/outgame-cached-1792125241918` 必须存在；缺失它们是前置条件失败，不能转为负控 PASS。
