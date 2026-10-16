# S2 护送剧情：自然完成验收工具

## 当前状态

6a 冻结构建已有一次 S2 Web 自然功能通关：原运行 14 项检查、0 运行错误。新 helper 对该真实录制离线复核 8 项通过，确认完整送达、真实选项、检查点、评级公式和实际/结算运输车血量相符。三拨敌人身份与演出仍为 `OPEN`。新加入的敌方道路追击工具尚未运行 Web，不能把本次结果算成新版驾驶工具实测。没有改动任务时钟、血量、完成状态、敌人或生产脚本。

## 本次实际结果

原证据：`evidence/story-natural-s2-manifest-6a53673c-2026-10-16T04-20-20-834Z/result.json`，原工具 SHA256 为 `ef4df293c9fa3511488f49353a8c68db610c220dee593806e6665cb441b706c8`；该报告保持原样。

- 实际任务送达时间 `325.5833` 秒：`phase=complete`，当时尚未 `finished`。
- 等待原规则中的对白结束后，实际结算任务时间 `353.7667` 秒；评级按该时间复算。
- 击杀 8、死亡 2、任务失败重试 2，完整送达 `456.86797 / 456.86797` 米，最终检查点统计 `3 / 3`。
- 实际 `truck.hp` 与结算 `stats.truckHp` 同为 `0.3623666666666492`；评级原公式复算为 B，实际也为 B。
- 原公开按键记录为评分 `2`、路线 `3`（路线在正常重试后再次选择）；最后实际 flags 为 `rate=1`、`road=2`。
- 原运行断言已验证正常返厅、地形数组释放以及实际环境音源播放。此处离线复核不重新运行这些过程，不另作性能或听感结论。

补充证据：`evidence/story-convoy-6a-offline-recheck.json`。使用 `node tools/migration/recheck-story-convoy-result.cjs` 对原 792 个样本及实际公开数字键按时间顺序重放新 helper，8 项检查 PASS；包含原报告 SHA、新 helper SHA、最终真实快照及 `encounterIdentity=OPEN`。这是一份真实 Web 录制的离线再验，不是新版工具的第二次 Web 通关。

基线为 Three.js `2026-10-15` 分支提交 `b276064942ae09c0227ec28d4cfda1d5ff006455`，以 `outgame-baseline.json` 固定快照为准。S2 原脚本 `shared/story/level2.js` SHA256：`db7b14ae31e679666c69e88ed91e727c77dc54b9d382c6de7c9b5a1b6ba71726`。导入 JSON 虽仍有旧日期元数据，其 `scriptSha256` 与该最新基线字节相符；CPU 检查直接核对二者。

## 逐项验收

开启 `VOX_STORY_CONVOY=1` 后，在现有公开剧情入口和真实驾驶、射击操作基础上，额外要求：

- 实际观察 `meet` 和 `convoy` 两个目标。
- 第一处分成选择真实按 `2`，路线选择真实按 `3`；输入发生在原版选项超时前，实际任务 flags 分别为 `rate=1`、`road=2`。默认超时选项不能冒充输入。
- 观察运输车实际经过 `cp=1`、`cp=2`，最终统计为 3 个检查点。
- 运输车实际从 `d=0` 行至完整路线终点，运输车最终存活，输出实际 S/A/B 评级。
- 评级按 H5 原公式复算：无死亡/失败且严格小于 S 时限为 S；死亡加失败不超过 1 且严格小于 A 时限为 A；否则 B。再按运输车 HP `<0.35` 限 B、`<0.7` 限 A；有真实 `truck.hp` 字段时，与结算 `stats.truckHp` 交叉核对。
- 保留原自然通关检查，包括运行错误、环境音、结算和回局外后的资源释放。

进度 `[0.15,0.5)`、`[0.5,0.76)`、`[0.76,1]` 的敌人数峰值、阻挡状态与样本数仅保存为诊断，不作为三拨出兵签收。首拨一只残敌贯穿三段同样能产生这些观测，所以 `encounterIdentity.result` 固定保留 `OPEN`，自然送达只给 `FUNCTIONAL_PASS`。敌方身份、生成事件顺序和三拨演出仍需后续证据。采样漏过硬性检查点时工具失败，不能单凭工具驾驶失败判断游戏有缺陷。正常关卡重试允许同一选择再次出现；同一选择持续展示不会延长原超时时间。

## 操作命令

由主任务选定当前冻结构建及 QA 服务，串行运行 GPU 验证。以下端口和 manifest 是本轮交接值，执行前须与 `/identity.json` 一致：

```powershell
$env:VOX_QA_PORT='4432'
$env:VOX_EXPECT_MANIFEST='manifest-6a53673c.json'
$env:VOX_STORY_LEVEL='2'
$env:VOX_STORY_CONVOY='1'
$env:VOX_STORY_SECONDS='720'
$env:VOX_STORY_AMBIENCE='1'
node tools/migration/check-story-natural-web.cjs
```

若生产文件已继续修改，以 `VOX_STORY_REFERENCE` 指向该冻结构建的 `scripts` 目录。工具会拒绝 Mission、MissionRules 或只读 probe 与服务身份不一致的情况。

## CPU 验证与冻结

`node tools/migration/check-story-convoy-controls.cjs`：106 个检查、15 项负控 PASS。覆盖缺少会合、默认/错误选项、漏检查点、未送达、运输车死亡、缺评级/输入、错误评级、实际与结算 HP 不符、超时输入，以及重试后的选择计时。额外加入“始终只有一只残敌、击杀为 0”反例：允许真实送达功能通过，但必须保留三拨身份 `OPEN`。结果保存于 `evidence/story-convoy-controls-offline.json`，明确标注 synthetic telemetry。

| 文件 | SHA256 |
| --- | --- |
| `tools/migration/story-convoy-acceptance.cjs` | `9edaa76057afd7dbd22d5fbd746be0ff050ca263fe39b3ccd5e56c6d56abee26` |
| `tools/migration/check-story-convoy-controls.cjs` | `0863ee4972c73ae56680280005e66a139cbbbf06d5429ce4c3025dcf1addedc2` |
| `tools/migration/check-story-natural-web.cjs` | `eb9e3a89ca958a8af4035807414789f2e0f0cf9fb6e42de2c15c288a99107323` |

驾驶命令 CPU 控制为 36 检查/8 变异 PASS，道路导航为 65 检查/7 变异 PASS。新增敌人跨高差追击仍走道路、沿路不被敌方近距离阈值刹停、每个道路点保留独立前进基线的控制。

本轮 6a 首次 S2 日志实际记录：任务时间 120.23 秒，玩家位于 `[-203.26,-10.37,-156.57]`，目标敌人位于 `[-119.67,2.57,-192.10]`，运输车 CP1 且 far/blocked。原工具因 `enemy=true` 完全跳过道路规划，可能直接撞向坡面；新工具从该观测位置选择实际道路 `lS1 → lS0`。此为工具导航问题及离线反事实，不证明新轨迹已通过；旧运行不会被新代码热替换。以上控制同样不替代真实关卡结果。
