# G4 玩家死亡时的敌车停车分支

## 固定基线与问题

固定 H5 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`。

原 `three/src/battle/storyMission.js:298` 在玩家死亡且敌车目标为 player 时执行 `u.step(dt,PARK);continue`。实际 `shared/combat/carUnit.js:361` 的 step 保留物理、无瞄准转轴动作，但不调用 fire。原 fire 才负责转轴武器坐标同步、武器系统步进和产生射击特效。

迁移版虽然不再调用 AI，仍让这些敌车以自身位置作为 aim，执行转轴武器同步、武器 Step(false)、特效和音频消费。这会让死亡等待期间继续推进子弹/武器状态，也使炮台动作与原版不同。

## 已修改

只修改 `scripts/story/Mission.lua` 的 BeforeStep：

- 玩家死亡且敌车目标是 player/default：保留 PARK 车辆物理步与 `StepRotors(nil,nil,dt)`，不处理武器或消费 FX/音频。
- 以运输车为目标的敌车继续原战斗流程，玩家存活时沿用原流程。
- 没有更改相机、音效参数、伤害、敌人数、地图或着色器。

最终 Mission.lua SHA256：`cefa9c78ac98989a6ebbcb2139ce2a17edce61a362d9028faf876df6b5008cc1`。

## 实际验证

新增 `story-dead-player-park-source.mjs` 加载冻结的完整 StoryMission 与 CarUnit 模块，执行真正的 beforeStep、step、fire；替换物理、AI、武器依赖以记录调用。`verify-story-dead-player-park.py` 执行实际 Lua Mission.BeforeStep，对照玩家存活/死亡、default/player/truck 目标、有/无运输车、扳机开/关的 24 种组合。

264 项检查通过，涵盖驾驶调用、停车指令、物理步、转轴步、aim、武器转轴同步、武器步、开火、FX 消费及 Lua 音频消费。三个负控有效：49c15 旧版产生 40 处差异、删除停车转轴步产生 8 处差异、错误地让 truck 目标也停车产生 22 处差异。

证据：`evidence/story-dead-player-park-offline.json`。工具输入、源哈希、生产哈希和负控失败项均已记录。按 root 要求，本子任务没有修改共享审计注册器；合包时由 root 注册 `story-dead-player-park`。

受 Mission 整文件哈希影响的 8 份报告已先保留至 `evidence/history/mission-before-dead-player-park-2026-10-16/`，再全部实际运行：result-quote 1392、input-progress 260、choice-epilogue 171、objective 934、choice-presentation 803、death-order 2572、convoy-targets 128、mission-timers 131。加上本次 264 项，共 6655 项通过。

实际工作区 freshness `.tmp/dead-player-park-freshness.json` 为 FRESH、drift 0。本轮没有构建、GPU、原生运行、提交或上传。

## 验收边界

只验证标准非钻头接管车辆的逻辑调用。源 CarUnit 的结构回复与正常战斗分支原有的物理/转轴调用顺序不属于本次对照范围。没有签自然死亡/复活路线、实际碎片画面、音频听感、全关卡或性能通过。

复跑：`C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe tools/migration/verify-story-dead-player-park.py`。
