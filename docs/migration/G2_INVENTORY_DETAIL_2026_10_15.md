# G2 装配终端详情与数字字体

## 接续基线

- 从 `CURRENT_EXECUTION.md` 与 `G1_FONTS_PROGRESS.md` 接续；不重新开始 G0。
- 原 H5 分支 `2026-10-15`，提交 `b276064942ae09c0227ec28d4cfda1d5ff006455`。
- 冻结源 `.tmp/outgame-source-2026-10-15T12-35-57-243Z`，由 `outgame-baseline.json` 校验读取的四份源码 SHA。
- 本次只修改 `scripts/ui/InventoryDetail.lua`，新增独立的 `InventoryDetailRows.lua`；未改字体资源、公共绘图、页面排版、H5 或只读引擎库。

## 确认并补回的旧版残留

1. 源 `shared/ui/inventory.js` 的 `_detail` 对钻头已有独立分支；目标仍把钻头显示为普通射击武器的火力、单把秒伤、每发耗能。现逐行迁入天元钻头的全段基础伤害、六段数、蓄力/冷却、突进、每次耗能、持续钻削、蓄力/释放耗能、维持耗能，以及夫元钻头的独立伤害和彩蛋说明。文字、图标、顺序、条件来自冻结源，没有添加说明。
2. 源 `new-ui-inventory.css:140` 的主数值明确使用 `VoxNum` 与 `tabular-nums`。目标使用比例数字 `vox-display`，现改成已有的 `vox-tabular`；免费仍使用原正文。没有更换字体或伪加粗。
3. 审查发现武器导出数据仍为旧基线，狙击满伤 600 而冻结源为 800，已报 root。root 本轮独立重导武器资源；本检查最后重跑时所有详情内容已与冻结源武器计算一致。该资产由 root 修改，本任务没有重导或覆盖它。

## 离线证据

- `source-inventory-detail-golden.cjs` 执行实际冻结 `_detail` 中生成参数行的语句，以及冻结 `weaponStats` / `weaponDps`。比较使用当前导入的 331 个零件；不手写钻头专用预期表。
- `verify-inventory-detail-offline.py` 通过 Lua 5.4 运行实际详情行模块，并调用真实 `InventoryDetail:Render`，记录文字命令验证三个主数值的等宽数字字体。
- 最后结果 **5867/5867 PASS**；331 零件逐行文字/图标/顺序一致；`resourceDrift=[]`。证据：`docs/migration/evidence/inventory-detail-offline.json`。
- UI 脚本冻结 SHA256：
  - `InventoryDetail.lua`：`6f36f02bfc79a123ce3fd74ca9a60627de1f2406d63d67505bba857a9040ce96`
  - `InventoryDetailRows.lua`：`f711bcb2d95390fca23d184cd6626c5c9e3272d946e9b10f71bce2161fa48bed`
- 黄金提取器首次参数名冲突、缺少源几何依赖；Render stub 首次缺少 props，均为离线夹具问题，修正后完整重跑。没有据此改生产行为或阈值。

## d7af 实际 Web 增补

- 真实会话 `70055` 已结束，结果 `FUNCTIONAL_PASS_VISUAL_REVIEW_REQUIRED`：22/22检查、12个源/目标页面状态、运行错误0，PC与20:9均验证天元、夫元钻头及激光枪详情。使用公开建造/零件库输入与只读探针，没有注入游戏状态。
- 原始证据 `evidence/inventory-detail-web-2026-10-15T14-50-17-893Z`；精选报告与四张图已收入 `verification/2026-10-15/inventory-web/`。
- 实际查看 PC 天元钻头与20:9夫元钻头的四张底部配对截图。PC文字断行不同；20:9目标仍为较窄的居中布局、内容比例不同，不能签1:1。截图滚动位置不完全相同，背景蓝图操作也不同，不能将两张全图直接当像素等价比较。
- 桌面触摸模拟不等于真实手机；本次20:9进入建造/搜索仍使用外接键盘输入，不算自然手机入口验收。此运行只验证 d7af，不包含后续鼠标/Space增量。本批整理没有修改UI生产代码。

## 剩余实际验收待办

- PC 建造进入零件库，指向天元钻头，展开更多参数，应出现源全部七项钻头参数和阶位/占用/解锁；不得再出现火力/单把秒伤/每发耗能。
- 指向夫元钻头，应出现独立满蓄力 450、蓄力 1.5 秒/冷却 3 秒、突进 1.25 秒、每次耗能 22 及原彩蛋；不出现天元专有六段、钻削与维持耗能。
- 检查普通武器、移动零件、免费方块详情与切换后的展开状态；预算、质量、耐久仅数字使用源等宽字体。
- PC 与 20:9 横屏修正已观察到的字形、断行、整体比例与滚动差异，随后重验。原离线批未启动浏览器或native；上述后续Web证据不能扩大成全页视觉、输入、性能或真机验收。未收入之前的706d构建。
