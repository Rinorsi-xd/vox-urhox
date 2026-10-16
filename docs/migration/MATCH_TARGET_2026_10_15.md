# 竞技 AI 选敌与三模式目标独立核对

基线：2026-10-15 H5 `b276064942ae09c0227ec28d4cfda1d5ff006455`。沿用当前迁移进度，不重开 G0。本报告仅负责本批竞技 AI 行为核对，没有修改 production，也没有构建、提交、上传或占用 GPU。

## 执行结果

`tools/migration/check-match-target.py`：**1329 项通过，0 项失败**，Lua 5.4。原始结果及源/目标逐文件 SHA256：`docs/migration/evidence/match-target-offline.json`。检查前后目标哈希相同，未发生并发代码漂移。

运行命令（项目根目录）：

```powershell
& 'C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' tools/migration/check-match-target.py
```

测试依赖 Node.js 与现有 `.tmp/nav-python-deps/lupa.lua54`。输出 JSON 为运行证据，不是发布包标识。

## 对照方法

`check-match-target-source.cjs` 用 `vm.SourceTextModule` 执行冻结的 `three/src/battle/matchSession.js`，保留原 import，只在末尾追加三个模式类的 export。真正执行冻结的 `shared/ai/driver.js`、`shared/battle/match.js`、`shared/battle/shieldQuery.js`；音频、UI、场景创建等无关 import 使用 `SyntheticModule` 替身。四份源文件读取时先与基线清单逐 SHA256 核对。

`check-match-target.lua` 加载实际 `combat.MatchTarget`、`combat.EnemyDriverNav`、`combat.BattleObjectives`，调用真实 `Pick`、`Visible`、`Goal`、`At`。单位和射线世界是受控夹具；不重新抄写目标算法。JS 调用实际 H5 `_pick`、模式 `goal/_assign` 与源 LOS，先生成逐步骤黄金结果，再与 Lua 的目标 ID、缓存对象复用、过期时间、射线参数、目标坐标/半径/射击/被动/冲锋状态作深比较。

## 逐项覆盖

| 范围 | 检查数 | 已核对行为 |
| --- | ---: | --- |
| 选敌、LOS 与缓存 | 326 | 可见优先、残血权重、同分稳定顺序、友军/死亡过滤、260 米边界、射线目标偏移/自身排除/目标命中/0.6 米容差、0.5 秒严格边界、死亡失效、空缓存立即重试、基地护盾内敌人过滤，另含 300 组确定性的 8 单位随机场景 |
| 三模式目标 | 961 | 歼灭/争夺/护送，双阵营与四角色，可见/不可见/无敌人，60/90/100/130 米严格阈值，40 秒边界与突然死亡；护送调用真实路线插值 |
| 争夺任务分配 | 32 | 0/99.999/100/101 分、敌盾开启/关闭、重型/狙击稳定优先、死亡与玩家排除、站点状态数组反序时按 ID 对应、2 秒过期值 |
| 争夺连续缓存 | 10 | 双队分别在 0/1.999999/2/3.999999/4 秒改变敌盾及积分，2 秒前保留旧任务，边界重新分配；100 分时停止新分配反应堆偷分任务 |

源站点任务每个点的额外负载成本是 120；源码没有硬性“最多两车”截断，检查按实际代码而非注释实现。

## 审查发现与修复状态

首轮独立审查发现争夺任务存在三处偏差：缺少己方积分小于 100 的反应堆突袭条件；缺少重型/狙击优先的稳定分配顺序；站点状态按数组位置读取而非 ID。已回报 root，root 修改 `BattleObjectives.lua`；本报告的 1329 项结果覆盖这些修改后的实际文件。

`BattleController.lua` 的集成点已经检查为 `objectives:Goal(entry,self:Pick(entry))`，并把返回的目标和 charge 传给真实驾驶器。该静态集成检查不等于实机战斗验收。

## 保留的验收边界

- PASS 只表示受控输入下本批目标与缓存行为和冻结 H5 源一致，不表示整个竞技或 G3 已完成。
- 未运行真实物理世界、原生/Web 自然匹配、遮挡场景、射击命中、驾驶寻路、帧率或持续性能验收。
- 护送路线是受控的两段端点夹具，未替代真实地图全路线行驶验证。
- 新代码尚需进入 root 统一的不可变运行包，再通过实际三模式入口验证；旧包截图与结果不能签收这批新增代码。
