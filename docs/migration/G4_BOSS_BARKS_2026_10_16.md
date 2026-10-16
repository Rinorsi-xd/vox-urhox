# G4 Boss 喊话、字幕接管与单次对白

日期：2026-10-16。固定 H5 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`，源快照 `.tmp/outgame-source-2026-10-15T12-35-57-243Z`。

## 本批交付

生产只修改 `scripts/combat/StoryBoss.lua`。SHA256：`426d76cf94aeef94c0b4490ba721652c2a7bef152f9e3dd7f0e01c696126aaee`。

- `Say(key,urgent)` 与源语义相同，普通对白默认不强制抢断，喊话通过源 14 键 BARKS 自动分类；缺失台词仍静默。
- 规则发来的剧情对白按源调用点显式赋 urgent；开场、队友入场、击倒与大招反馈保留源明确要求的接管。
- `firstRise`、逃生舱与货车默认不强制接管。真实通信卡已验证：firstRise 跟在刚开始的喊话后保留当前字幕，接到后面，修复之前直接清字幕/淡出声源的问题。
- 队友倒下、跺脚命中、横扫命中、地脉命中与源一致，只有第一次成功说出才标记；频道忙而被抑制时不消耗单次机会。
- 空袭 raid 与源一致，首次触发先标记后说，后续空袭不重复对白。
- 保留前批击倒 `storyUntil=0`，不把结尾排到旧战斗队列后面。

没有修改音频生产模块、资源、BossRules 或规则时序。第 5 关原始数据没有配音录音，不新增不存在的配音。

本批发生在冻结 `.tmp/outgame-cached-1792113063203` / 5b8c 之后，必须由主线下一包验收，不能拿 5b8c 的运行表现冒充本批结果。

## 对照与验证

`tools/migration/verify-story-boss-barks.py` 调用 `story-boss-barks-source.mjs`，完整执行冻结 FoxBoss 与生产 Lua；不复制一份期望算法代替源代码。

**754 检查 PASS**：

- 330 个门禁场景：14 个 BARKS 键、普通剧情事件、大招两种真实分支；正在说话与预留时间的严格边界。
- 源台本完全相同；8 个已退役键在真实数据里仍静默，单独标记的合成数据只检查分类集合。
- 56 个真实播放器场景：实际 FoxBoss → NonoComms 与实际 StoryBoss → StoryComms，对比当前字幕、队列与 storyUntil。包括 firstRise、pod、truck、entrance、down、phase2、ultHit；最近一段的 1.5 秒合批宽限内/外，以及剧情频道忙/空闲。
- 4 个 Once 序列：忙时不记账，空闲后可播，之后不重复。
- 4 个真实事件序列：冻结 `_stepAllies / _impact / _sweepHit / _lanesHit` 对生产 `StepAllies / BossRules.Emit → Events`，每类重复三次，验证实际调用也接入 Once。
- 旧 5b8c 实际源码产生 343 个字段/序列差异，负控有效，包含真实通信卡与实际受击事件差异。

回归：击倒交接 **33 检查 PASS**，跪地对白 **1,617 检查 PASS**，战斗流程 **1,090 检查 PASS**。击倒工具按完整候选文件 SHA 固定本批审核状态，原击倒行为断言与历史负控保持不变。

证据：`docs/migration/evidence/story-boss-barks-offline.json`，以及相邻三份 defeat/kneel/combat-flow 报告。测试适配 DOM、渲染、物理与原生音频接口，不证明听感、GPU、自然完整通关或帧时间。

## 全部 Say 调用契约

| Lua 路径 | 冻结 H5 对应 | 本批结果 |
| --- | --- | --- |
| firstKneel | `_kneel:476`，首次 `say(key,true)` | Rules once，显式 urgent=true。 |
| phase2/phase3 | `_phase:501/509`，阶段递增，`say(key,true)` | 显式 urgent=true。 |
| cry | `_hurt:444`，`once(key,true)` | Rules once，显式 urgent=true。 |
| exposed | `_kneel:475`，首次标记，2.6 秒后仍存活/未结算才 `say(key,true)` | urgency 正确；**原有延迟与取消条件差异未修**。 |
| firstRise | `update:853`，`once(key)` | Rules once，默认 urgent=false，实际播放器验证。 |
| ult/ultAgain | `_startUlt:1102`，每次 `say(key,true)` | 显式 urgent=true，允许重复。 |
| crush | `_land:1183`，`say(key,true)` | urgency 正确；Rules 仍 once，当前钻头脚本只安排一次，见剩余边界。 |
| hardShield/slamWarn/lanesWarn/sweepWarn | once，urgent 分别 false/true/true/false | 正确映射；实际台本缺键，两端仍静默。 |
| allyDown | `_stepAllies:634`，`once(key)` | Once，成功才记账，默认 urgent=false。 |
| stompHit | `_impact:919`，`once(key)` | 同上，真实事件重复回归。 |
| sweepHit | `_sweepHit:1039`，`once(key)` | 同上，真实事件重复回归。 |
| lanesHit | `_lanesHit:1077`，`once(key)` | 同上，真实事件重复回归。 |
| ultSafe/ultHit | `_ultBlast:1133`，`say(key,true)`，BARKS | 自动分类、忙时抑制、空闲 urgent=true，不占用剧情时长。 |
| raid | `_startRaid:1231`，先记账再 `say(key,true)` | 同样先记账，显式 urgent=true，全战一次。 |
| entrance | `BOSS_KIND.update:1536`，`talk(lines,false,true)` | 显式 urgent=true。 |
| allies/fightStart | `:1556`，同一次 `talk([...],false,true)` | 同帧连续两次，第一段预留、第二段 append，正常台本队列顺序一致。 |
| down | `:1564`，清 storyUntil，`talk(lines,false,true)` | 保留清零，显式 urgent=true，33 项专项回归。 |
| pod | `:1616`，P.t>1.2、P.said=false，`talk(lines)` | 默认 urgent=false，播放流程已有一次标记。 |
| truck | `:1624`，P.t>7、!talking，`talk(lines)` | 默认 urgent=false，保留原门禁。 |

独立随机跪地池 `KneelLine` 未改，仍按源 `talk([pick],true)` 传 urgent=false、append=false；1,617 项回归通过。

## 明确剩余项

1. exposed 的源 2.6 秒延时及死亡/结算取消条件与 Lua 即时事件仍有差异。本批按主线授权不修改规则时序。
2. crush 源无显式 once，Lua Rules 有 once；当前脚本钻头跳砸只安排一次，自然数据下等价，未来重复安排 drill 时需重新对齐。
3. 真实同构建字幕/声音连续性、整关通关及设备性能仍由主线验收。本批不宣称 G4 全部关闭。
