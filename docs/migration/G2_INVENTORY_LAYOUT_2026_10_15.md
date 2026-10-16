# G2 装配终端排版候选

## 接续位置

- 从 `CURRENT_EXECUTION.md` 和 `G2_INVENTORY_DETAIL_2026_10_15.md` 接续，不重开 G0。
- H5 冻结基线 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`。
- 源快照 `.tmp/outgame-source-2026-10-15T12-35-57-243Z`。本批未改 H5、字体资源、引擎库或其他 agent 负责的玩法文件。
- 本批改动已进入下述 `8d1859cd` 统一候选，并完成一次实际 Web 功能检查。全页 1:1、真实手机性能仍未通过验收。

## 修正内容

1. **首页/建造的旧缩放策略**：旧 `TouchMode.Scale` 无条件固定 1920x1080；源 `homeScale.js` 已使用触屏主设备且短边不超过 600 时的 1066.6667x600 参考画布。候选将 compact 分类与实时 `Enabled` 输入判断分离，启动后保留分类，缩窗只重新计算比例；PC 小窗口不自动切成 compact。保留现有驾驶页策略。
2. **Web 平台映射边界**：Lua 没有浏览器 `screen.width/height`、`matchMedia('(pointer: coarse)')` 和 `navigator.maxTouchPoints` 绑定。候选沿用引擎 UI 的 `GetNativePlatform` 手机平台识别，加 `input.touchEmulation`、`-touch`，短边取启动时 CSS viewport；`-compact=1/0` 对应源调试覆盖。真实 Web 能否返回手机 native 平台、设备屏幕与嵌入窗口不同时的判定，仍待实际验证。不得以桌面小窗口强行当手机来签通过。
3. **参数列与换行**：扩展参数恢复源 CSS 的 `15px + 8px + minmax(54px,1fr) + 8px + minmax(0,1.6fr)`。PC 272px 内容宽的两文字列为 92.6875/148.3125；compact 201px 内容宽为 65.375/104.625。标签和值均按源字体实际字宽换行，按整行最高内容垂直居中。原实现标签不换行、值按标签实测宽度挤出列宽。
4. **详情纵向节奏**：标题用源 1.05 行高；说明用源正常空白合并与中文/单词换行、20.390625px 行高，compact 说明上下间距为 9/10px；主参数恢复已测 53.796875px 行高；详情外层承担底部 padding，避免子项再额外叠加空白。补左边框的 1px 内容偏移。
5. **compact 底栏**：快捷栏按源靠左，底部说明与操作菜单分置左右，菜单保留 32px 高。没有新增页面文字或改样式方向。

## 离线检查

- `verify-inventory-detail-offline.py`：**5867/5867 PASS**，331 零件行内容与数字字体回归，`resourceDrift=[]`。
- `verify-inventory-layout-offline.py`：**108/108 PASS**，实际 Lua 5.4 `InventoryDetailLayout`/`SourceRichText`/`SourceTextLayout`，使用实际打包字体的 cmap/hmtx/hhea。检查固定分栏、长标签两行、长数字值换行、右对齐不越界、10 个设备/调试场景、缩窗保留分类、相同尺寸不重复 SetScale、驾驶策略与本批前 HEAD 一致，以及五个生产文件 Lua 语法。
- 测试初次缺少 fontTools 路径、Lua 5.4 require 多返回值和 resize 夹具使用同尺寸，均已修正夹具并完整重跑，没有降低生产阈值。
- `git diff --check` 通过，仅既有行尾转换警告。未启动 native、浏览器或 GPU 运行；未提交 Git。
- 完整 SHA 与源输入 SHA 在 `evidence/inventory-layout-offline.json`；原 331 零件结果在 `evidence/inventory-detail-offline.json`。

## 修改范围

- `scripts/controls/TouchMode.lua`，经 root 授权的共享缩放策略。
- `scripts/ui/InventoryDetail.lua`。
- 新增 `scripts/ui/InventoryDetailLayout.lua`。
- `scripts/ui/InventoryPanel.lua`。
- `scripts/ui/InventoryChrome.lua`。
- 测试工具 `tools/migration/verify-inventory-detail-offline.py` 和新增 `verify-inventory-layout-offline.py`。

## 统一包实际验收

1. 记录 Web 端 native 平台、touchEmulation 与 compact 初始值。PC 1920x1080 和 1440x810 应保留 PC 结构；840x378 DPR3 真触屏环境应使用 600 高逻辑画布。
2. 经公开机库/建造/零件库入口进入，确认完整加载、退出和返回，停留时不反复重建。
3. PC 天元钻头展开更多参数：长标签两行，值列右齐；与源相同滚动位置配对截图，复核标题、说明、三主参数与更多栏的纵向位置。
4. 20:9 横屏夫元钻头：card 逻辑宽约 1309.333、高 588，detail 外列 220、内容 201；不能仍是窄居中 1580 的 PC 卡。快捷栏左齐、底部说明左右分布。
5. 普通武器、移动件、免费方块切换以及搜索、展开、滚动、关闭均保持；查看图像和字体实际结果。桌面触屏模拟不能替代真机性能和热稳定性。

以上是本批检查口径，实际结果如下；不能用离线字宽断言或旧 d7af 的截图签新包完整视觉通过。

## 2026-10-15 23:28 实际 Web 结果

- 测试入口：QA `http://127.0.0.1:4335`，普通包由 root 管理在 4336。
- 实际 manifest：`manifest-8d1859cd.json`；脚本指纹 `9e1a18222db2cac415191d526ff22d3b4f2f6941262b239f6426b98a54e6a34d`；probe `cc0a8416b00267ceb23a89d0b50f5819ef5071c013bcef92782e22d057f4a2f1`。五个生产文件 SHA 均与此包 identity 一致。
- 工具：`tools/migration/check-inventory-detail-web.cjs`，报告 `evidence/inventory-detail-web-2026-10-15T15-22-48-164Z/report.json`。
- 结果：`FUNCTIONAL_PASS_VISUAL_REVIEW_REQUIRED`，**30 项功能检查通过，14 个页面状态，14 个底部状态，运行错误 0**。源 `inventory.js`、库存 CSS、`homeScale.js`、响应式 CSS 与冻结快照内容一致。
- 经实际机库入口按 E/B、搜索天元钻头/夫元钻头/激光枪 T1、选卡、到达并展开更多参数、滚动、关闭返回建造完成。七组源/目标参数文字相符，关闭后 backdrop 均释放。目标运行页和浏览器已退出，GPU 已交还 root。

| 环境 | H5 compact | UrhoX 实测 | 结论 |
| --- | --- | --- | --- |
| PC 1920x1080 DPR1 | false | Web / native Windows / compact false，逻辑 1920x1080 | 保持 PC；详情 viewport 均为 `[1440,188,310,697]` |
| Android UA 横屏 840x378 DPR3、touch | true | Web / native Android / compact true，逻辑约 1333.333x600 | compact 生效；详情外列约 220、内容约 201，快捷栏左齐 |
| 保留原桌面 UA 的 840x378 DPR3、touch 诊断 | true | Web / native Windows / compact false，逻辑 2400x1080 | **未对齐**：H5 根据 coarse/screen 判断，引擎根据 native 平台判断。没有用 `-compact` 强制通过 |

### 已目视确认的残差

1. **字体仍不等同**：PC 天元底部配对中，目标详情正文和部分标题的字面显得更细，不能把使用相同字体文件等同于渲染一致。
2. **底部滚动有约 14-15px 视觉差**：PC 更多参数/最后一行整体位置与源不同；20:9 也有末尾 padding/滚动范围差。目标 ScrollView 显示可见滚动条，源没有相同外观。这些尚未签收。
3. **部分值断行仍不同**：20:9 天元“1秒打满，每0.2秒一段，需持续接触”源截图两行、目标三行；参数值列宽虽已按 CSS 固定，实际排版/字体栅格仍需对照。
4. **截图状态边界**：源端逐零件切换会保留详情滚动值（PC 夫元 287、激光 234；20:9 夫元 459、激光 445），目标切换回到顶部，所以带零件名的截图不保证同滚动位置；只在底部配对比较完整可见参数。源端 20:9 夫元图片的搜索框/卡片仍显示天元，但 DOM 标题与参数已是夫元，局部渲染滞后原因未确认，不能用这组完整首屏作像素一致证据。
5. **桌面触屏诊断未对齐**：目标零件库仍为居中的 PC 宽卡，源为近全宽 compact；目标建造触控栏很大。此项保留平台映射边界，不以 Android UA 结果覆盖原用例。

已实际查看：PC 天元 bottom 源/目标；20:9 天元 bottom 源/目标；20:9 夫元普通和 bottom 源/目标；desktopUA 目标 hall/build/天元 bottom。截图均位于上述报告目录。本次未修改生产文件、未提交 Git、未上传；不代表真机帧率、持续热稳定性或整个 G2 1:1 通过。

## 2026-10-16 底部滚动范围修复

沿上面的残差继续，未重开阶段。本增量已修改生产，但尚未签新包实际画面：

- 查实引擎 `ScrollView.UpdateContentSize` 仅累计子节点边界，不计 ScrollView 自身尾部 padding。源 `.inv-detail` 的 PC 16px / compact 12px 尾部 padding 已设置，却没有进入迁移版最大滚动范围；因此滚到底会把最后一行停在底边，缺少源留白。这是底部差异中已确定的一项，不能据此断言原 14-15px 视觉残差全部关闭。
- 新增局部 `InventoryDetailScroll.lua` 子类，先执行完整基类计算，再增加详情尾部 padding；每次由基类重算，连续帧不会累加。仅 InventoryPanel 的详情使用，不修改引擎库和其他滚动面板。
- ViewState 恢复上限同时使用详情高度与上下 padding；保持原有明确 centerHeight，避免模态布局初期 Yoga 高度 NaN 影响恢复。
- `verify-inventory-scroll-offline.py` **139 PASS**：实际完整引擎 ScrollView、实际生产子类和实际恢复语句，覆盖 PC/20:9、内容短于/等于/超过视口、仅超出1px、长内容、小数高度、重复更新、上下限/ScrollBy、恢复及临时 NaN 视口。`inventory-scroll-before.json` 保留旧路径 FAIL。
- 既有 `verify-inventory-layout-offline.py` **108 PASS**；`verify-inventory-detail-offline.py` **5867 PASS / 331 零件 / resourceDrift=[]**。

冻结 SHA：`InventoryDetailScroll.lua f3ff9a579905783d7fffee9123c3fe1e92856d71d64faa90c0d823636b7656c3`；`InventoryPanel.lua 3a1bec549dc0968822ae79bcbc4e65bad5d5102007372391825b3e45e6ba6327`。新增证据 `evidence/inventory-scroll-offline.json`。

边界：离线控件布局矩形是夹具，没有执行 Yoga/NanoVG、浏览器或 GPU；此项只确认缺失尾部范围的代码修复。字形粗细、窄列断行、实际滚动条样式和全页 1:1 仍未关闭。新统一包请用既有 `check-inventory-detail-web.cjs` 公开 E/B、展开详情、滚到底并截图，PC 1920x1080 与 Android UA 840x378 DPR3 分别确认尾部16/12逻辑像素留白和关闭返回。

## 2026-10-16 b239 右列文字复核：OPEN

沿用本阶段记录，不重启 G0。只读复核 `evidence/inventory-detail-web-2026-10-15T16-59-53-332Z/` 中 PC 天元钻头 bottom 源/目标原图，并生成局部并排图 `.tmp/inventory-detail-clipping-compare.png` 便于核对：源左、目标右。本批没有为此修改生产布局或字体。

- 目视残差仍存在：目标正文比源更细；“武器阶位”和“命中后钻削”等右值的末端显得贴近边缘，部分行疑似裁切，尚未取得实际 NanoVG 字形边界/推进记录，不能把疑似裁切归因成已查实的栏宽错误。
- 实际报告中源/目标详情内容同为 x=1465、宽272、右界1737；外滚动列同为 x=1440、宽310、右界1750。更多参数源固定值列为148.3125，生产 `InventoryDetailLayout.Row` 使用同样的值列宽。数据中的完整参数字符串也一致，不是迁移时丢字。
- 引擎完整 `ScrollView.CustomRenderChildren` 按外列 `[1440,1750]` 裁切；交互滚动条宽10、margin2，占 x=1738..1748，位于详情文字右界1737之外。现有坐标不支持直接认定“滚动条挡字”。没有缩列或增加右留白来掩盖字体问题。
- 日志确认实际包创建 `vox-body` 时选择 `Fonts/VoxIndustrial-Bold.otf`。相同文件/字体名不能证明 Web 字形栅格一致；当前离线字宽检查调用字体表推进，不执行引擎 `nvgTextBounds/nvgText`，所以不能用该 PASS 关闭此残差。
- 后续验收需在同一新包记录目标实际 value 行的 layout 宽度、run.x/run.width 和 Native NanoVG 字形边界，并对照源相同滚动位置。若推进不同，修度量/绘制一致性；若仅栅格不同，再查字体载入与渲染，不先改 CSS 列宽。该检查保持 OPEN，由主代理安排在统一构建可用后执行。

本次复核未启动 GPU、未启动浏览器、未改变 ScrollView 引擎副本；Workshop 生产修复已冻结，供主代理优先恢复完整战斗验收。

## 2026-10-16 b239 20:9 实际补证：功能通过、视觉仍 OPEN

主代理随后完成 `evidence/inventory-detail-web-2026-10-15T17-06-50-510Z/` 这轮实际 Web 检查：18 项功能检查、6 个页面状态、运行错误0。主代理已查看源/目标天元钻头底部配对图，确认目标文字仍更细、断行不同、目标滚动条可见。本子代理未重新启动 GPU，也未将主代理的查看记录冒充为自己的运行结果。

这轮说明 b239 的该入口与操作流程可以运行，不能据此关闭 G2 字体、断行、滚动条样式和全页视觉验收。此后 Workshop 生命周期修复及其他并行生产增量需要新统一包重新验收；本轮证据只属于记录的 b239 构建。
