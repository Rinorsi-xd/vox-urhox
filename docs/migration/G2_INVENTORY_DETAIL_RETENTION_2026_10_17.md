# G2 零件库详情切换保留滚动

状态：`LOCAL_IMPLEMENTED / OFFLINE_PASS / WEB_SCOPE_PASS`。接续既有 G2，不重启 G0，不涉及性能候选或 G5 已验收事项。

## 同包真实Web补验（2026-10-17）

普通4582的`.tmp/outgame-cached-1792204236638` / manifest `2a9723f0`已包含两份上述SHA生产模块。PC1600x900在`evidence/inventory-detail-retention-web-1792204315440/report.json`的PC用例5检查通过；该报告整体FAIL来自随后Android测试输入错误，不把整体改成PASS。Android840x378/DPR3最终`evidence/inventory-detail-retention-web-1792204967824/report.json`五检查PASS/CLOSED，运行及HTTP错误0，实际触摸展开/拖动后切换零件，before/after偏移均为120.438514；短内容范围及关闭backdrop亦通过。root实看PC和20:9切换后截图。

保留两次失败：首轮在touch环境发mouse.wheel未滚动，expanded超时；第二轮已用真实CDP触摸，但在惯性从116.256自然滑到118.774之前记录比较基准，误报切换不保留。实际选择前后稳定值相同。最终只在测试工具增加有限新状态稳定等待（连续3次），保留原<=1px断言，不修改生产滚动或回调来通过测试。性能面板覆盖部分右侧内容仍可见，本项仅签滚动行为，不签全页视觉、自然全触控流程或手机性能。

## 来源和实际缺口

- 冻结 H5：`2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`，按 `outgame-baseline.json` 校验实际源 SHA。
- `shared/ui/inventory.js` 的完整 `_detail(type)` 替换同一详情 aside 的内容，没有重设 scrollTop；既有实际 Web 报告也记录切换后的源滚动值 287/234，迁移版回到顶部。见 `G2_INVENTORY_LAYOUT_2026_10_15.md` 的截图状态边界第 4 项。
- 实际 Lua `InventoryPanel:Detail` 每次切换零件后调用 `detailScroll:ScrollToTop()`。这是用户指向、点击、键盘聚焦零件时反复回顶部的直接原因。
- 完整引擎 `ScrollView` 在 `bounces=false` 且静止时不会因内容缩短自动夹回合法范围。因此单删 ScrollToTop 会留下超出新内容的空白；本批同时补局部详情子类的范围处理。

## 生产改动

1. `scripts/ui/InventoryPanel.lua`：有效零件切换保留当前详情滚动位置，继续使用真实 `InventoryDetail:SetPart`、原行内容和展开状态。
2. `scripts/ui/InventoryDetailScroll.lua`：完整基类测量和原尾部 padding 之后，仅在当前位置越界时夹回新范围。有效位置不发滚动事件；连续帧不重复通知；临时 NaN/零高 Yoga 视口不清空位置。内容缩短和收起参数均走这条原消费者路径。

冻结 SHA256：

| 文件 | SHA256 |
| --- | --- |
| InventoryPanel.lua | `93d9fd3909e619ea05d2469fd1edafb2f501b688856e924c1b3251e8e1feb740` |
| InventoryDetailScroll.lua | `adea7d6fc724b248eab4325a066d0df854e860db26eae30331e3e3fa7656305a` |

## 离线实际消费者证据

- `source-inventory-scroll-golden.cjs` 执行冻结完整 `_detail`，覆盖 3 零件 × 3 偏移 × 展开/收起，共 18 场景。源文件先校验 SHA，零件/武器行来自既有冻结源生成器，资源差异为空。DOM 输出为适配器，没有模拟浏览器布局。
- `check-inventory-detail-retention.py` 加载实际 `InventoryPanel:Detail`、`InventoryDetail:SetPart`、`InventoryDetailRows`、`WeaponDefs` 与完整引擎 `ScrollView` 和实际局部子类。资源读取从真实资产 JSON 适配，视口/子项矩形为明确夹具。
- 旧生产：94 检查，32 失败，原样存为 `evidence/inventory-detail-retention-before.json`。
- 修改后：120 检查 PASS，3 负控分别拒绝强制回顶、缺失缩短夹回、绕过真实详情消费者；覆盖稳定位置不重复通知及临时视口。`evidence/inventory-detail-retention-offline.json`。
- 受影响回归：滚动范围 139 PASS、排版 108 PASS、331 零件详情 5867 PASS，`resourceDrift=[]`。旧滚动工具原先只认内联 require，遇到既有 hoist 后在断言处失败；现仅改为核对顶层依赖及实际构造表达式，原范围/恢复断言保留。
- Node 语法检查和限定文件 `git diff --check` 通过。没有本 agent 的 Native/Web/GPU 执行，没有 Git 提交或上传。

## 同构建公开入口验收

工具：`tools/migration/check-inventory-detail-retention-web.cjs`。root 在自己的串行硬件窗口选取新冻结统一包与既有只读 outgame QA observer 后运行；不修改共享 probe，不注入蓝图、滚动状态或点击回调。

```powershell
$env:VOX_PREPARE_FILE = '<新冻结包的 identity.json 或 prepare.json>'
$env:VOX_QA_BASE = 'http://127.0.0.1:<QA端口>'
node tools/migration/check-inventory-detail-retention-web.cjs --self-test
node tools/migration/check-inventory-detail-retention-web.cjs
```

工具核对当前/冻结三模块与服务 identity，PC 1600×900 和 Android UA 840×378 DPR3 分别：公开 E/B 进零件库、搜索并选天元钻头、展开并实际滚动、再搜夫元钻头保留位置、滚到底改选轻方块检查范围、关闭并检查 backdrop 释放。每步存现有只读状态及截图，错误/HTTP失败不豁免；退出浏览器并保存 shutdown。

边界：最初本节写于工具未运行时；当前窄范围真实结果见顶部补验。20:9已用真实触摸拖动，但搜索仍有外接键盘输入，不是自然纯触屏体验或真实手机验收。此项不是字形/光效/全G2 1:1、性能提升或骁龙845持续30FPS的证据。
