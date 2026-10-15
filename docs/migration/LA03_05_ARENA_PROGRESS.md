# LA03–05 竞技旧版修复

日期：2026-10-15。接续已有独立旧版审查，不重启G0。状态：生产候选已完成，原生功能已验，统一Web包真实流程及性能未签收。

## 固定身份

- 冻结H5：`2b169a9964645f5f346a7158bcb14447f040814a`，快照 `.tmp/outgame-source-2026-10-14T10-09-50-505Z`。
- 源规则：`shared/battle/match.js`、`three/src/battle/matchSession.js`；后者SHA256为 `7e06e1d264af2f4294a7b8f38aff4647c1a00376f53459f1315f33897c87efc4`。
- 目标当前HEAD：`ad72080b262f93cf87ff464ae2ad72e5b10e2d89`，在已有脏工作区增量修改。
- 当前普通预览 `manifest-11e3cbe9` 不含本次增量，不用旧包结果签收新规则。

## 实施范围

| 项目 | 原差异 | 候选修改与依据 |
| --- | --- | --- |
| LA03复活 | 争夺/推车8秒 | 定向导入冻结MATCH_MODES，均15秒；歼灭不复活保留 |
| LA03规则正文 | 歼灭仍为旧“全灭/血量/回血”三条文案 | 冻结原版home.js合并MATCH_MODES后绘制pvp.rules；HomeBattle改共用ArenaData.modes，正文使用原“拆光/耐久/维修” |
| LA04区域 | 争夺16米、车中心固定高度8米 | 站点22米；共用源inPoint：水平严格小于圈半径+车radius×.5，高度严格小于8+车radius；推车人数与近车回血复用 |
| LA04显示与AI | 圈和AI停靠半径16米 | ObjectiveView按实际point.radius画轮廓/填充/分段，AI目标同22米 |
| LA05维修 | 仅歼灭共享脱战恢复 | 三竞技模式同5秒/15%每秒/.5秒结构恢复；歼灭决胜禁恢复；保留争夺基地叠加及推车攻击方近车2%回血的源执行顺序 |

`Arena.json`只替换`modes`对象并新增`source.modeBaseline`，未把其余预制车/地图数据的来源标签伪改为已验证。定向写入前差异仅歼灭三条文案、争夺/推车两个respawn字段；写入后结构化差异为空。UI/Outgame.json旧副本未覆盖，HomeBattle实际消费已改为共享规则源。

冻结源自身矛盾：`shared/ui/home.js:56`的争夺SUBLINE仍写“8秒复活”，实际`MATCH_MODES`为15秒。本次按忠实复刻保留该原文字，不自行美化为一致。真实HUD倒计时应按15秒规则验收。

脱战与基地共用`entry.repair`计时器，按源先breathe再基地维修，达到阈值清零；不私自改为独立计时器或在离开基地时清零。`RestoreMissing(1)`的具体3%耐久预算由既有CarUnit实现，已用真实零件破坏和武器重绑检查，未将其误译为每次固定长一个物件。

## 自动证据

- `tools/migration/source-arena-unification.mjs`直接导入冻结MATCH_MODES/ShieldQuery，并用VM执行完整matchSession模块后导出原inPoint及三原模式类；未手抄或正则截取原算法。
- 72个圈边界黄金：车radius1/5/20，六种距离、四种高度。
- 36个原模式unitTick黄金：三模式×决胜开关×4.99/5/8秒×家内/家外，比较Heal/Restore调用顺序和共享计时器。
- 原生运行实际CarUnit、Bullet车体、mounted weapon销毁与恢复、14.9/15秒复活及歼灭不复活。
- 首轮 `evidence/arena-unification/native-2026-10-15T09-31-49-236Z`：158/158功能PASS，运行段Lua/resource0；整体FAIL，frame2=195.305ms、frame3=597.041ms，100ms门槛未放宽。保留原始报告。
- 原始stderr另含引擎启动环境的`Cube/Day/DaySpecularHDR.dds`和`themis_x64.dll`告警，不宣称原始日志绝对无告警。
- 扩测 `evidence/arena-unification/native-2026-10-15T09-40-43-224Z`：162/162功能PASS，追加WorldState双队/死亡/圈外/严格高度边界、AI Goal22米及真实ObjectiveView顶点半径均通过。Lua/resource0，整体仍FAIL，两次100ms尖峰为214.179/654.305ms，原报告保留，不作为性能通过。
- 父任务委托代跑未改动的 `verify-reticle-fonts.ps1`：14/14 PASS、Lua/resource/engine0，证据 `evidence/reticle-fonts-2026-10-15T09-41-01-347Z`。这属于原字体增量专项，不等于本Arena或全HUD视觉签收。

## 剩余验收

1. 父任务制作唯一新manifest，记录本专项代码指纹。
2. 新包从真实争夺/推车入口死亡等待，核15秒实际重生和HUD读数；歼灭保持回合内不复活。
3. 小车/T5大车在边缘和高处、双队同时压圈，实际推车/占点与画面22米一致；实际UI模式正文对照原版。
4. 三竞技模式离开基地/车旁后受伤→5秒恢复，决胜禁维修、基地/推车叠加单列核对；新命中中断计时按源。
5. PC及20:9横屏分别留图和真实操作记录；当前原生功能检查不代表移动端持续性能或1:1视觉通过。
