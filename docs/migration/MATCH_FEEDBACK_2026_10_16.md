# 竞技准备与受击反馈补齐

源基线：`2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`，冻结`shared/ui/matchHud.js`与`three/src/battle/matchSession.js`。

实际漏迁三项：原`mh-count`准备阶段最后3秒倒数、`hurt()`受击边缘闪烁、底部`mh-regen.sd`决胜维修失效提示。共享准星已有方向受击与低血效果，不能代替这三项。

`ui/MatchFeedback.lua`由现有MatchHud共享UI帧绘制，不新建VG上下文或后处理目标。倒数按准备剩余时间取ceil，仅显示1到3，数字改变重启动画；真实session.intro未完成时隐藏。受击由实际DriveOverlay消费的玩家正伤害事件触发，350ms节流、两个更新帧后开始500ms CSS ease淡出，零伤害/他人受击/回血不触发。只有歼灭战存活玩家、live、sudden同时成立才显示维修失效。

`verify-match-feedback.py`执行冻结JS实际`MatchHud.update/hurt`，与生产Lua跨三个模式、prep/live/over、intro、存活和9个时间点比较；另检验实际DriveOverlay事件接线、350ms边界及半秒淡出。666项通过，生产脚本SHA记录于`evidence/match-feedback-offline.json`。

未完成边界：新包Web真实倒数、自然受击截图尚待验证。红色边缘使用四向VG渐变近似CSS inset box-shadow，不能称已像素一致。严重战斗性能、重复入陨坑OOM不因本检查通过而关闭。没有提交或上传。

后续41e4025e实际Web：`evidence/combat-performance-2026-10-15T16-33-58-904Z` 已通过公开匹配、跳过实际介绍后等待自然准备计时至3，保留 `match-countdown.png` 与只读状态，root已查看实际数字3。观战图可见QA核心受击后的边缘效果，但不签自然受击时序/像素一致；决胜提示自然路径仍待验。三次实际进场成功只适用于该次复现，性能FAIL保留。
