# G5 商人数量选择与仓库检视售卖

## 基线和交付边界

- 原版固定 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`，快照 `.tmp/outgame-source-2026-10-15T12-35-57-243Z`。
- 执行前实际核验 `salvageHub.js`、`stash.js`、`salvage.css`、`new-ui-salvage.css` 对应冻结清单 SHA，再执行原版 `_bindStepper`、`_trade`、`_inspect` 和真实 Stash 交易方法。
- 本批不是旧 `manifest-8b6203a3` 的运行结果。没有构建、GPU、提交或推送；主线统一合包后才有 Web 验收入口。

## 实际补齐

| 验收项 | 原缺口与本批行为 | CPU 证据 |
| --- | --- | --- |
| NQ01 数值直接输入 | 原数值为无操作按钮；现在使用真实引擎 TextField，失焦按原 parseInt/默认1/上下限提交，非法值归1 | 空串、字母、零、负数、带空白/后缀、小数、科学记号、十六进制前缀和超长数字与实际 JS 对照 |
| NQ02 滚轮 | 原整张交易面板接管滚轮；现在只在数量输入框调整，方向与原版一致 | 双向、上限、下限、最大值实际事件检查 |
| NQ03 长按 | 原只有单击加减；现在按下立即一步，400ms 后每70ms继续，第13次重复起每次5个 | 实际原版 setTimeout/监听器执行，与 Lua 指针/墙钟更新序列对照，包含迟到帧不突发补跑 |
| NQ04 输入所有权 | Enter 提交输入并清焦，同帧不能触发购买/出发；释放、取消、失焦、弹窗、销毁均停止重复 | Page.Key、字段清焦、迟到回调和按钮事件实际执行；销毁主动清除自身字段焦点 |
| L05 仓库检视售卖 | 原检视只有展示；现在数量选择、最大、关闭、卖给后勤处可用，明确执行 sell，不受商人上次 buy 模式影响 | 真实 Page.Create 构造、售卖回调到 Lobby.Trade，保留装车件，失败写入回滚检查 |
| L05 仓库快捷操作 | 原选中格不能反选，右键缺卖1；现在再次点击关闭检视，右键按源售卖一件 | 实际格子 OnClick/OnPointerDown 到真实交易 |
| L05 交易反馈 | 成功恢复原文数量提示、place/remove 声音和 qty=1；失败保留数量 | 真实原版 _trade 与 Lua Trade 的库存、余额、文案、声音、重置一一对照 |
| L05 检视信息 | 补散件、车上数量、占格/每格数量、收购价和当前售卖总额；商人仓库数使用 loose | 原版 _inspect 输出事实与实际 Lua Render 输出逐项对照 |

数量变化原位更新 TextField 和交易按钮禁用态，价格由现有 Render 读取当前 qty；不因每次重复步进销毁整页或重新加载预览。

## 实际执行

- `check-salvage-quantity.py`：**184 检查 / 23 个实际原版场景 / 6 个负对照 PASS**。
- 负对照全部拒绝：删长按、删加速、忽略输入、反转滚轮、检视误购买、真实 `48ef15f2` 旧 Page。
- 关联最终代码回归：loadout feedback **1401 / 223源场景 / 4负控**、departure **74 / 7负控**、hangar cue **38 / 3负控**、action buttons **1353 / 550矩阵场景**，均实跑 PASS。
- 独立子线只读核查真实引擎 `UI.lua` 的 pressedWidget Up/Cancel 分派、递归 Update、TextField清焦、GarageHud同帧键盘轮询与显式售卖参数，未发现本范围可证实的新问题。
- `git diff --check` 本批文件通过。
- 证据 `evidence/salvage-quantity-offline.json` 记录源、生产、资源、检查器 SHA 及负控。未手工改哈希签收。

## 生产文件

| 文件 | SHA256 |
| --- | --- |
| `scripts/ui/SalvageQuantity.lua` | `5582a5c1096700ea3e8221045bc465b09af5d6f96a28ddccc39a057ed9deb0de` |
| `scripts/ui/SalvagePage.lua` | `218946b1bb6486b950aeaca41cb46366e79f4fd668b7e5f24a2a6e81b67ad3f2` |
| `scripts/ui/SalvagePaint.lua` | `0b2f10cdb97a9dceb0a2a193dadc8df4bb76dd5c16b92b58336e19f687356306` |

新增 Quantity 的 `.meta` 一并交付。未修改 SalvageLobby/StashRules 数据层、TrialSession、render 或工具 registry。

## 保留待验与范围

- UI/native TextField宿主、墙钟、绘制、键盘轮询和文件保存使用适配器；真实浏览器/触屏键盘、各横屏比例的检视排版与可见摇动、音效试听仍待主线同包验收，不能称完整像素1:1。
- 本批没有完成商人一键卖全部货物、全仓库分类数字、完整悬浮提示和原钱包金额弹跳；没有把这些写成已完成。
- 原版 toast 的 z-index860 高于无尽 HUD80，自身存在短暂遮横幅；本批不擅自改变原层级。死亡/复活旧证据仍保留自然路线验收边界，没有用新数量测试冒充战斗验收。
- 账号资产、自然完整搜撤/无尽波次和真机性能不是本批功能证据。

## Web 实测后的滚轮补正

主线 `manifest-f9b98d5f` 的首次实际 Web 路线通过21检查后，在移出数字框滚轮处失败，运行与HTTP错误均0，未执行出售。原证据保留在 `evidence/salvage-quantity-web-manifest-f9b98d5f-2026-10-16T09-24-47-762Z/`。实际鼠标已命中“出售”，引擎打包版 `UI.HandleWheel` 却先给旧hover字段派发，再刷新hover。

只在 `SalvageQuantity.lua` 补局部适配：活跃数量Row期间，共享单层包装在当前命中或旧hover属于数量框时调用公开 `UI.HandleMouseMove` 刷新，再交原派发；字段额外拒绝外部与零滚轮。最后Row销毁还原原处理器，模块重入不叠包装，无每帧轮询。引擎库、Page和Paint未改。

当前 Quantity SHA更新为 `f18b2abaa6b6e350a42ef6e125e291bbd5131bbf935b5428a2902014dfa63147`。离线检查实际执行未改写的打包 `UI.HandleWheel`，**200检查 / 23源场景 / 7负控 PASS**，新增内→外、外→内第一下、多个字段、转ScrollView、普通滚动不变、销毁还原及模块重入。新包 Web 重测仍待主线执行；完整说明在 `G5_QUANTITY_WEB_ACCEPTANCE_2026_10_16.md`。
