# G4/S04 同帧死亡与逃跑顺序

本项属于 **0bcd 之后的下一批增量**，不在 `manifest-0bcd53d6.json` 内。没有构建、GPU、浏览器、原生、提交或上传操作；不关闭完整 S04/S05。

## 基线与根因

- 冻结 H5：`2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`。
- 冻结源 `StoryMission.afterStep` 按 Map 的敌车生成顺序处理死亡，逐车更新 `lastKill`；第一关清场后按这个位置生成航行日志。原关卡 `scouts` 实际生成三艘侦察艇，下一目标台词明确“最后那艘掉了个东西”。
- 迁移版 `Mission.AfterStep` 为方便删除采用倒序，导致同帧多杀保留第一辆的坐标，同时改变爆炸、逃跑光效和通讯之间的先后顺序。

## 修改范围

唯一生产编辑：`scripts/story/Mission.lua` 的 `AfterStep` 敌车循环改为正向 `while`。存活时索引加一；删除后处理移到当前位置的下一辆。继续原有显式 Dispose、世界/HUD 清理和规则事件，没有增加每帧临时表。

- 最终 `Mission.lua` SHA256：`197b07ced3daa75b2586be71a77d1984c0a43502fa1f9c3bfc3116270617026e`。
- `MissionRules.lua` 没有编辑，测试关联 SHA256：`9162e148d3d2075385288ede7c052a2706d4b88b257c4fb7970ba9cfe32157c4`。
- 旧控制脚本逐字等于实际 0bcd 中的 `Mission.lua`，SHA256：`448c2965ef3e354068cce1ee007e1c40d3b0ecc9f4896a719d512fac77581849`。

## 已验收

工具直接运行冻结完整 JS `afterStep/update` 与原 `KINDS.capture.onFlee`，对照实际生产 Lua `AfterStep`、`MissionRules` 和 `Mission.Events`。引擎对象使用测试替身，不加载场景。

`verify-story-death-order.py`：**223 场景、2572 检查 PASS**。

| 检查 | 结果 |
| --- | --- |
| 三侦察艇七种非空死亡 mask，含同帧双杀/三杀 | lastKill、日志坐标及实际 Events→AddIntel 消费一致 |
| 存活、死亡、逃跑、剧情免爆、noBlast、Boss 死亡的 216 组合 | 击杀数、剩余顺序、爆炸/逃跑光效/对白/横幅顺序与源一致 |
| 同一对象第二次 AfterStep | 不重复击杀、爆炸、逃跑和对白 |
| 对象生命周期 | 被移除对象 Dispose 恰好一次；存活对象不释放 |
| 容器清理 | entries/world.units/HUD tags/live snapshot 一致，保留玩家和无关标签 |
| 独立旧脚本控制 | 复现 192 场景差异，其中四个同帧多杀 mask 全部失败 |

证据：`evidence/story-death-order-offline.json`。初次工具执行遗漏浏览器 `performance`、`flat` 环境时仅测试工具失败，未修改生产绕过；现执行完整源顶层常量，只有 Three.js 未使用的向量构造器替身。

复跑：`C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe tools/migration/verify-story-death-order.py`。

## 下一包验收

1. 按下一不可变包身份核对上述生产 SHA；不可借 0bcd 的开篇测试签收。
2. 实际第一关到侦察艇遭遇战，确认多杀后日志出现在源规则所指定的最后处理敌车处，开过去自动拾取并进入最后采集器目标。
3. 实际第四关狐狐撤退后，确认逃跑光效/通讯顺序、敌车及头顶 HUD 清除正常。
4. 自然全关、声音试听、视觉 1:1 和手机持续性能仍 OPEN。

## 第一关自然日志验收工具（已准备，未运行 GPU）

直接扩展现有 `tools/migration/check-story-natural-web.cjs`，不新建玩法入口，不改生产或 QA probe。默认仍要求完整自然通关；显式 `VOX_STORY_LOG_ONLY=1` 才在拾取日志、进入 `east` 后结束子路线，并正常返厅检查地形数组释放。

当前 14f 包的串行运行命令（由 root 在现有自然开篇检查结束后执行）：

```powershell
$env:VOX_QA_BASE='http://127.0.0.1:4370'
$env:VOX_EXPECT_MANIFEST='manifest-14f59378.json'
$env:VOX_STORY_LEVEL='1'
$env:VOX_STORY_LOG_ONLY='1'
$env:VOX_STORY_SECONDS='900'
& 'C:/Program Files/nodejs/node.exe' tools/migration/check-story-natural-web.cjs
```

开始前校验实际 manifest、probe SHA、当前 `Mission.lua` 和 `MissionRules.lua` SHA，错包立即拒绝。公开入口为大厅 → 出战 → 剧情模式 → 01 坠舰 → 开始任务；全程仅 F8 读取、真实鼠标/键盘驾驶与射击，不用传送、秒杀、改时钟或阶段。

子路线逐条断言：

1. 先经过真实前置目标，并观察 `scouts/fight` 中的三辆敌车。
2. `log` 出现时击杀比战前增加 3、敌车归零，不能拿 90 秒超时撤退代替击杀。
3. 此时情报数为 2、采集器数为 2，日志具有实际有限三维目标坐标，保存状态与截图。
4. 实际自动拾取后进入 `east`，情报数精确变成 3、采集器仍为 2、击杀仍为 3。
5. 实际返厅后地形数组字节归零。整条路线错误、超时或返厅失败保留失败证据。

状态转换与异常先落 `result.json`，再截图；截图 15 秒截止，崩溃/OOM 不继续截图。日志子路线不执行文件系统内存扫描。证据在 `evidence/story-natural-s1-manifest-14f59378-<timestamp>/`。

已实际运行：Node 语法检查；纯 Node 观察器 7 场景/23 断言，包括正常拾取、超时不足三杀、跳过日志、情报错误、目标非法、未观察遭遇战及错误拾取，全部 PASS，未启动浏览器。

**边界**：这里尚无本包自然第一关运行结果。公开路线自动驾驶可能受地形/道路选择阻塞；deadline 不直接证明玩法缺陷。现有只读 probe 不提供每辆敌车的同帧死亡顺序，因此这个 Web 子路线只能签真实击杀→日志目标→实际拾取；同帧最后处理位置仍由上面的 JS/Lua 离线对照证明，画面仍须逐张查看。第四关自然撤退、整关通关及真机性能继续 OPEN。
