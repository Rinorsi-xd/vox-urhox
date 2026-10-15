# 武器图标门禁与恢复光壳联合检查

2026-10-15：集中依赖模块 `scripts/ui/WeaponIconResources.lua` 已冻结。只收集实际装备对应的普通/Hurt图标，不全Catalog预载。HangarApp/OpeningHost资源接线由root维护，本批未改这些共享文件。未重复44项恢复光壳专项。

## 函数契约

`require('ui.WeaponIconResources').For(parts) -> string[]`。

输入可为 `bp:List()`、`VehicleSpec.weapons` 的 `{type=...}` 项，亦可直接为 `bp:ToTable().parts` 的数组项。按装备输入顺序输出每种图标的 normal/Hurt 两条路径，同型多件去重，`fuyuanDrill` 与 `tianyuanDrill` 共用后者图标并去重；非武器、未知类型、nil/空列表返回空集。函数不访问图片或发起下载。

例：`For({{type='mg3'},{type='mg3'},{type='core'}})` 返回 `UI/WeaponIcons/mg3.png`、`UI/WeaponIcons/Hurt/mg3.png`。root应把返回列表追加至实际入口 `options.resources`；开篇按实际玩家原型、后续可换装武器原型收集，不能只补战斗HUD首次读取处。

## 已验证

- `node tools/migration/check-weapon-icon-resources.mjs`：10项资源清单/实现契约静态检查通过；Catalog17武器type对应16种图标，32个normal/Hurt路径及SHA256已记录在 `evidence/weapon-icon-resources-check.json`。首次脚本Windows URL路径解析错误已修为`fileURLToPath`，未涉及生产文件。
- `powershell -NoProfile -ExecutionPolicy Bypass -File tools/migration/verify-weapon-icon-session.ps1`：真实Lua执行 `For` 的空集/非武器/未知类型/序列化输入/同型去重/钻头映射，以及17种Catalog武器路径存在；实际 `ResourceGate` 配冷测试后端验证加载阻挡、只请求当前装备2条路径、回调后完成。后端为确定性夹具，**不是实际Web冷网络下载证据**。
- 同一原生夹具建立实际 `TrialSession`/`PracticeSession`/CarUnit/Bullet/DriveView：实际损失与恢复由共享 `Tick` 接到RestoreFlash，视图重建清理旧壳，整个DriveView Dispose再替换后安全重绑，活跃恢复壳存在时由实际Session.Dispose先释放，然后才释放view/world。
- 原生证据 `evidence/weapon-icon-session-2026-10-15T10-50-24-988Z/`：43/43功能断言，Lua/资源错误0。整体 **FAIL**：frame2 303.132ms、frame3 1374.53ms、frame5 1414.8ms 超过原100ms阈值；未放宽性能阈值。夹具无渲染viewport，`scene_stalled=true`，不作为图像或持续性能证据。原生进程已退出，临时脚本入口已清除。

## 生命周期结论与边界

实际生产 `PlayerViewSync.Update` 先为最终活着的CarUnit做Rebuild/Bind，`TrialSession.Tick`再Consume恢复事件，之后CombatView才清理共享列表；当前顺序符合光壳依赖。VehicleView.Clear/Dispose会清空visuals，旧壳Drop比较visual identity后才恢复pop，因此本批真实重建和整视图替换未访问已销毁native节点。TrialSession.Dispose先Dispose光壳，再Dispose玩家view和world，联合夹具已覆盖。

此保证依赖该所有权和顺序：不能先销毁整个Scene然后调用FX.Dispose，不能在已Dispose旧view且未Consume新view之间调用FX.Update。开篇当前替换后必须在首Tick先Consume再Update，保持这个顺序；本批没有擅自改变共享控制器。

## 冻结指纹与未关闭项

模块SHA256：`E4435F10BAAA1E551EB01F3FCB6553790301942B6B66F8B48A77716AE9DC920F`。

联合夹具SHA256：`D9351F6ED60788F4703F2AF17181C7F13868AF307D24532A7E298AC80A38869E`。

同一新不可变Web包真实冷入口仍OPEN：现有加载验收在 `app.loader.options.resources` 检查 `For(entryBlueprint:List())` 每项均包含；实际gate完成后再检查每路径可用；随后自然受损读取Hurt图标时不新增下载失败/请求，并对照开篇换装和PC/20:9。本批测试后端、磁盘存在或原生缓存不能替代这项。

## 统一包依赖复核（2026-10-15）

只读核对最终候选 `.tmp/outgame-cached-1792062486110/dist/1.0.0/manifest-264a138b.json`：54/54文件通过，范围为19个设置/入口/开篇/恢复模块、32个normal/Hurt武器图、RestoreFlash.shader及IntroComic的2张网点PNG。每项manifest、payload、size、当前工作文件与冻结快照SHA一致；19脚本均匹配identity；`http://127.0.0.1:4308/game-dist/assets/`返回54项HTTP200且字节SHA一致，manifest refs无未解析项。没有改构建或生产文件。

冻结基线branch `2026-10-14`，commit `2b169a9964645f5f346a7158bcb14447f040814a`，sourceContentSha256 `227ecd10517b3cf55b0af5800d8250d9a1033e55702d87f1509d93c01d88e6d4`；targetCommit `ad72080b262f93cf87ff464ae2ad72e5b10e2d89`；scriptFingerprint `7a31c714de0dfaa6147cdbe65152b8f5e4ab0a40a53b943146fded6fef62a356`。

16项包内静态接线存在：统一HUD/建造设置、TrialSession Esc入口及dialog内PollKeys Esc、Hangar/Opening装备图标依赖、RestoreFlash创建/Consume/Update/Dispose和两个shader门禁、IntroComic绘制/释放、IntroTerminalFx背景/投影。此为依赖和字节审计，不能替代shader实际编译、自然恢复效果、冷网络加载与所有流程验收。root另报告同包Web设置PC18/18、20:9触屏14/14、errors0且三Esc经过PollKeys，运行证据由root维护。本节不声明全1:1、真机或持续性能通过。
