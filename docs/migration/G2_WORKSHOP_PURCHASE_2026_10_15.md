# G2 工坊购买链冻结记录

基线：H5 分支 `2026-10-15`，提交 `b276064942ae09c0227ec28d4cfda1d5ff006455`；冻结目录、逐文件 SHA 见 `outgame-baseline.json`。本批只闭合打捞局外工坊购买链，不表示 G2 全部通过。

## 确认并修复的旧版遗漏

- 打捞创意工坊此前复用了普通创作工坊，没有整车价格、钱包、缺钱状态、价格排序和购买语义。现按冻结源 `shared/ui/workshop.js`、`salvageHub.js` 及对应 CSS 接入。
- 余额不足仍能打开确认，保留原版“用仓库里的零件拼，只付差价”的选择；竞技创作模式保留原有导入和分享功能。
- 真正执行 rat 购买时发现派生 `Outgame.items` 只有 327 项，缺 manta、rat、roach 共 20 件外壳，`SalvageBuy.Rows` 因缺 item 直接崩溃。冻结源 `items.js` 明确登记所有非 core 零件，故重导完整 347 项，而非跳过缺失零件或替换车型。
- `SalvageRules` 仍为更旧的 265 项；同步源 `stackMax`、物品顺序及市场排序后也是 347 项。
- 独立 G4 审查实际复现：精选页异步请求 fox 后打开 scorpion 详情，迟到 fox 会把标题、购买对象改成 fox，3D 预览仍是 scorpion。现离开精选页先取消其图片 gate，迟到结果不能串入详情；源 H5 本来分别保存 heroI/detailId。

## 生产文件

- `scripts/ui/Workshop.lua`：购买展示、钱包变化更新、详情价格、价格排序入口。
- `scripts/ui/WorkshopCard.lua`、`WorkshopButton.lua`：价格标记和购买按钮。
- `scripts/ui/WorkshopShop.lua`、`WorkshopShopPaint.lua`：源经济适配和绘制；钱包未变化不逐帧分配状态表，价格由 Catalog 预制行计算并缓存。
- `scripts/ui/GarageHud.lua`：空白底盘真实领取入口成功回调按 lobby 分流，打捞返回打捞车库，竞技仍进入建造；保留现有初始化失败清理 wrapper。
- `assets/UI/Outgame.json`：仅 items 字段按冻结源重导。
- `assets/UI/SalvageRules.json`：按冻结源 items/stash 规则重导。

现有 `SalvageBuy.lua` 没有改动，正确元数据已解除其 nil 崩溃。

## 检查与复现

10/16实际Web补充：固定592c0077包，最终`workshop-shop-web-manifest-592c0077-2026-10-15T16-10-30-580Z`共33项PASS、运行错误0。真实公开按钮打开rat/roach/miniAssault/miniScout/miniHeavy详情及确认、核对冻结源价格与余额、逐车取消不改库存车位；实际以8000余额购买roach3852，余额4148、车位1→2并回打捞garage。五张dialog与购买后garage截图已检查。仅此次新建浏览器本地会话，无真实账号/云恢复/手机验收。此包不含后续空底盘入口导航和精选/详情独立状态修复；后两项需新包。16:06旧轮15项后FAIL为工具误把背景go购买按钮当modal primary判断，修工具限定kind后重跑，旧证据保留。

运行 `node tools/migration/workshop-source-items.mjs --write` 可重导派生资源；该工具先检查冻结源 SHA，再直接加载源模块，没有手抄定价公式。市场中文排序使用 Node 的 zh localeCompare，浏览器最终顺序仍需统一构建目检。

常规入口 `capture-outgame-source.cjs` 写 Outgame 后强制调用此黄金导出；原有 `export-salvage-rules.cjs` 也转调同一导出，不再维护第二份规则生成实现。`sync-story-page-data.cjs` 只替换剧情字段，保留 items。这样下次常规重导不会静默恢复旧物品表。

运行 `tools/migration/verify-workshop-shop-offline.py`：使用真实 Lua 5.4，实际执行 Workshop 页面、卡片、按钮、SalvageBuy、StashRules、SalvageLobby；引擎 UI/渲染和存储仅用内存替身。输出 `evidence/workshop-shop-offline.json`，含生产文件和资源 SHA。

- 对照源 JS 的 19 个车型价格、35 组筛选/排序、76 个钱包状态。
- 19 个真实 Catalog 预制车型逐车打开确认并执行购买，含 rat、roach、miniAssault、miniScout、miniHeavy；精确余额成功，差 1 信用点禁用整车购买。
- 仓库已有完整零件时零余额拼车；创建失败恢复购买前信用点与物品；空底盘零余额购买。
- 页面 feature/detail/browse、Enter、钱包更新、普通创作导入/分享保持连通。
- 所有 347 件物品元数据和全部 stash 规则逐字段与冻结源相等。

本批最终离线检查 **448 项 PASS**。`audit-workshop-pending-detail.py` 另外执行真实 Workshop/Carousel 的迟到回调检查，修复后 `NO_BUG`：selected、displayedDetails、preview、purchased 均为 scorpion；详情不再被迟到 fox 替换。记录在 `evidence/workshop-pending-detail-audit.json`。

### 空底盘真实入口追加验收

上面 448 项中的空底盘只覆盖 `SalvageBuy.Car(empty)` 的零价模块事务，不是实际页面入口。源 H5 `workshop.js:125/198` → `salvageHub.js:182` → `shell.js:174` 的 `onBuyPrefab` 在 empty 时直接 place，无确认框；place 成功转 `salvageTab('garage')`，不自动进编辑。

目标此前 `GarageHud.s.CreateVehicle` 正确绕过购买框，但成功后误走竞技模式 `SetTab('hangar') + EnterBuild()`。现仅修该回调的导航分支，不改变打捞车位存储。

新增 `verify-garage-acquire-entry-offline.py` 从真实 `GarageHud.Create` 创建状态，执行实际安装的 `s.CreateVehicle / s.Run / s.SetTab`；非空 rat 调用真实 `SalvageBuy.Car`。**9 项 PASS**：打捞 empty 免费无确认、不进编辑并回打捞 garage；竞技 empty 仍进编辑；非空仍需购买确认；创建失败不触发成功导航。引擎 UI、资源依赖查询、换车动画和存储仍为替身。证据 `evidence/garage-acquire-entry-offline.json` 含当前 GarageHud SHA；不等同 Web 原生验收。

**边界：离线检查通过不是原生/Web/真实账号或视觉验收。** 本批没有启动浏览器、没有部署、没有提交 Git。统一新包还需实际打开打捞工坊，操作鼠型/蟑螂与新三车购买、库存抵扣和回车库，并核对价格标签与购买按钮视觉。
