# G5 局内改装文字提交

基线为 H5 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`。本批只修改 `scripts/endless/Edit.lua`，不属于此前 ea91 包验收。

## 已确认的问题与修改

H5 `three/src/battle/endlessEdit.js` 的键盘处理先检查 `isTyping(event)`，车辆名称输入框按 Enter 只提交名称。Lua 改装的 `Update` 在通用建造的焦点保护之前轮询 Enter，且名称提交会清空焦点，同一次按键会导致离开局内改装。

现将事件与轮询共用焦点和弹窗门禁；名称提交保持原回调，并消费本次 Enter，直到松开才能再次出发。主键盘 Enter 与数字键盘 Enter 都按 H5 处理。商店、背包、对话框继续保留输入所有权。

## 验证

- `check-endless-edit-enter.py`：实际执行冻结 JS `keyHandler` 与 `isTyping`，对照生产 Lua 的事件/轮询处理。76 项通过，覆盖两种 Enter、画布/输入框/多行文本/可编辑区域、对话框/背包组合、ClearFocus 后同帧提交、持续按住、松开后再次出发、重复配置以及商店门禁。
- 三个负控均能检出：移除文字焦点检查、移除提交消费标志、移除数字键盘 Enter。
- 原 `check-g5-edit-touch.py` 92 项回归通过。
- 证据：`evidence/endless-edit-enter-offline.json` 与刷新后的 `evidence/g5-edit-touch-offline.json`。

以上使用真实生产 Lua 方法和冻结 JS，UI/原生输入依赖为适配器；尚未据此签收浏览器操作、渲染、自然无尽全流程或性能。
