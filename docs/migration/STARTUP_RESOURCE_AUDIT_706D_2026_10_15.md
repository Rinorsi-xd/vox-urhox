# 706d 首启资源分类与可实施调整

本轮是对已固定运行包的只读资源审计。没有修改生产脚本、资源配置或 metadata，没有启动其他 native/browser，没有重新烘焙地图。当前运行、构建与是否实施由 root 统一控制。

## 身份和证据边界

- 游戏包：`manifest-706d3d0b.json`。
- 文件：`.tmp/outgame-cached-1792072535275/dist/1.0.0/manifest-706d3d0b.json`。
- 当前 QA/普通预览：4328/4329，以各自 `/identity.json` 为准。
- 源基线：2026-10-15，`b276064942ae09c0227ec28d4cfda1d5ff006455`。
- 真实 Web 证据：`evidence/combat-performance-2026-10-15T13-56-49-208Z/`。console 记录 Found 3547 preload files、Need to download 3545 files (119.2MB)，下载成功 3545、失败 0。
- manifest 的本地资源字节是构建尺寸，不是 GPU 内存，也不等于压缩传输体积。以下计数包括图片旁的 XML 等文件；特别标注的实际图片/音频除外。

游戏 manifest 共 7439 条、7434 本地资源、5 跨源引用，本地总计 861,666,579 B。metadata 标记 boot 625 条/30,768,625 B，另有 config 1 条/47 B；这不能当成实际启动的 3545 条/119.2MB，因为启动还涉及 blocking、引擎资源和共享库。

本地 boot/config/blocking 的去重并集是 2451 条/59,525,084 B。使用已缓存 engine/libs/startup manifest 试算得到的启动并集与真实 console 总数仍不一致，因此本报告不把静态试算冒充实际下载队列。精确拆出引擎贡献、同 hash 去重和目标变体体积，仍需捕获引擎最终队列或实际网络请求。

## 已经延后的内容，不再重复实施

| 内容 | 全组文件/字节 | boot | blocking | 当前结论 |
| --- | ---: | ---: | ---: | --- |
| Parts/Models | 605 / 59,518,048 | 0 | 0 | 已以 bin 按当前车辆/入口加载 |
| Parts/Rigs | 336 / 290,388 | 0 | 全部 | 小体积装配数据，不能与模型下载混算 |
| Intro/Images | 28 / 40,600,434 | 0 | 14 / 4,508 | 14 张实际图片 40,595,926 B 已延后 |
| Intro/Audio | 55 / 22,423,153 | 0 | 0 | 已由 IntroSession 入口门禁 |
| Story | 374 / 33,447,766 | 0 | 21 / 216,553 | 大部分剧情媒体已延后 |
| UI/Parts | 1598 / 7,943,709 | 0 | 331 / 106,582 | 已延后缩略图主体 |
| UI/Prefabs | 152 / 16,922,564 | 0 | 76 / 24,472 | 已延后预制车图片主体 |
| UI/Faces | 16 / 22,120,435 | 0 | 8 / 2,576 | 已延后人像主体 |
| Crater | 526 / 170,131,796 | 0 | 188 / 8,614,120 | 大媒体延后，JSON/cube 等仍 blocking |
| Salvage | 857 / 272,752,699 | 0 | 36 / 1,095,744 | 打包总量很大，不等于全部首启下载 |

入口已有链路：`HangarResources` 组合大厅资源与当前车 `parts.Dependencies`；`HangarApp.WithVehicle` 在切车/操作前门禁；`PartAssets` 在 GetResource 前检查实际存在；`IntroSession` 门禁原图、音频、字体；`OpeningHost` 门禁陨坑、演员零件和特效；`StoryPage` 门禁人像、`StoryPageVoice` 门禁语音、`StoryHolo` 门禁选中模型；`Tutorial.Prepare` 门禁教程人像和语音。

当前 `.project/resources.json` 的 default `**` 保留全部可用内容，boot 已排除大型 UI/Parts、Prefabs、Modes、Salvage、Faces、Avatars、Music。不能仅切 enhanced reachability：本项目存在大量数据和拼接路径，未补全契约会漏运行资源。

## 字体：有明确重复项，但不能直接删 boot

本地 Fonts 13 条/20,080,030 B 均在 boot，其中主要是：

| 字体 | 字节 | 首屏/消费者 |
| --- | ---: | --- |
| MiSans-Regular | 8,122,324 | Help U+21C4 fallback、PartsGallery Text3D |
| MiSans-Bold | 8,009,316 | HangarCanvas 四块大厅面板，首屏可见 |
| SmileySans | 2,629,764 | SourceDraw 初始化、大厅面板 |
| VoxIndustrial | 1,028,972 | SourceDraw 标题和正文 |
| Barlow | 112,196 | SourceDraw 显示字、大厅面板 |
| VoxDisplayTabular | 111,528 | SourceDraw 数字字 |
| Chakra Bold/Medium | 24,336 / 24,360 | HUD |

`SourceDraw.Begin` 在加载页之前即创建 title/display/tabular/story/body/code 字体；因此不能把 Fonts 整组从 boot 移走。MiSans-Bold 是首屏内容，也不能用其他字体替换后宣称保持原版。

发现 pinned engine-res 与项目存在同字节 Regular：

- 项目 UUID `ELeauduyxGP3gKRqijtMiQpO`，hash `729d48cb`，8,122,324 B，boot/default。
- 引擎 UUID `CURqsaXDFUNd1JdtV4GY6WaO`，同 hash/同尺寸，full/default。
- 引擎 manifest 缓存：`.tmp/web-engine/http-cache/5b5cc23b8b446e2c0bdfa7c8099c7da610af93b675d45d36a8107eb2605b6521`。

可实施候选：让项目资源路径引用这个引擎默认字体，避免另保留一份项目字体。必须先确认构建后的 UUID/source 解析及真实请求是否已经按 hash 去重。8,122,324 B 是项目副本上限，不是已证明的实际下载节省值。若最终队列已去重，收益主要是项目包简化，不能承诺启动加快。

MiSans-Bold 也与引擎同 hash `0f2bab41`，但引擎文件属于 full，不属于 default；不能假定它已预载。需显式跨源引用并在首屏 gate 中保留，才有资格移除项目副本。

若改为真正延后 Regular，而非复用引擎默认副本，必须同时处理两处消费者：

1. `SourceFonts.ResolveHelpSymbol` / `SourceDraw.InlineFont` 目前直接读取并 nvgCreateFont，没有门禁；帮助页首绘前应保证文件已到。
2. `PartsGallery` 目前 gate 只有零件依赖，Update 直接 GetResource Font；应把字体加入该入口依赖。

本报告不修改这两条，也不建议用字体 fallback 改变原版样式。

## 可以继续缩小 boot 的 UI

| 分组 | boot 全组字节 | 非 blocking 媒体字节 | 现有门禁/缺口 |
| --- | ---: | ---: | --- |
| UI/Match | 690,434 | 686,892 | BattleController.Dependencies 已含两张 minimap mask；其他 MatchLobby 入口图由 LoadingFlow artGate 管理，仍需逐路径核全 |
| UI/WeaponIcons | 314,263 | 309,111 | WeaponIconResources.For 当前装备列表已接 TrialSession；需核新增武器和开篇图标路径 |
| UI/Touch | 173,163 | 173,163 | SourceTouchDriveWidgets 首绘直接取图，缺完整显式 gate |

这三类非 blocking 主体合计 1,169,166 B。它们可以继续延后，但收益不大，尤其触屏不能先排除再等待用户报告缺图。正确顺序是补齐所有入口依赖、在首绘前 gate、然后排除 boot，并分别验 PC 与触屏冷缓存。

`boot#refs` 不是直接 boot。它包含 199 项、metadata 23,951,602 B；本地已知 23,041,990 B，另有远端 Anonymous Pro 字体 909,612 B。相关本地主体包括 Hangar 14,054,184 B、UI 7,728,424 B、教程音频 600,371 B。按当前文档，媒体引用具备边玩边下语义；本次未抓最终网络队列，不把这些引用全部认定为首启下载。

## 真正 blocking 的大数据

本地 blocking 2327 条/30,470,959 B，其中 JSON 19,353,316 B、XML 4,464,523 B、cube 3,647,222 B、Lua 2,612,323 B、其余小模型与 shader。

| 文件 | 字节 |
| --- | ---: |
| Crater/Tonemap.cube | 3,647,222 |
| Crater/Boulders.json | 1,884,705 |
| Parts/Catalog.json | 1,322,127 |
| Parts/JoinedShapes.json | 1,164,586 |
| Intro/Intro.json | 921,096 |

仅从 boot 排除这些文件不会去掉 blocking。要真正延后，需采用非 blocking 容器（例如 bin）并同步导出器、读取器、所有依赖列表、烘焙输入和失效校验。Catalog/JoinedShapes 当前有启动期直接读取的消费者，不能单纯更名。Tonemap 又参与地图烘焙输入，不应为小改配置触发未经验证的全图重烘焙。

## 建议执行顺序与逐条验收

1. 优先完成当前 706d 的真实 prepare/activate 性能归因，确认 baked map 命中和音频分帧实效。资源总量审计不替代长帧归因，当前实际性能仍未通过。
2. 在后续独立小包验证 Regular 字体引擎复用：构建前后 manifest 的项目字体条目、跨源引用和实际请求字节可对照；帮助 U+21C4 和 PartsGallery 原字体显示正确；PC/Web 冷启动无字体 assert。只有实际队列少了才签节省。
3. UI 分组逐一补 gate 后排除 boot：冷缓存进入竞技、武器切换、开篇、20:9 触控，所有图标首绘前到位；取消/返回不会让迟到回调激活旧页。预期上限约 1.17 MB，不把它包装成主要提速。
4. 最后处理大型 blocking 数据的入口分包：先画清启动依赖图，再做单一文件族的容器转换和故障回退；分别验证首次大厅、陨坑、打捞、开篇、无尽。每项必须有旧包/新包同路径的队列、字节和最长帧证据。

未完成的边界：引擎最终下载队列精确归因、同 hash 跨源去重、真实手机/M1 性能、所有入口全冷缓存回归。没有将这些记为完成，也没有因完成资源审计签收 G0/G6。
