# 局内 ESC 单一暂停入口

2026-10-16。继续当前迁移，不重开 G0。H5 当前分支实核为 `2026-10-15`，HEAD `b276064942ae09c0227ec28d4cfda1d5ff006455`。

## 用户要求与根因

用户最新要求：ESC 不再先显示一级“点击画面继续”层、第二次才显示设置，应统一一次打开暂停页。原 H5 `three/src/drive/testDrive.js` 的 Escape 在未锁定时退出驾驶；这里明确遵循用户最新统一交互要求，不冒称与该旧交互完全相同。

迁移版 `TrialSession:Escape()` 原先在 captured 时只执行 Pause，并在竞技模式显示 PAUSED banner；未 captured 时才打开 GameSettings。因此两次 ESC 是明确的代码路径。Web 还可能由浏览器消费 Escape，仅通过 `input.mouseLocked=false` 告知游戏，导致根本没有 KeyPress。

## 生产改动

只改 `scripts/app/TrialSession.lua` 与 `scripts/ui/GameSettings.lua`，保留已有 require 提取和其他未提交改动。

- 首次 ESC 立即打开现有统一 PauseMenu，直接有继续、返回车库、画面、声音等入口。
- 暂停页再按 ESC 关闭并调用既有 Resume；子设置/帮助/退出确认页 ESC 回统一暂停页。
- 新 PollPointer 调用真实 DrivePointer.Poll，捕获 captured/pending 到释放的边沿；Web 只丢锁而无 KeyPress 时，同样打开暂停页。
- 拒绝/超时的 Web 恢复捕获返回可操作暂停页；正常异步捕获仍等待引擎真实锁定标记。
- GameSettings 重复打开保留当前模态对象，避免同一个入口重复建页。
- ESC 消费当帧输入，避免同帧 T/其他玩法快捷键穿透新开的菜单。
- 保留战斗退出失败确认、搜撤提交/返回门槛、结算/MVP/片尾专有输入、源解锁时的中立世界模拟。此项没有更改物理、剧情计时或世界暂停策略。

## 实际离线验证

执行：`C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe tools/migration/verify-unified-pause-input.py`。

实际 Lua 5.4 执行完整生产 TrialSession.Update、PollKeys、HandleKey、Escape、PollPointer，完整 DrivePointer 的注册鼠标事件回调/捕获/释放，以及真实 GameSettings、PauseMenu、DialogHost、MatchActions。原生设备、控件绘制与物理 Tick 使用明确 CPU 适配器。

**204 检查 PASS**：竞技、剧情、训练、无尽、打捞 × Native/Web 共十场景，另加锁拒绝/迟到捕获、触屏子设置和恢复。覆盖实际按下开火→ESC清除 held fire、首次菜单、同帧 ESC+T、连续开关、子页返回、菜单按钮回调、Web 仅丢锁、恢复锁定、退出确认。

固定提交 `48ef15f2c9c95c400f91ee6e34309399d02b3733:scripts/app/TrialSession.lua` 作为实际旧代码负控，在首个 `first Escape opens unified menu: battle` 断言失败，确实检出了旧二级行为。不是根据静态字符串猜测。

证据及全部绑定 SHA：`docs/migration/evidence/unified-pause-input-offline.json`。

同时更新原 `tools/migration/check-game-settings.lua` 的三处旧二级 ESC 预期，以便统一 Runtime 接力检验。此轮没有运行该 GPU 检查。

## 待统一构建验收

本轮未启动 Runtime/浏览器 GPU，未构建、提交、推送。离线验证不等于真实浏览器的 pointer-lock 授权、布局/声音或骁龙845持续性能通过。root 下一统一包需实按 ESC、恢复、子设置返回，特别检查浏览器消费 ESC 的顺序；4453旧包不包含这些修改。聚焦此次入口缺陷，不借此关闭完整 G4。
