# G5 检查点与打捞结算的云恢复边界

2026-10-16，接续现有 G5，不重开 G0。H5 固定基线为 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`。本批没有修改生产代码、构建或提交，也没有执行 GPU 测试。

## 实际结果

`tools/migration/check-g5-cloud-recovery.py` 已实际执行：**61 检查 PASS，5 个变异负控均被拒绝**。工具 SHA256 为 `ea595f2d1b610ff9f274f7798a1349ddf6aacb0d4d93086aea9222436aaf6c6b`。证据在 `docs/migration/evidence/g5-cloud-recovery-offline.json`；其中记录执行时的生产、真实资源和冻结源哈希。输出已采用统一审计的 `productionHashes / resources / testInputs` 字段，并按此最终工具重新实际执行全部检查与负控。

执行的都是当前生产模块：`Run / Inventory / Blueprint / Records / BlueprintStore / CloudStorage.Boot / CloudStorage.Decode / CloudSync / SalvageLobby.CommitRun`。JSON、文件系统、SDK 回调与身份接口是受控适配器，没有替换玩法规则、仓库规则或记录验证器。

与既有只验证蓝图的云专项相比，这次覆盖以下新的完整调用链：

- 真实无尽补给选择和 `Run.Save` → 原命名空间文件检查点 → 异步 SDK 确认 → 清空本地文件 → `CloudStorage.Boot` 批量读取、校验、双代 Hydrate → 新 `Run.New` 恢复。波次、阶位、生命、余额、得分、时间、伤害、维修、饥荒计数、seed、完整蓝图和限量库存逐项不变；已领补给不重复发放。
- 旧检查点在途期间保存新检查点，超时后不推进队列；旧请求明确成功后才上传最新值；再次清空本地文件后恢复最新已确认余额。
- 零生命或负限量库存拒绝恢复；启动继续但云写入封锁，不以默认记录覆盖远端坏记录。
- 已结束检查点使用原格式墓碑；清空文件并恢复后不复活旧局，也不凭空生成最佳分数。
- 打捞 `BeginRun / CommitRun` 实际写入；文件打开失败时整对象回滚、无多发货物；成功确认后清空文件，恢复货物、raid 计数及两个运行标记；重复提交同一 runId 不重复入库。
- 身份切换后拒绝旧账号回调，不以其成功通知结束当前恢复状态。

五个负控分别关闭 Hydrate、绕过无尽校验、让旧确认清空更新队列、绕过打捞 runId 幂等、去掉打捞失败回滚；实际都在对应断言处失败。最初夹具误把首次写入 generation 固定为 1，已改为比较实际已确认 envelope：启动会先为不存在的记录 Hydrate generation=1 墓碑，首次新写自然是后续代。另一次负控误匹配 `BeginRun` 而非 `CommitRun`，已收紧到后者上下文后重新执行，未将夹具失败计为生产缺陷。

## 本批没有证明的内容

这条离线路径没有发现需要修复的生产差异。它证明当前适配器接线与受控故障顺序，不证明真实平台账号已经保存、刷新并恢复。

以下仍 OPEN：真实账号 SDK/配额/网络行为、多设备并发与跨键事务、浏览器完整重启或热更新恢复、无尽自然完整多波及 Boss 击杀、打捞自然成功撤离、实际恢复页面呈现、可闻声音、手机持续性能。受控 rest/checkpoint 和成功结算输入不属于自然游玩成功证据，不可用于关闭 N02/N03/L04/L06 或 D03/D05 的真实账号要求。

## 重跑

```powershell
& 'C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' tools/migration/check-g5-cloud-recovery.py
```

依赖已存在的 `.tmp/nav-python-deps/lupa.lua54`。未更换生产资源，未生成平行存档格式。root 已登记统一审计的 `g5-cloud-recovery`，该注册不得用于替代实际账号验收。
