# 剧情大车交互尺寸回退与视图缓存

H5 基线：10/15 `b276064942ae09c0227ec28d4cfda1d5ff006455`。本批是 `manifest-45f10158.json` 之后的候选，未构建、未运行 GPU，不借旧包验收。没有重做开场或修改共享音频。

## 确定差异与修复

冻结 `three/src/battle/storyMission.js` 的 `carSize()` 同时用零件数量和 `visual.root` 身份缓存模型世界包围盒；模型未出现或包围盒为空时，按蓝图占用格包围盒和 `CELL=0.5m` 回退，且模型就绪后重测。

Lua `Mission:CarSize()` 只用零件数量缓存，视图替换但数量相同会继续使用旧尺寸；无视图/空包围盒始终回退为半宽 2m、上下 1.5m。大车中心高于地面的情况下，这会使原本够得到的情报、到达区和采集器交互失败。

本批仅修改 `scripts/story/Mission.lua` 的 `CarSize`：加入当前 root 身份，保持同 root 同数量的原缓存语义；模型未就绪按源蓝图格回退；只有成功量得模型才缓存该 root。旧 root 仅比较身份，不访问其属性或方法。没有改动各玩法半径、尺寸放宽公式、物理或任务状态机。

生产 SHA256：`d6074aa993ee0ccd2ac7c155e4c7f01f7a6e4d9429e22d0adcf6c627926ef7fc`。

## 实际 CPU 验证

`verify-story-car-size.py` 执行完整冻结 H5 类的实际 `carSize/near` 与生产 Lua `CarSize/MissionRules.Near`，外部模型包围盒为受控适配器。33 序列、43 帧、10,535 检查 PASS，覆盖同 root 缓存、同数量替换 root、旧 root 退役后禁止读取、未就绪到就绪、视图消失恢复、数量变化、空蓝图和 24 组格尺寸。每帧包含拾取、到达、夺点、擦涂鸦四类严格边界输入；同时比较模型量测/蓝图统计调用次数。

负控直接加载不可变 45f 中的真实旧 Mission 模块，SHA `cefa9c78ac98989a6ebbcb2139ce2a17edce61a362d9028faf876df6b5008cc1`，实际复现 30 帧尺寸差异，不是手写模拟旧实现。生产 Catalog 的实际 cell 已与冻结 H5 核对。

证据：`evidence/story-car-size-offline.json`，记录实际生产、源、工具和旧对照身份。

## 受影响回归

搜索所有 `*-offline.json` 中的 Mission 关联。历史目录保留其当时身份，不刷新历史；当前根级 10 份关联报告已按本次生产函数实际重跑，合计 6,664 检查全部 PASS，没有只改 hash。

| 报告前缀 | 实际运行工具 | 检查 |
| --- | --- | ---: |
| story-choice-epilogue | verify-story-choice-epilogue.py | 171 |
| story-choice-presentation | verify-story-choice-presentation.py | 803 |
| story-convoy-targets | verify-story-convoy-targets.py | 128 |
| story-dead-player-park | verify-story-dead-player-park.py | 264 |
| story-death-order | verify-story-death-order.py | 2,572 |
| story-event-order | check-story-event-order.py | 9 |
| story-mission-timers | verify-story-mission-timers.py | 131 |
| story-input-progress | verify-story-input-progress.py | 260 |
| story-objective | verify-story-objective.py | 934 |
| story-result-quote | verify-story-result-quote.py | 1,392 |

## 未验收边界

本批证明函数和交互距离行为对齐，未证明原生模型实际包围盒、当前新包自然 S2–S5 通关、画面、音频可闻效果、性能或手机真机。小车首关已有自然通关证据继续属于其原冻结包。后续合包应在大车接近情报/采集器以及视图替换/重生后验收实际可交互范围；无需为这条尺寸修复重跑完整开场。
