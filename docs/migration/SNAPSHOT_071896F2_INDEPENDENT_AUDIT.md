# 071896f2 统一包独立离线审计

快照：`.tmp/outgame-cached-1792079256939`。发布清单：`manifest-071896f2.json`。源基线：2026-10-15 `b276064942ae09c0227ec28d4cfda1d5ff006455`。目标 Git HEAD 记录为 `9541dc59ef2f281cafa5126762a57550189e04dc`，本地未提交增量以逐文件 SHA 为准。

复算脚本指纹：`76b68c9b121257a93fa7af24905e25a7f1cf21ca3b7f83393d4a8215f9e1d7d0`，与构建 identity 一致。

## 精确文件数量与差异

| 范围 | 数量 | 结果 |
| --- | ---: | --- |
| 当前生产 `.lua` | 475 | 474 个与包一致，1 个打包后变化 |
| 快照 `.lua` | 475 | 475 个逐 SHA 与 identity 一致 |
| identity 脚本条目 | 475 | 无缺失/额外条目 |
| manifest Lua 条目 | 475 | 所有快照 Lua 均有唯一条目、长度一致，无额外脚本 |
| manifest 全部文件条目 | 7462 | 此处只记录总数，未对所有贴图/模型内容作全量验收 |

唯一差异：`scripts/ui/GarageHud.lua`。

- 快照/identity：`b40d5e73551351e621d06f02110b290312f79df0eee7b66a8383ef91eb6ed517`
- 当前生产：`e99aed05460d19f0ab132b695236a98fa04835343cf78c54be3b5cd6ed820148`
- 当前文件修改时间为本地 2026-10-15 23:49:20。差异是把创建逻辑提成 Build，并由 Create 用 xpcall 调用，失败时 Dispose、state=false、重新抛错；另加 state 类型标注。作用是防止局外初始化失败后残留半成品引发逐帧连锁报错。
- 该保护不在071896f2；不能声称此包与全部当前生产完全相同。其余474个Lua没有差异。未修改快照去伪造一致。

## 最新夹具证据哈希

核对13份报告中63条 production/scripts/resources SHA：全部同时匹配快照和当前生产，0条陈旧。工具兼容 `productionHashes`、`production`、`scripts`、`resources` 四种现有报告结构，不把源代码哈希误当生产哈希。

| 报告 | 已记录检查数 | SHA条目 |
| --- | ---: | ---: |
| match-target | 1329 | 5 |
| combat-result-production | 13005 | 8 |
| workshop-shop | 448 | 7 |
| story-result-quote | 1392 | 4 |
| story-input-progress | 296 | 3 |
| story-result-rows | 14656 | 2 |
| g5-result | 29 | 6 |
| g5-edit-touch | 92 | 6 |
| match-actions | 103 | 8 |
| tutorial-presentation | 215 | 4 |
| intro-driver-actions | 96 | 2 |
| inventory-layout | 108 | 5 |
| inventory-detail | 5867 | 3 |

这是报告哈希新鲜度核对，不是重新执行上述行为测试，也不合并为完整系统通过结论。

## 资源与AI接线

- `assets/UI/Outgame.json`：当前/快照/工坊测试期望 SHA 均为 `a364cf303923bcbdb991cd3011f0ff292b0873d721af66050fb47eed96fa6185`。manifest条目135677字节，boot/default/#blocking均在。
- `assets/UI/SalvageRules.json`：当前/快照/工坊测试期望 SHA 均为 `9132fe4d70675c98a31b0d8bd737239a39f07bef34d970f9f3d70f9054c4b01b`。manifest条目18415字节，boot/default/#blocking均在。
- 新 `combat/MatchTarget.lua` 同时存在于快照、identity及manifest，SHA为 `61fea4e117e5c7654c8b821ad56077bef41df80ea15d60cf337c80ad6843d40e`。
- 快照实际 `BattleController.Pick` 委托 `require('combat.MatchTarget').Pick(self,entry)`；BeforeStep把结果传入 `self.objectives:Goal(entry,self:Pick(entry))`，再把 goal/charge 传入 `entry.driver:Step(dt,goal,charge)`。接线存在，没有漏打新模块。

## 复现与边界

```powershell
node tools/migration/audit-unified-snapshot.cjs .tmp/outgame-cached-1792079256939
```

机器证据：`docs/migration/evidence/unified-snapshot-manifest-071896f2-audit.json`。审计总状态保留 FAIL，原因是上述唯一生产漂移；包内部一致、manifest脚本覆盖、资源一致、AI接线及全部63条夹具哈希均通过。

本批只新增审计工具与文档，没有编辑 production、构建、commit/upload或占用GPU。不签收真实Web/原生输入、画面、自然完整战斗或性能。
