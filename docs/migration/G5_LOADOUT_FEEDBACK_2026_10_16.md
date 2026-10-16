# G5 整备库存缺口与数量反馈

本批接续 L01，基线固定 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`。开始前读取 CURRENT_EXECUTION、G5_ACCEPTANCE_LEDGER、UI 文档及库存/虚拟列表/控件三示例，不重开 G0。

## 实际变化

生产只修改 `scripts/ui/SalvagePage.lua`、`scripts/ui/SalvageItem.lua`，不动 SalvageLobby、StashRules、存档、经济规则、地图、加载宿主。

| 可逐条验收的项目 | 现在行为 | 源依据 |
| --- | --- | --- |
| 已装武器/移动/功能零件缺库存 | 对缺口中该种物品画 2px 内侧 `#ff3b30` 红边，不把格内装配数量改成缺量 | salvageHub.renderLoadout 的 short[id]，最终 new-ui-salvage.css 的 .sv-tile.bad |
| 多车共用库存 | 使用整个打捞车库的 Usage/Shortfall，其他车占用造成的缺口也正确标记 | SalvageStash.shortfall 与 Shell 注入 usage；不改已有数据层 |
| 数量角标 | 0/1 不显示，大于1显示 ×n，10000及以上显示源一位小数万单位，保留源 JS toFixed 中点舍入 | SalvageHub._tile；含 1.15/1.25 等二进制舍入边界 |
| 装备分区空槽 | 武器/移动至少4槽，功能仅有实际物品，不再额外补4个功能空槽 | renderLoadout slots(function,0) |
| 带入道具刷新 | 散件数降至0时移出带入列表，计数更新；数量仍是实际 loose，不是总拥有量 | SalvageHub.render 的 gear.filter(stash.count>0) |
| 道具弹出菜单 | 显示源 `仓库里 n 个 · 描述`，无散件禁用；即使绕过控件回调也不能把0库存道具加进去 | SalvageHub._gearPop |

红边不是覆盖所有物品的全局红框，仅当前已装的、且该物品在真实 shortfall 中有缺口的格子显示。结构件仍不在源整备的三类装备格中，可能出现出发按钮提示结构缺口但没有对应装备格，这是原版分类，未新增假的结构栏目。

## 执行证据

`tools/migration/check-salvage-loadout-feedback.py` 实际执行冻结 H5 `SalvageHub.render/renderLoadout/_tile`、`SalvageStash.count/shortfall`，执行前校验全部源 JS/CSS 的 SHA256。导入的物品分类由当前导出 Outgame.json 提供，图标/提示 HTML/DOM 是受控边界；不声称源全部导入模块已经运行。

- **1401 检查、223 个源场景通过**：6 种整备场景与217个数量边界，含正常、武器缺口、其他车占用、道具归零、无功能件、多功能件，以及万单位进位和最大安全整数。
- **4 个负控均拒绝**：真实 `48ef15f2` 旧 Item、移除红边、Page 不传缺口、菜单误用总拥有量。
- 实际 Lua `SalvagePage.Create` 生成的控件数量、库存标记、禁用状态、文案与源输出比较；实际 `SalvageItem.Render` 的文本、字号和四边颜色/厚度执行记录比较。
- 关联实际重跑：salvage-departure **74 检查/7负控**，hangar-cue-hooks **38 检查/3负控**。当前测试配置路径以当次执行结果为准，不沿用过去178的数量。
- 生产 SHA256：Page `cc9ddb33b1cc23499ae50f24128eec189aa1a09d3b2fc9ba220c687a906e8b5c`，Item `629f6ae825220ae317e4decd06f8acf3fe2fa131ac98c6b75c325a8b83cc2f6b`。

证据 `docs/migration/evidence/salvage-loadout-feedback-offline.json`。本批没有 GPU、提交或推送。浏览器真实红边、字体实际落图、横屏触摸与真机性能待统一新包，不能借2797旧包签收。

## 同页仍未关闭

完整富文本悬停卡（装在车上/数量/占用等）、仓库分类数量、商人数量直接输入/长按加速、仓库详情的源出售操作与局部动效尚未由本批补齐。数字只补了基础黑影，源 CSS 的模糊阴影/hover 像素观感仍未签收。不能把本批解释成打捞整个 UI 已1:1完成，也不关闭自然成功撤离、真实旧账号经济或云恢复。
