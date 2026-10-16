# G4 剧情选项确认呈现迁移

基线固定为 H5 分支 `2026-10-15`、提交 `b276064942ae09c0227ec28d4cfda1d5ff006455`，冻结源目录由 `docs/migration/outgame-baseline.json` 指向。此批没有改规则时序、建造、Web 测试服务或上传。

## 缺口

原 `shared/ui/storyHud.js` 的 `choice()` 在选中后立即锁定 `_pick`，保留选中行 500 ms，再移除 `on` 类；`.sh-choice` CSS 使用 opacity 0.2 s 和 translateX 0.3 s 退出，均无延迟。原选项条进入同一 CSS 动画，选中行使用 `var(--sa)` 实色高亮。迁移版之前按 `rules.choice ~= nil` 直接显示，选择后的下一帧即消失，缺少锁定、picked 状态、进退动画和动态提示宽度。

## 生产改动

- `scripts/ui/MissionChoiceState.lua`：以系统墙钟独立维护 choice 的进入、500 ms 选中确认、取消和 CSS 延迟退出。暂停、死亡和物理时间不会冻结展示。
- `scripts/ui/MissionChoice.lua`：动态按选项/提示文本计算宽度；复刻切角、渐变、边框、键位框、hover 位移、picked 实色和文本字距；回调在逻辑 choice 仍对应时才提交，重复点击不会重复回复。
- `scripts/story/MissionRules.lua`：仅扩展既有 `choice`/`radio` 事件 payload，携带原 choice 和 1-based index；`flags` 仍保存原 0-based 值，回复和音频顺序不变。
- `scripts/story/Mission.lua`：窄接线到 choice 事件、pickup 事件、目标切换、完成和释放；失败事件仍保留原版不立即取消选择的语义。

## 验收

`tools/migration/verify-story-choice-presentation.py` 实跑 **803 checks / 68 samples / 9 cases PASS**，包括原冻结 StoryHud 完整 choice/pick/cancel 类、逐采样 CSS opacity/transform 与生产 `MissionChoiceState` 对照，以及真实 `MissionRules`/`Mission.Events` 同一 Drain 的自动默认选择、重复选择、目标切换、失败和 Dispose 场景。额外执行真实 `MissionChoice.Attach`、回调与自定义 Render，检查两项布局、最小自然宽、选项数量、选中暗色文字/字距、仅一次 Resume、退出时关闭输入与最终隐藏。

证据：`docs/migration/evidence/story-choice-presentation-offline.json`。

边界：未声称自然完整剧情、真实浏览器渲染、原生 VG 像素级或真机性能通过；这些仍按 G4/G6 另行验收。

## 本轮纠正记录

最初 CSS 检查未限定 `.sh-choice` 块，误匹配其他控件的 0.5/0.7 s 延迟动画；同时多 case 夹具没有重置时钟，造成后续 case 的数值不一致。旧 597 检查结果只覆盖语义，不能用于签收动画。现已限定精确 selector 块校验，逐 case 重置时钟，恢复每个样本的 opacity/transform 数值断言，并重新执行生成上面的 803 检查证据。未手工改写 SHA。上述旧结果作废，不声称浏览器真实 CSS 渲染已验收。
