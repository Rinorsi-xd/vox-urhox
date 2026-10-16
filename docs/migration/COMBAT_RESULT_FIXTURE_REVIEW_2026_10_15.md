# 竞技 MVP / 结算 / 再匹配工具离线复核

沿用 2026-10-15 `b276064942ae09c0227ec28d4cfda1d5ff006455` 基线与当前迁移阶段。本批只修改运行工具及新增报告，未改 production，未启动 native/Web 或占用 GPU。

## 核对结果与工具修改

1. 实际 `app.MvpShow.Skip` 在 preparing 时直接忽略按键。必须等 active、done 或 failed 才继续；failed 现在明确终止，不能靠最终有“再来一局”按钮把缺失的 MVP 冒签通过。
2. 实际 Skip 首次在 t<7.1 时跳到 7.1，第二次把 finishing 设为 0。实际 Update 在获得焦点后累计 finishing>=0.36 才 done 并 Dispose。工具现在每次 Space 后取新探针，核对跳转和 finishing，再等真实 done，最后才等可见且有有效命中矩形的结果按钮。若首次 Space 时动画已自然超过 7.1，则只需一次 Space，工具不会错误坚持必须两次。
3. `MatchActions.Again` 设置 restartBattle 后 Leave；`HangarApp.Update` 返回 hangar 时 EnterBattle；EnterBattle 调实际 `LoadingFlow.QueueBattle`；该方法重新 Matchmaker.Find 并创建新的 loadingFlow.match。工具现在直接采集 active matching flow 的 mode/stage（queue/found/roster），再等待新对局 prep/live、加载页结束及 capture.sequence 增长，区别于旧世界 Restart。
4. 冻结 H5 `shared/battle/matchmaker.js` 和生产 `Matchmaker.Find` 都过滤 profile.recent，再从名字池不重复移除，最后保留最近30名字。当前池70名字，3v3生成5机器人、4v4生成7机器人，正常成功存档下下一局与上一局名字互斥。工具额外检查人数不变、名字存在、同局唯一、与上局互斥；这只是直接 queue 证据之外的辅助检查，不以随机不同替代重走匹配。若存档失败，此互斥条件不再保证，报告明确写出前提。
5. 此前 `state!=='over'` 也会接受缺失 battle.state；现在只接受明确 prep/live，并对生命周期访问做空值保护。

## 离线验证

```powershell
node tools/migration/check-combat-result-flow.cjs
& 'C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' tools/migration/check-combat-result-production.py
node --check tools/migration/check-combat-performance-web.cjs
```

- 工具控制流 **17 项 PASS**：preparing、早跳两次、自然晚跳一次、already-done、MVP失败、被忽略按键、fade失败，以及旧名单重排/重复/缺项的反例。
- 实际生产 Lua 5.4 **13005 项 PASS**：真实 MVP Skip/终止 Update；真实 Matchmaker.Find 在3v3/4v4各500组连续两场匹配（刻意使用同seed），验证完整的名字过滤、唯一性和人数契约。使用真实 Arena 数据，存储为成功的内存夹具，渲染stage/music/session为替身。
- 最新浏览器工具通过 Node 语法检查。逐文件哈希证据：`docs/migration/evidence/combat-result-production-offline.json`。

## 修改文件与验收边界

- `tools/migration/check-combat-performance-web.cjs`：消费新 helper、记录 MVP 各阶段及再匹配队列快照。
- `tools/migration/combat-result-flow.cjs`：集中本批可独立测试的工具状态机与名单断言。
- `tools/migration/check-combat-result-flow.cjs`：纯 Node 反例和状态测试。
- `tools/migration/check-combat-result-production.py`：实际 Lua 行为与名字契约验证。

本报告没有新 Web 通过结论。下一轮仍需真实输入、资源准备、MVP渲染、按钮点击、返回释放、匹配加载和退出清理证据；新 helper 只避免已知的工具误判，不承诺 GPU/浏览器时序、画面1:1或性能通过。
