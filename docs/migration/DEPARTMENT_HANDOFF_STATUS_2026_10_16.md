# Department Handoff Status / 2026-10-16

## Main 集成同步

- 用户最新明确要求“同步更新一下main分支”；本轮据此提交并推送迁移集成版本，尚未通过的稳定性条件继续保留。
- 同步前本地及实核GitHub `main`：`9541dc59ef2f281cafa5126762a57550189e04dc`。本说明随新集成提交交付，最终提交以Git main记录为准。
- GitHub同步目标为 `backup` 远端的 `main`；不触发Maker提审或发布。
- 本地 `origin/main` 跟踪引用仍为 `dc2527ca9fd9`，不能代替上述远端实核。
- H5 基线：`2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`。
- 当前候选：`.tmp/outgame-cached-1792130289040` / `manifest-eb4f7ad2.json`。
- Lua fingerprint：`70f6957345a9c29a803744d5bdbe0a9e1707cc484862ba3b1b81e92661ad1960`。
- 已验候选构建在提交前生成，包内 `targetCommit=9541` 是构建时父提交身份；本次提交纳入其对应生产脚本及必要资源，不借提交重新标记旧运行证据。

## 验证边界

- eb4f 已有构建、HTTP 实际身份/manifest/main 载荷检查通过。
- `evidence/unified-snapshot-manifest-eb4f7ad2-audit.json`：524/524 Lua、132 报告/779 关联、0 漂移。
- 上述审计证明载荷与报告关联新鲜度，不重新执行所有行为，不签视觉、可闻音频或性能稳定。
- 大厅环境音独立乘 0.5；源 480 cases、102 检查、4 负控已通过。eb4f真实运行单声部amount约0.06992，返厅重新播放；主观听感与音频连续性仍未签收。
- 旧包已有 S1 S级、S2 B级自然通关；旧 bb6e S5 8 检查/0 错误、Boss/结局/返厅功能通过。
- 旧包结果不能代签 eb4f、片尾新动效、同构建五关回归或逐帧视听连续性。
- OPEN：S3/S4 完整自然成功、eb4f 首次匹配声音、长冻结/音频间隙、旧 S3 WASM OOM 与战斗慢帧。
- OPEN：全视觉 1:1、无尽/打捞完整自然成功、账号恢复、移动真机持续性能与发热。
- S4自然 session65800已exit1/CLOSED：INCOMPLETE，1324样本/9阶段/5入口与返厅检查通过/运行错误0；540秒指令期限内完成A/B的夺点、反扑和涂鸦，12真实击杀/8死亡，第三处C未完成。已正常返厅且地形数组为0。root实看entered/deadline图；不是整关成功，也不能凭时限判第三处生产关卡故障。此轮GPU已结束。
- eb4f实测首次刷3敌时Tick峰值153ms；持续窗口BeforeStep均15.30ms/Tick、World.Step均3.91ms/Tick，固定步追赶2.79步/Tick，详见 `G3_EB4F_S4_RUNTIME_STABILITY_2026_10_16.md`。计时有嵌套和观测开销，非隔离GPU/真机性能结论。

## 部门运行与必纳内容

在已安装 UrhoX / TapTap Maker 的环境打开项目根目录，入口为 `scripts/main.lua`。
编辑器提供 SDK、内置 urhox-libs 与引擎资源；本仓库不携带这些安装目录。
`.project/settings.json` 的运行打包根仅为 `../assets`、`../scripts`；同时交接四份有效 `.project` JSON。
保留现有 `asset_ignores`，尤其离线地形 PNG/sidecar 与冗余模型排除；不把它们直接改成全部打包。

本轮快审发现未跟踪 `assets` 767 项、`scripts` 119 项，均含 `.meta`；正式整理时重新枚举。
仅 `git commit -a` 会遗漏它们。必须纳入实际引用的新增 Lua、资源配置、二进制与对应 `.meta`：

- `OpeningRetirement`、`WebMapTransition`、`GameAmbience`、`MatchRadioDSP`、`EpilogueMotion` 等模块。
- `Combat/AmbienceSounds.json`、`Combat/MatchRadioDSP.json`、`UI/Sounds.json`、`Story/Mission/ResultVoices.json`。
- 环境音/UI 音效、12 条结算语音、TV-cut 低通 WAV、红色图像及配置、修复符号字体和许可/来源说明。
- `Sounds/BattleRadioDSP` 的 349 WAV + 349 `.meta` 合计约 70.14 MB，为运行 stem，不能误删为调试产物。

## 缓存快照身份

eb4f `identity.json.engineSources.mode=downloaded-snapshots`；以下为实际缓存 manifest 内容 SHA-256。
版本/client 来自该身份及 `tools/migration/cached-engine-sources.cjs`，不是当前 SDK 安装版本或在线 stable 检查。

| Source | Version / Client | Manifest 内容 SHA-256 |
| --- | --- | --- |
| engine-startup | 1.0.29 / e0c42c86 | `f54a09156e78aaea039588cb64496b9f3ce28576b64b3cf618998aea9bc804a7` |
| engine-res | 1.1.925 / 60b25079 | `ec118a86c9502fd53e002bf979aac57bd7d26dcd29112c870a70925756f27dfa` |
| urhox-libs | 1.0.47 / 64f47a38 | `046a4bb53d1555f290c3c9214aff0509261ab64e8604d2b52bdb375607cfaf6a` |
| official-res | 1.32.37 / 153a2b71 | `dad0759d73f68858b3805483f05ce7fec45b19874e0d998acc748f747ef8a398` |

身份中的 `manifest` 字段为 HTTP 缓存键，不能误称上表内容哈希。现有配置使用 `stable`，不锁定上述版本。
`evidence/cached-engine-packages-offline.json` 的 archive 审计覆盖 engine-res 1085 项、urhox-libs 159 项及 18 HTTP 检查；不代表新机器同环境。

## QA 与归档

`.tmp/outgame-source-*` 冻结 H5 源只用于导入/对照，游戏 `scripts/` 与有效 `.project` 配置无此运行依赖。
QA/importer 存在 `baseline.snapshot` 的 D 盘绝对路径、C 盘 Playwright 路径和 `.tmp/nav-python-deps` 依赖。
本地 Web 预览另需 `.tmp/web-engine`、prepare/构建快照；原生预览脚本需另装 `.cli/UrhoXRuntime.exe`。
这些是恢复 QA/预览环境的条件，不是 Maker 项目必须提交的运行素材。
`.gitignore` 已排除 `.tmp`、`.build`、`dist`、`.cli`、本地 SDK、保存数据及 `docs/migration/evidence/`。
不要整包纳入缓存/调试产物；需复核的报告和必要证据应单独归档并附身份、恢复路径与环境说明。
Windows 系统字体有存在性检查及打包字体回退，不依赖原机器的个人字体路径。

本次按明确要求同步main供部门集成与诊断；已知稳定性阻断继续处理，本文件不授予发布或稳定验收状态。
