# 帮助页滚轮根回退修复

日期：2026-10-15。状态：原生29/29通过；统一561eef79包真实PC浏览器向下滚动通过，字体全状态及其他比例验收分开记录。

## 真实问题与证据

- 旧普通包11e3cbe9的真实浏览器滚轮没有滚动帮助页，记录于 `evidence/target-font-pages-manifest-11e3cbe9-2026-10-15T09-41-30-234Z`。保留原FAIL，未重写为通过。
- 父任务已实录鼠标960,540、wheel事件到引擎，但`UI.HandleWheel`的hovered=nil，trace chain为空。库随后只查root.OnWheel及root直接children；帮助弹窗在独立overlay栈，不在root子树，已有modal.OnWheel收不到fallback。
- 上一轮原生直接调用modal.OnWheel只能证明ScrollView可滚，不能证明真实UI事件能找到弹窗。

## 生产改动

- `scripts/ui/SourceHelp.lua`通过DialogHost现有onClose/onDispose接入解绑，保留已有modal.OnWheel正常命中通道。
- 新 `scripts/ui/HelpWheelBridge.lua`仅在帮助打开期间安装root.OnWheel。需同时满足root未切换、帮助为UI.GetTopOverlay、owner.dialog仍属该帮助、isOpen且未销毁才转发ScrollView。
- 无帮助或被其他overlay覆盖时调用原root handler，保留self及dx/dy。库的OnWheel找到第一个处理器即停止，正常ScrollView/modal命中不会再经过root，避免双滚。
- Close/Dispose幂等清除桥接并释放root/owner/modal/scroll引用；若后来有外部handler覆盖root.OnWheel，不擅自覆盖它。保留的退休桥只转给旧handler；不同owner帮助乱序关闭时跳过已释放桥，最终恢复原handler或nil。
- 未改urhox-libs，未添加每帧input轮询或第二次滚轮消费。

## 验证

扩展原 `check-source-help.lua`，保留48条原帮助内容、90%卡高、上下GPU截图、所有行和页脚可达等检查，新增UI.HandleWheel/no-hover根回退与生命周期覆盖。

- 首轮 `evidence/source-help-2026-10-15T09-46-56-650Z`：23/29，Lua/resource/engine0，功能FAIL保留。原因是夹具移鼠到屏外仍会命中全屏SourceModal，未造出真实问题中的hovered=nil；不是生产错误已关闭的证据。
- 仅改夹具使用公开UI.HandlePointerCancel清hover，保留原生产和所有断言。最终 `evidence/source-help-2026-10-15T09-47-47-374Z`：**29/29 PASS、Lua/resource/engine0**，100ms门槛未改。
- 验证实际公开UI.HandleWheel到ScrollView只一次、被覆盖时不滚、Close/Dispose及重复销毁、原handler身份/self/delta、原先nil、root更换、外部后来handler、嵌套帮助乱序关闭。
- 已查看最终原生底部GPU截图 `evidence/source-help-native-bottom.png`，最后长条目与关闭页脚可见；本次未调整字体或版式，不签全页面1:1。
- UI.HandlePointerCancel是原生夹具构造no-hover状态；这不是操作系统真实wheel，也不替代下一包真实浏览器鼠标移动/wheel/关闭后滚动恢复验收。

## 下一步

2026-10-15 17:50，统一 `manifest-561eef79`、QA4305实际PC1920×1080：从帮助按钮进入，真实 `page.mouse.wheel(0,1600)` 到引擎 dy=-1600，trace chain仍为空，scrollY **0→433.5**。上下截图已收、末尾J条目及关闭页脚可见，随后Esc关闭、实际设置/工坊入口均可继续；运行错误0。root已打开 `pc-help-bottom.png`。证据 `evidence/target-font-pages-manifest-561eef79-2026-10-15T09-49-07-610Z`，不再拿native直接调用代替此真实路由。

PC反向滚动、关闭重开、被其他弹窗遮盖及20:9的实际路线仍未在此Web脚本重验；原生生命周期覆盖不能替代全部真实输入。字体完整1:1和性能不随本缺口通过而关闭。旧11e3真实失败保留。
