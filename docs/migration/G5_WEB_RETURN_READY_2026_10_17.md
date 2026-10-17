# G5 当前返厅验收准备

## b88e 最新实际返厅：此子项通过

最新生产冻结 `.tmp/outgame-cached-1792180474126/identity.json` / `manifest-b88e4703.json`，QA4516原样保留生产PERF开启；实际HTTP main（117636字节）、manifest和完整observer suffix逐字节核验PASS，probe SHA `4907352f1a57a8f646efe197a565708ce66a1849765fe8c31ad8d1dcc6af1b5e`。证据 `evidence/g5-return-b88e-http-4516.json`。

最短公开路线 `check-salvage-natural-web.cjs --return-only` 已实际 **PASS / 11项 / 运行错误0 / probeErrors0 / CLOSED**：普通起步车进入打捞、真实捕获鼠标、W+左键5.314墙钟秒（游戏0.567→5.883秒）、原T放弃、实际大厅拥有结算、旧trial七项释放全部true；点原“回大厅”仅关闭结算、不重载hall或二次结算；真实鼠标“整备→车库→整备”成功，蓝图保持 `先锋 · 轮式激光`。

返回后的唯一overlay已实际识别为 `main.performancePanel` 的同一root（Panel、box-none、HitTest绑定、visible且未disposed）；未知Panel门禁仍保留。`result`和`returned`截图已实看：结算位于真实打捞大厅上方，确认后结算消失、整备页与PERF可见。这是返厅生命周期和公开输入子项通过，不是整体UI像素一致或性能验收。原3aca FAIL证据保持不变。

运行条件必须保留：独立非持久Chrome context、无既有profile、QA跳过教程并启本地validation namespace，没有真实平台账号；未启strong路线、工坊采购或QA销毁/注货。大量999是冻结生产 `UI/SalvageRules.json.testFill=999`，与冻结H5 `shared/salvage/stash.js:12` 的 `TEST_FILL=999`相符，由真实SalvageLobby初始逻辑填充，不是runner临时造数。实际冻结资源CRC/size/SHA已核对：`evidence/g5-return-b88e-inventory-boundary.json`。**不据此签真实账号经济、挣得库存、限量不足/扣件、云ACK或自然撤离。**

原始本轮证据 `evidence/salvage-natural-manifest-b88e4703-2026-10-16T20-07-01-234Z/`。runner77655 exit0，page/browser均确认CLOSED于 `2026-10-16T20:10:43.854Z`；自建4516服务81803已停止且端点拒绝连接，用户4514未动。未跑长场OOM，也未据大厅PERF数字签任何FPS收益。

下面3aca准备和首轮失败为历史接续，不能覆盖本节本轮状态。

日期：2026-10-17。生产候选：`.tmp/outgame-cached-1792178680605/identity.json`，`manifest-3acaaff3.json`。本子任务未启动服务、浏览器或 Runtime，未改生产；实际 Web 由父任务独占硬件运行。

## 本批明确缺口

最高优先级是新结算顺序的实际 Web 返厅验收。`G5_RESULT_RETURN_PARITY_2026_10_17.md` 的生产修复已在 3aca，但旧包的返厅证据不能签收新包。

发现并修复一个确定的 QA 构建串线问题：自然打捞 runner 使用工作区 Gameplay、RunData、Workshop 和 Outgame 资源决定路线、敌人、工坊选择及净货物断言，可能与正在服务的冻结包不同。现在按实际 HTTP identity 读取该冻结包的四个 `dist/assets` payload，验证唯一资源、大小与 CRC，并在结果 `reference` 字段记录 manifest 和资源 SHA-256。公开输入、原游戏资源和玩法没有改变。

## 可直接串行运行

父任务独占硬件窗口时，在两个终端分别执行：

```powershell
$env:VOX_PREPARE_FILE='.tmp/outgame-cached-1792178680605/identity.json'
$env:VOX_PREVIEW_PORT='4512'
node tools/migration/serve-outgame.cjs --qa
```

```powershell
$env:VOX_QA_PORT='4512'
node tools/migration/check-salvage-natural-web.cjs --return-only
```

前置条件：4512 未被其他服务占用，HTTP identity 为 3aca 且 `qa=true`；Playwright Chrome 可用；不要继承 `VOX_NATURAL_EXTRACT`、`VOX_NATURAL_DEATH`、`VOX_NATURAL_STRONG`、`VOX_NATURAL_PROFILE` 等其他路线变量。默认独立临时浏览器上下文，使用源起步车。运行后检查 JSON 的 `result` 与 `shutdown`，并亲自看 `result`、`returned` 截图。

`salvage-return-acceptance.cjs` 是断言模块，不是启动浏览器的 CLI。上面的 runner 会调用它。

## 逐条门禁

1. 公开大厅进入打捞并实际出发，下载/投放完成。
2. 实际鼠标捕获，持 W 与左键 5 秒，然后原 T 放弃。
3. 结算保留原车、丢弃货物、原 runId 只记一次损失。
4. 结算必须在实际 hall 安装、加载关闭后出现，七项旧 trial 释放证据全部为 true，不能有 live salvageRun。
5. 点实际“回大厅”按钮只关结算；hallGeneration、原车、经济不变。
6. 真实鼠标完成“整备 -> 车库 -> 整备”，没有其他模态挡输入。
7. 运行错误零，浏览器实际 CLOSED；截图可见内容符合预期。

本轮离线：四资源冻结内容校验及 10 个负控 PASS；返回断言 48 项 PASS；实际 OverlayState 与 Debug/DialogHost 生命周期 16 项 PASS；生命周期实际 Lua/源对照 179 项及 7 个行为负控 PASS。3aca 新增 `DriveAim.Clear` 导致首次旧夹具缺上下文而失败，夹具已改为执行实际 Clear 函数体，最终重跑通过；没有为此改生产。

## 首次实际 Web 结果与 QA 根因

`evidence/salvage-natural-manifest-3acaaff3-2026-10-16T19-31-48-313Z/salvage-natural-web.json`：整体 **FAIL**、8 项通过、运行错误 0、浏览器 **CLOSED**。原 T 放弃、库存/货物/经济与 runId 幂等通过；结算已在实际 `hallGeneration=2` 的打捞大厅出现，旧 trial 七项释放为 true。点击“回大厅”后结算和 `salvageReturn` 已清空。

失败是 QA 将剩余 `Panel` 当成未知模态：实际截图与对象来源核查指向右上性能面板。`main.lua` 的局部 `performancePanel` 持有 `PerformancePanel.New(app)` 实例，其 `root` 使用 `box-none`，自有 HitTest 仅测试右上 toggle。旧 observer 没有映射此实际 owner。现在只以同一 main chunk 中 `performancePanel.app==app` 且 `performancePanel.root==widget` 识别 `main.performancePanel`，保留 visible/disposed/HitTest 状态；不按 Panel 类名或 PERF 文本放行，不构造注册名或包装注册生命周期。未知 Panel、底层未知模态、丢失 HitTest、阻挡 pointerEvents、隐藏和已释放状态均有负控。

原 FAIL 文件保留。父任务需重启 QA 服务使新 observer 生效，再跑真实“整备 -> 车库 -> 整备”与剩余门禁；尚未凭离线修复签收鼠标交互。

自然成功撤离、自然死亡/900 秒超时、长场打捞 OOM、真实账号/云 ACK、完整画质及 845/TapTap 持续性能仍 OPEN。本短路线不能替代这些门禁。当前没有新实测确认的生产玩法缺陷；首次 Web 的 QA owner 缺失已经窄修，公开输入复测待跑。
