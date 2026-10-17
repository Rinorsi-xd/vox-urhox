# G5 无尽局内改装：零库存选件保护

日期：2026-10-17。最新状态：实际 Web c074-h 的库存、改装暂停恢复和公开结算返厅窄链 PASS/CLOSED；a--g 的原始 FAIL 均保留。仅关闭下述受控入口链，不签全 G5、真实账号或性能。

## 实际 c074-h：库存与公开结算返厅窄链完成

主线串行运行 `evidence/endless-stock-web-c074-h`，实际结果 **PASS / CLOSED / exit 0**，Runtime / HTTP errors 均为 0。独立只读重建 runtime 的 3,772 个分包、350 组完整状态：索引唯一、字节长度和 FNV-1a checksum 全部通过，报告 19 个状态逐一与原始分包严格相等。保留较早辅助 OUTGAME_STATE 的 1 条半截 JSON（runtimeSequence312），不将其隐去或算作库存通道通过。

真实支座 78→79、激光 79→80 / 库存1→0；耗尽卡片 disabled/unavailable，点击、双击、拖拽、键盘激活与分配均保持原选择、蓝图、历史和库存。实际 Ctrl+Z 恰好一次 ctrl=true,z=true 派发，79件 / 库存1 / undo1,redo1；Ctrl+Y 恰好新增一次 ctrl=true,y=true 派发，80件 / 库存0 / undo2,redo0。右键实际命中 laser1 并拆除后79件 / 库存1，公开重置回78件、undo0/redo0，蓝图与进入改装时严格相等。

全部14个编辑状态的世界和局内时钟均精确保持 `16.86666666666699`，波次1 / 命数3；出发后恢复至 `17.733333333333608`，仍同波同命。新实际 OUTGAME_STATE seq390 证明 Escape 打开 `app.trial.dialog / 暂停 / open=true`，captured/pending均false；实际点击背景后seq392只剩不阻挡的box-none性能层，指针仍未捕获。随后真实点击“结束本局”进入over（时钟19.25000000000019），再点击“回主页”，最终mode/tab=hangar、loading=false并有可见启用“出战”。旧g失败没有被覆盖；h补上了该次缺失的真实释放指针步骤。

工具当前SHA与报告及h前冻结三项一致：runner `e7a3bece...04df6`、observer `6ab59726...a694`、serve `3134fec3...c319`。同c074冻结fingerprint `b8c52246de4ee2ab9a39ee2e4187da389693c0d8c4378d2230208fa799a3524d`，不自动替后续4a3a包签署。report SHA `19ec91c24c5e7b3ba3fca8dbeb824e7ef7f662355a215f322a665ae088c07650`，runtime SHA `457b42cfecac72db351683a8c862fad24b68d996fc36ff7ebcc2d5347a34b189`。独立派生见 `evidence/endless-stock-web-c074-h-independent.json`。

边界仍为既有QA PageDown进入生产SelectEndless、真实起步车和改装输入；自然倒数/出兵后F2清已出生敌人、F3回基地。没有注入库存或蓝图、没有直接调用Finish来制造返厅。本结果不是自然完整整波、公开完整模式入口、全G5、真实账号/云刷新、全部视觉一致或骁龙845 TapTap持续30FPS验收。主线已实看resumed/returned图；本独立审计没有启动游戏或改生产。

## 基线与确认的差异

冻结 H5 基线为 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`，读取现有 `docs/migration/outgame-baseline.json` 指向的冻结副本。没有修改源副本或重新回到 G0。

源 `shared/build/editor.js` 的 `pickPart` 和 `assignSlot` 在限量库存耗尽时拒绝操作，保留当前零件、快捷栏与输入状态，反馈 `本局仓库没有这个零件 / bad`。源 `shared/ui/inventory.js` 对这些卡片设置 disabled。

迁移版此前只在实际摆放的 `history.Commit` 中拒绝超额，仍允许从零件库选取和分配无库存零件。双击耗尽卡片还会关闭零件库，拖拽也能开始；直到摆放才失败。因此原有放置校验不能代替选件规则。

## 窄范围修改

生产仅修改 `scripts/endless/Edit.lua`，当前 SHA-256：

`12bee1c91233154abf643ad8c8fe74418214ec4084c181b3a6e47ecae7ba09c9`

- 在本次改装拥有的 BuildSession 实例上包装 PickHotbar、AssignHotbar；每次按当前蓝图与拥有量重新核验，不维护第二份库存账。
- 在本次 InventoryPanel 实例上设置 Unavailable，并更新虚拟列表卡片的 disabled。实际键盘激活、双击与拖拽调用沿用既有消费者。
- OpenInventory 完成后立即同步卡片，后续继续沿用原 0.1 秒刷新。
- 结构方块不限量；实际放置的 history.Commit 超额校验保留。

没有改共享 BuildSession / InventoryPanel 类表，没有改普通车库或打捞库存策略。`Leave()` 原有 `build:Dispose()` 关闭零件库并释放该改装会话；保护闭包随该实例结束，无全局策略需要恢复。

## 已执行验证

命令：

```powershell
& 'C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' tools/migration/check-endless-edit-stock.py
& 'C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' tools/migration/check-g5-edit-touch.py
```

库存对照：48 个源场景、854 个断言、4 个行为负控全部 PASS。证据为 `evidence/endless-edit-stock-offline.json`。相关触屏/改装回归：203 个断言、7 个行为负控 PASS，证据 `evidence/g5-edit-touch-hoist-2026-10-16.json`。

库存对照执行完整冻结 JS 模块，仅适配 import/export、DOM/呈现、蓝图 Map 边界；调用实际 EndlessEdit.enter、remainingInventory、Editor.pickPart/assignSlot/selectSlot。Lua 侧执行实际 Edit、BuildSession 快捷栏/保存方法、Inventory、Blueprint.Load/Add/Remove/List、BuildEditor.SelectType、BuildInput.Cancel、InventoryPanel 行回调和 InventoryKeys.Activate。

用例覆盖武器、移动、功能零件与无限结构，拥有量/安装量为 0/0、1/1、2/1、1/2；检查当前零件、10 个快捷槽、活动槽、取消状态、保存次数和原拒绝文案。移除任一选取守卫、卡片 unavailable 或 disabled 都会在对应断言失败。

额外执行实际 EditHistory.Commit / Undo / Redo：

1. 唯一限量零件已安装且卡片禁用，删除已安装零件仍成功并归还 1 件。
2. 撤销删除回到 0 件，重做删除回到 1 件。
3. 重新安装、撤销安装、重做安装，库存准确为 0 / 1 / 0，没有复制库存。

旧 `check-endless-edit-enter.py` 复跑在加载模块阶段缺 `app.ResourceGate` adapter 而失败，尚未执行 Enter 断言。本次保留此失败，不算回归通过；没有为旧夹具修改生产加载顺序。

## 给主线的实际 Web 验收入口

新增隔离工具，不修改共享 server/probe：

- `tools/migration/endless-edit-stock-web-serve.cjs`：读取主线提供的不可变 identity，通过内存派生既有 server，仅追加观察器。
- `tools/migration/endless-edit-stock-web-observer.lua`：在原 PostUpdate 后，按 F8 输出 `ENDLESS_STOCK_CHUNK` 分段 JSON；只读取 retained editor 的库存、快捷栏、卡片 disabled/unavailable、屏幕矩形与世界时钟，不写战斗状态、不调用校验重建。

由主线串行启动，不能和性能采样并跑：

```powershell
node tools/migration/endless-edit-stock-web-serve.cjs <包含本次 Edit 的 identity.json> <空闲端口>
```

实际步骤与通过条件：

1. 隔离 `--qa` 的 PageDown handler 调用生产 `SelectEndless`，再实际点击“先锋 · 轮式激光”。这是受控 QA 入口，不是生产公开菜单导航验收。等待自然倒数、真实出兵完成。F2 仅击毁已出生敌人，等待实际波末休整，鼠标选择一项补给；F3 仅把实际玩家移回基地，按 G 进入保留战场的编辑器。
2. F8 记录 wave/lives/worldTime/runTime、拥有量、快捷栏与已装件数。B 打开真实零件库，选有剩余的限量零件，关闭零件库；使用实际建造输入把其剩余量装至 0。初始车附送备用件，因此不能把初始同款卡片直接当零库存夹具。
3. 再开 B，搜索该零件：disabled 与 unavailable 均为 true，剩余量为 0。点击、双击、拖拽到快捷槽、键盘激活不得改变快捷栏或关闭零件库，也不得增添零件。
4. 关闭零件库，实际撤销最后一次安装，再开库：应恢复正库存且卡片可选。重做安装再次耗尽；实际拆下已安装的该件仍归还库存。
5. 重置本次改装回到开局蓝图；点击“Enter · 出发”，恢复同一波次和命数。编辑期间世界/局内时钟应暂停，恢复后继续；公开返回大厅关闭运行。

上述实际 Web 编辑库存步骤尚未到达，不能签 PASS。离线适配器不证明 Enter/Leave 场景生命周期、真实浏览器输入、1:1 视觉、自然整波战斗、账号恢复或性能，更不证明骁龙 845 / TapTap 持续 30FPS。

### 自动执行入口补充

`endless-edit-stock-web-run.cjs` 已补齐，由主线独占硬件时执行；本子任务没有启动浏览器或服务。

```powershell
node tools/migration/endless-edit-stock-web-run.cjs --self-test
node tools/migration/endless-edit-stock-web-serve.cjs .tmp/outgame-cached-1792206583227/identity.json <空闲端口>
node tools/migration/endless-edit-stock-web-run.cjs http://127.0.0.1:<端口> docs/migration/evidence/endless-stock-web-0bae-a
```

runner 通过 Playwright 的实际点击、按键与指针锁移动驱动。无尽入口是已说明的 QA PageDown，后续选择起步车、改装与结算调用真实 UI；不把这条链称为公开完整导航。观察器只读输出当前编辑器、相机姿态、可见车体表面候选、真实零件 ID、库存与 UI 矩形；不设置库存、蓝图、相机或模拟状态。候选只帮助移动鼠标瞄准，安装仍经真实输入与生产 history.Commit。找不到合法放置面时明确 FAIL，不通过直接提交绕过输入。

验收链包括系统起步车、自然倒数/出兵（F2 只清已生成敌车）、实际补给选择、回基地 G、实际安装备用激光至耗尽、禁用点击/双击/拖拽/Tab 后 Enter/Space/数字分配拒绝、真实 Ctrl+Z/Y 与右键拆除归还、公开重置/出发、同波同命数恢复以及公开结算回大厅。报告保留逐段状态、HTTP 源哈希、控制台日志与最终截图。

离线结果：Node 语法与自测 PASS，UTF-8 分段长度和重复/截断检查通过，12 个选取状态与暂停时钟负控均被拒绝；Lua 5.4 观察器语法 PASS。实际浏览器输入路径仍待主线运行，不能据此标记 Web PASS。

### 实际 a/b 工具失败与 c 修复

`evidence/endless-stock-web-0bae-a` 为 FAIL/CLOSED：`Module.calledRun` 时仍在引擎 `LoadPreloadResources`，游戏 observer 尚未运行，原 8 秒 F8 门禁过早失败。已增加首个真实 PostUpdate 的 observer-ready 握手及独立 120 秒启动等待；未延长正常 F8 或其他状态门禁。

`evidence/endless-stock-web-0bae-b` 为 FAIL/CLOSED：bootstrap 握手通过，但初始观察 seq1--23 尚无 app，输出 `tab=false/widgets={}/loading=false`；旧 hall 判定误放行。seq24 才有实际机库且 `loading=true`，seq41 才关闭加载，之前的 PageDown 被加载门禁拒绝。c 的 hall 判定必须同时满足 `tab=hangar`、真实可见“出战”按钮、`loading=false`，并保留初始失败数据与全部游戏错误检查。starter 实际名称仍为“先锋 · 轮式激光”。此轮只改 runner，已有新版 observer 的 4581 服务无需重启。

`evidence/endless-stock-web-0bae-c` 为 FAIL/CLOSED：已实际点击起步车并装配无尽场景，但首个装配帧的 seq181 只有 145 字节，JSON 停在 `widgets[1].rect=[0,0,`。单包字节数完全符合声明，证明截断发生在 Lua encode 之前或内部，而非分包丢失；同帧原 QA OUTGAME_STATE 也停在该矩形位置。既有真实 codec 探针 `monitor-combat-effects-2a97-a/runtime.log:1000` 已记录 NaN 会让引擎 cjson 返回半截字符串且不抛错。原始 c 日志没有保存矩形数值，故不能直接读回当时宽度具体是什么。

d 工具对未布局完成的非有限矩形保留控件并明确输出 `rect=false/layoutPending=true`，不能将其用作点击位置；其他所有数值递归执行 finite 检查，encode 后必须能完整 decode。分包额外携带 FNV-1a checksum，runner 校验字节数、checksum、重复包和完整 JSON，任何失败仍中止。未修改生产 UI 或吞游戏错误。观察器已改变，主线重试 d 前必须重启隔离 server。

`check-endless-stock-observer.py` 离线执行真实 Lua 观察器：NaN/正负无穷矩形、有效矩形、跨块中文、意外非有限数据和伪造半截 codec 结果共 7 检查 PASS；Node 自测另拒绝等长损坏、缺 checksum 与字节数自洽的半截 JSON。这些只验证观察工具，d 实际库存路径仍未验收。

### 实际 d：进入改装成功，真实放置未通过

主线已运行 `evidence/endless-stock-web-0bae-d`，结果为 **FAIL / CLOSED / exit 1**，浏览器已关闭、隔离 server 已停。报告中的 runtime errors 和 HTTP errors 均为空；bootstrap 握手、完整 JSON 接收及实际无尽改装入口已越过先前 a/b/c 阻塞。

失败明确为 `No legal actual laser placement found; never manufacture inventory or commits`。主线实际尝试 100 个候选面，激光预览未达到合法放置条件（重叠或地面约束），因此没有点击提交伪装通过。最终仍有 78 件、`laser1` 已装 1 / 剩余 1、undo / redo 均为 0；最后预览理由为“与已有零件重叠”。改装中的波次为 1、命数 3，世界与本局时钟均为 16.783333333333662；这些末态只能说明当时状态，不能代替尚未执行的完整暂停/恢复断言。

因此零库存卡片拒绝、库存耗尽后撤销/重做/拆除归还、公开重置和出发恢复仍未验收，不能签 Web PASS。下一次独占硬件验收应先通过真实输入放置无限结构方块支座，再将限量激光安装到合法支座上；仍必须使用实际建造预览与 history.Commit，不得改库存、直接提交或放宽合法性门禁。本次仅归档 d 结果，不重跑、不改冻结工具。

### e 前冻结：实际输入先建支座，再安装限量激光

d 的失败保留。修订仅涉及隔离观察器、runner 和 serve；生产 `Edit.lua` 仍为上述 `12bee1c9...`，没有改库存、放置规则或实际输入消费者。工具已冻结，主线运行期间不得再修改：

| 工具 | SHA-256 |
| --- | --- |
| endless-edit-stock-web-observer.lua | 3994b054fab0339495632658fad351eb3f58d98a9479142b51ad70d418fbc30e |
| endless-edit-stock-web-run.cjs | 798c8cd6217e0379b3ac26812c5a5a481581eb272c778e4030b32993e85eab63 |
| endless-edit-stock-web-serve.cjs | 3134fec3b389120c99479b843c380e18c225fbd56bdbdd147debf756fc07c319 |
| check-endless-placement-input.py | 60a1c45c59aa920a50e8ca83761286f6cd768985227f13b3fec7f4baa0d211ae |

观察器使用实际 `Placement.For` 和 `bp:Check` 只读计算候选合法性；实际 editor 的 hit / preview 不被改动。枚举全部可见面、将合法候选排序之后才限制输出 100 个，避免按蓝图零件枚举顺序提前截断。runner 经真实数字快捷栏选择无限方块，在前甲板现有结构件顶面安装一个支座，再经真实快捷栏与鼠标移动把备用激光安装到该新支座顶面。每次仍必须实际 `state.preview.ok` 才点击，随后校验确切新增 ID、零件数及库存差额；拆除时必须射线命中刚安装的确切激光 ID，不能拆支座冒充库存归还。

离线确定性检查读取 d 的真实 `editor entered` 蓝图与库存，执行实际 Lua `GridRay`、`BuildEditor`、`BuildInput.FirstPerson`、`Placement`、`EditHistory` 和无尽库存代码；相机、输入及服务边界使用适配器。没有直接调用 Commit 来完成验收放置。真实左键输入先在原 part8 的 `{-2,2,3}` 顶面建 part79 支座 `{-2,3,3}`，再把激光装在 `{-2,4,3}`、rotation9；该合法激光面在原枚举顺序为第 **185** 个，旧的前 100 个截断会漏掉。随后实际撤销、重做和右键拆除，库存序列为 `1,1,0,1,0,1`，最终 79 件、undo1 / redo0；每个候选预测与实际 Trace 的预览位置、旋转、合法性严格一致。

结果持久保存在 `evidence/endless-stock-placement-offline-2026-10-17.json`。Node 语法、既有 12 项负控、自测及 Lua 观察器 7 项检查均通过。以上证明修订放置策略能通过实际 Lua 输入消费者，**不等于真实 Web 输入、暂停恢复或完整 G5 通过**。

主线必须重启 server，使用包含当前 Edit 的冻结 identity；serve 会提供确切 observer SHA，runner 校验该值和实际 HTTP 的 BuildEditor / GridRay / Placement / BuildInput SHA，不接受仍运行旧观察器的服务：

```powershell
node tools/migration/endless-edit-stock-web-serve.cjs .tmp/outgame-cached-1792209050608/identity.json 4581
node tools/migration/endless-edit-stock-web-run.cjs http://127.0.0.1:4581 docs/migration/evidence/endless-stock-web-351f-e
```

实际 e 尚待主线独占硬件窗口执行；库存耗尽、禁用交互、撤销重做、拆除归还、重置、同波同命恢复及公开返厅的完整 Web 断言仍为 OPEN。本子任务未启动 Runtime、浏览器或服务。

### 实际 3030-e：安装和禁用交互已越过，Undo 未派生出蓝图变化

主线实际执行 `evidence/endless-stock-web-3030-e`，结果为 **FAIL / CLOSED / exit 1**；runtime errors / HTTP errors 均为空。合法真实输入已安装支座 78→79（undo1），再安装激光 79→80（undo2），备用激光从 1 到 0。真实点击、双击、拖拽、Tab 到卡片后的 Enter / Space / 数字分配全部保持 80 件及零库存，没有绕过禁用守卫。

失败在原 runner94 的第一次 Ctrl+Z 后：期望 79 件，实际仍为 80；末态 inventory=false、captured=false、undo2 / redo0。原 e 没记录该次按键到达引擎的 Ctrl / Z 状态、UI 文本焦点或 DOM 活动元素，不能把“未撤销”直接归因到生产 Undo，也不能把未捕获指针当作已证实原因。e 的 report SHA 为 `e2c4a26123a7d7441cf7a2fca221b69ae97b5c1897bac97c73ad0854aef56b10`，runtime.log SHA 为 `271bbd7610470fdd3a471ac7cfaa3636a44aff083f2206d0ecf41c904c4f60bd`；原文件保留。

补充离线执行实际 `BuildSession:Keys` 方法，复用上述真实指针安装产生的历史：文本输入拥有焦点时 Ctrl+Z 确实被实际 Keys 守卫拒绝；移除适配器文本焦点后，即使 captured=false，实际 Keys 也能把 80→79、库存 0→1，再由 Ctrl+Y 还原 80 / 库存0。说明指针捕获本身不是 Keys 方法内的必要条件，实际 Web 的输入路由仍须取证。结果为 `evidence/endless-stock-history-input-offline-2026-10-17.json`，没有用直接 Commit 制造历史。

f 前仅修隔离工具：关闭库后实际点击画面重新接管输入，再发送 Ctrl+Z/Y；额外只读记录 DOM 活动元素、引擎焦点、文本焦点及实际 `BuildSession.Keys` 调用前后的 parts / undo / redo。必须观察到一条新的真实 Ctrl+Z/Y 派发，原 80→79→80 和库存断言不变，未出现派发就明确失败。原生产 Keys / Undo / Redo / 库存方法完全未改。观察器包装仅该 QA 会话实例，不改变其原方法结果。

修订后的实际 Lua 输入、历史及观察器遥测检查 PASS；既有 Node 自测和 12 项负控、观察器 7 项 codec 检查 PASS。新冻结值：

| 工具 | SHA-256 |
| --- | --- |
| endless-edit-stock-web-observer.lua | 6ab5972631de2c107be79cb443088bc195c58db4f89827c49cf48b5baa10a694 |
| endless-edit-stock-web-run.cjs | 03ebdc83b02819ab2f46cdf1bdfa19021b7f5b846b1c9ea1d64026cec5780fdc |
| endless-edit-stock-web-serve.cjs | 3134fec3b389120c99479b843c380e18c225fbd56bdbdd147debf756fc07c319 |
| check-endless-placement-input.py | 777bb42863d4a0397469c23c30d155668b4eeb53442861fada4013d455bdf30b |

主线后续重新启动隔离 server，并使用同一最新 3030 identity，输出新 f 目录，不能覆盖 e。f 尚未运行，库存完整生命周期和是否存在真实 Web 快捷键路由问题均未关闭。本子任务未运行 Runtime、浏览器或服务，也没有修改 CURRENT_EXECUTION。

### 实际 c074-f：真实 Z 已到达，但引擎采样时 Control 未保持

主线实际执行 [endless-stock-web-c074-f/report.json](evidence/endless-stock-web-c074-f/report.json)，结果 **FAIL/CLOSED/exit 1**，Runtime 与 HTTP 错误均为 0，测试进程和服务已停止。真实支座安装 78→79、激光安装 79→80、库存 1→0，以及禁用卡片交互均已越过。首次撤销仍为 80 件、undo2/redo0，未签库存完整生命周期通过。

f 新增的实际输入遥测明确记录：DOM 活动元素为 BODY；引擎焦点为 true、playfield=true、captured=true、textInput=false、inventory=false、dialog=false。真实 `BuildSession.Keys` 只观察到一次 `z=true, y=false, ctrl=false` 派发，前后蓝图与历史未变。失败是保留的 `Actual engine Control key held during shortcut dispatch` 门禁，不再归咎于未捕获鼠标或文本框焦点。

这支持测试快捷键按下/抬起过快，在引擎处理已锁存的 Z press 时 Control 已释放的输入时序解释。原始数据没有保存全部浏览器事件时间，因此不将精确抬起时刻或内部引擎行为当成已直接测量事实。生产 Keys 的 Ctrl 守卫符合实际输入，不据此修改生产 Undo。

f 原始 report SHA-256：`473f921a548c9c0912a1f15c4b5e1d589a1dc2adc9b0df6868886b91f659270b`；runtime.log：`4f5b1c61ea0063f0aceddecb406ec4011b5335ca6a08dea4cecb97997a4322d7`。原始失败记录不改写。

### g 前冻结：真实按住 Control，直到实际 Keys 派发

仅测试 runner 修改快捷键派发：实际 `keyboard.down(Control)` 保持 120ms，再实际 `keyboard.down(z/y)` 保持 80ms；继续按住两键，直到只读观察器记录一条新的真实 Keys 派发，仍严格要求 Ctrl=true、正确 z/y、恰好一次派发、无模态和文本焦点。最后通过 finally 释放 z/y 和 Control。原库存、蓝图、撤销/重做与世界暂停门禁全部保留，未直接调用生产 Keys、Undo、Commit 或写入库存。

新增 [check-endless-history-chord.cjs](../../tools/migration/check-endless-history-chord.cjs) 执行 runner 的实际快捷键 helper，用键盘/时钟适配器验证两种键的顺序和保持区间、观察器失败/按下失败/抬起失败时清理、非法快捷键拒绝，以及 f 的 ctrl=false 必须失败，共 12 检查 PASS。既有 runner 自测及 12 项负控、语法检查通过。它不代表真实浏览器输入或 g 已通过。

工具冻结：runner `1d051b430b1e1a43a7ac3761e3d915412ab6c6ec00c85e169e7f9feb82736cbd`；observer 仍为 `6ab5972631de2c107be79cb443088bc195c58db4f89827c49cf48b5baa10a694`；serve 仍为 `3134fec3b389120c99479b843c380e18c225fbd56bdbdd147debf756fc07c319`。新增快捷键检查 SHA：`2211d6c6537052b6e872800e838652ac0086a0073adfb97d4ec30893f743fb13`。

使用最新 c074 冻结 `.tmp/outgame-cached-1792213080660/identity.json`，新输出目录 `evidence/endless-stock-web-c074-g`；g 实际运行待主线完成，不能覆盖或将 f 改为通过。

### 实际 c074-g：库存生命周期通过，公开返厅仍失败

主线实际执行 [endless-stock-web-c074-g/report.json](evidence/endless-stock-web-c074-g/report.json)，整体仍为 **FAIL / CLOSED / exit 1**；失败为 `Stage deadline button 回主页`。Runtime errors / HTTP errors 均为 0，不将末段失败或此前 a--f 记录改写为通过。

独立复核 17 个状态快照确认：真实支座 78→79、激光 79→80 / 库存1→0，零库存的点击、双击、拖拽和键盘激活均未改变蓝图或库存。真实 Ctrl+Z 观察到恰好一次 `ctrl=true,z=true,y=false` 派发，80→79、库存0→1、undo1/redo1；Ctrl+Y 恰好新增一次 `ctrl=true,y=true,z=false` 派发，恢复80 / 库存0、undo2/redo0。两次均实际引擎焦点为 true，文本焦点 / 库 / 对话框均为 false。右键射线命中实际 laser1 后拆除，79件 / 库存1 / undo3；公开重置恢复78件 / 库存1 / undo0/redo0，蓝图与进入改装时严格相等。

全部编辑状态的世界和本局时钟都精确保持 `16.883333333333656`，波次1 / 命数3；出发后仍是同波同命，两个时钟均恢复至 `18.00000000000026`。以上细项已实际越过，不代表公开返厅或 G5 整体通过。

返厅失败的现有证据来自同一 runtime.log 的实际 `OUTGAME_STATE`：第6681行，世界时钟 `18.73333333333355`，点击“结束本局”中心 x1528/y34 时，pointer.captured 仍为 true，lastPointer.classes 只有 Panel / Widget 且 button=false。此后137个有效样本到世界时钟 `38.91666666666574`，始终 captured=true / rest / wave1，未进入结算，因此“回主页”按钮未出现。

生产 `EndlessSession:ResumeEdit()` 最后调用 `TrialSession:Resume()` 并重新捕获驾驶指针；`DriveHud.lua:104-108` 在 captured 时把根和子项 pointerEvents 设为 none。结合实际命中记录，本次 runner 在出发后未先实际 Escape / 释放指针，是有证据支持的测试流程缺口。尚未实测 Escape 后公开结束与返回，不能据此断言返厅已修复，或将这次失败直接归咎于生产 Finish / Summary。`OUTGAME_STATE` 的第3262行在更早的编辑期还有一条半截 JSON，独立结果保留该记录；退出点击区间无解析失败，库存断言使用单独有校验和的 ENDLESS_STOCK_CHUNK 传输。

独立派生结果：[endless-stock-web-c074-g-independent.json](evidence/endless-stock-web-c074-g-independent.json)，SHA-256 `e7d5668fd07d64ad97f2e4bde8a6a0c36d2625df30ead7c593fd406a45772608`。该文件的 auditStatus=PASS 只指原始 g 证据与上述断言复核一致，原始游戏验收 status 明确保留 FAIL。本子任务没有启动浏览器 / Runtime、没有准备 h 或改冻结 runner，也没有修改生产代码、CURRENT_EXECUTION 或 Git 分支。

### h 前冻结：真实释放指针，再走公开结算与返厅

g 的 FAIL 原始资料保留。本轮只改专属 `endless-edit-stock-web-run.cjs`，未改生产、观察器或 serve。出发并验证时钟恢复后，实际发送 Escape，读取既有 `OUTGAME_STATE`，必须在新样本中确认 `pointer.captured=false / pending=false`、无尽仍 rest，以及顶层实际 `app.trial.dialog / 暂停 / open=true`。统一暂停页会挡住 HUD，而“继续”或再次 Escape 会重新捕获指针；因此实际点击卡片外的背景关闭模态，再要求一个更新的实际样本证明仍未捕获指针、没有阻挡对话框（允许既有 box-none 性能面板）。随后真实点击 HUD“结束本局”，必须先观察 `state=over`，再点“回主页”，最终必须满足真实已加载机库和可见“出战”按钮，不能仅 mode=hangar 便放行。

所有库存、真实输入、恰好一次 Ctrl+Z/Y 派发、拆除命中、reset、波次/命数和时钟门禁保留。没有调用 Finish / Host.Close / wantsReturn 或写入库存。既有主观察器在更早编辑期的半截 OUTGAME_STATE 单独记入辅助解析异常，不代替有校验和的库存状态；新增指针门禁只接受实际完整解码的新样本，未知或缺失状态均失败。

[check-endless-return-pointer.cjs](../../tools/migration/check-endless-return-pointer.cjs) 使用实际 runner helper 验证 Escape→观测→真实背景点击→再次观测的顺序，并拒绝未释放、pending、错误模式/阶段、未知或仍在的阻挡模态、重新捕获及输入失败，共29项检查 PASS。旧快捷键 helper12项、runner自测及12项库存/暂停负控、Lua观察器7项 codec 检查和 Node 语法通过。这些是离线工具检查，h 实际 Web 仍待运行。

| 冻结工具 | SHA-256 |
| --- | --- |
| endless-edit-stock-web-run.cjs | e7a3bece19fa34ef8ea5040391c85235827e116c96397937c76aa32bd0e04df6 |
| endless-edit-stock-web-observer.lua（未改） | 6ab5972631de2c107be79cb443088bc195c58db4f89827c49cf48b5baa10a694 |
| endless-edit-stock-web-serve.cjs（未改） | 3134fec3b389120c99479b843c380e18c225fbd56bdbdd147debf756fc07c319 |
| check-endless-return-pointer.cjs | 8cea7097b0cbeb511636aab9f5a147f3ca6ed2a848ebb84d64a4de9ab2a9c2d6 |

主线串行运行，使用同一 c074 冻结并写新 h 目录，不能覆盖 g：

```powershell
node tools/migration/endless-edit-stock-web-serve.cjs .tmp/outgame-cached-1792213080660/identity.json 4581
node tools/migration/endless-edit-stock-web-run.cjs http://127.0.0.1:4581 docs/migration/evidence/endless-stock-web-c074-h
```

本子任务没有启动 Runtime、浏览器或服务器；h 未运行前公开返厅仍 OPEN，整体 G5 未签收。

## 源执行哈希

| 模块 | SHA-256 |
| --- | --- |
| shared/battle/endlessInventory.js | 7b129fd4459256780562684390855a02fe0f9b26a09db72b170c538f8de59405 |
| shared/build/editor.js | 4a216cc80adc7e9f2ad1388e3877bb5097d702a914e438ae6ce9b25e682dd211 |
| three/src/battle/endlessEdit.js | d915973577ba5210d5ace66811ec12cea44cead6ce691638557f59df4dc8629b |

本子任务没有启动 Runtime / 浏览器；上面的实际 a/b/c/d 均由主线独占运行并提供证据。本子任务没有改 CURRENT_EXECUTION，没有 commit、push 或分支操作。
