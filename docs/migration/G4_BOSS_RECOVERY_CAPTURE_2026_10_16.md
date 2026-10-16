# G4 第五关回收演出与漫画取景

## 基线与范围

固定对照 H5 分支 `2026-10-15`、提交 `b276064942ae09c0227ec28d4cfda1d5ff006455`，源快照 `.tmp/outgame-source-2026-10-15T12-35-57-243Z`。这批只处理第五关 Boss 的回收车运动、演出机位、取景时机和取景对象生命周期，不代表第五关或完整剧情已经验收。

源文件校验：

| 文件 | SHA256 |
| --- | --- |
| `three/src/battle/storyBoss.js` | `6bc7a822b0eba9112d505ef69bf22be955e7ff6007d9d16824d55db46991b4cb` |
| `shared/story/level5.js` | `5673f40f68cd1b57fdcb052e37a01827883d90bd52f229abc189594ce7a9934e` |

## 已修改

- `StoryBoss.lua:247` 对齐源 `FoxBoss.openDir`：24 条射线选择开放方向，忽略玩家车体，Boss 自身命中按无遮挡处理，并保留 0.5 米的换向阈值。
- `StoryBoss.lua:258`、`BossView.lua:110` 对齐回收车：沿开放方向从 62 米驶至 22 米，按地面高度、朝向和八秒 smoothstep 曲线运动。旧版固定斜角、六秒直线移动已替换。
- `StoryBoss.lua:434` 起对齐开场、倒地、逃生舱、回收车的眼点/目标点/插值；眼点与目标点先分别平滑，再按源逻辑处理相机遮挡。
- 取景触发对齐源方法：首次跪地 1.6 秒、大招开始 6.5 秒、倒地 2.4 秒、逃生舱台词后 0.2 秒。第二次跪地不覆盖首张图。
- 每个取景键单独排期，不再共用一个待取景槽；原生默认使用系统时钟，避免 cinematic 暂停世界时倒计时停住。
- 新增 `render/BossSceneCapture.lua`：复用最终 3D viewport 生成宽度上限 1280 的离屏纹理；手动更新三次呈现后解绑场景。没有从整个屏幕截图，因此 NanoVG HUD 不应进入片尾漫画。取消、重复 Dispose、延迟退休均沿用现有 RenderTargetLifetime。

生产文件冻结 SHA256：

| 文件 | SHA256 |
| --- | --- |
| `scripts/combat/StoryBoss.lua` | `227d5ca6c3e05f067529c58e94431d73289b689179bd202eb1bd75295d09dbef` |
| `scripts/render/BossView.lua` | `3a7ee634941773c1596c414727edde1989ddb2d82b90baf1a483d385033037a8` |
| `scripts/render/BossSceneCapture.lua` | `24b109c68434be02e98a8091d084c4d1d69c8319291041783a5f13c32944b5fa` |

## 已执行的离线验证

标准注册名：`story-boss-recovery`。报告 `evidence/story-boss-recovery-offline.json`。运行 `tools/migration/verify-story-boss-recovery.py`，其 Node oracle 实际加载并执行完整冻结 H5 模块，Lua 执行当前生产方法；引擎向量、相机、碰撞和绘制使用夹具适配器。

90 项通过：4 组开放方向、32 组回收车姿态、逃生舱/台词/卡车生成顺序、首次/再次跪地和大招取景 cue，以及无阻挡/墙/自身命中三组相机连续三帧对照。源 `look` 也实际执行，包含眼点和目标点平滑及遮挡；不是仅比较手抄公式。

负控都产生差异：修改前冻结包 81 处、六秒回收车 40 处、线性回收车 32 处、缺逃生舱取景 2 处、跪地 0.6 秒 1 处、缺目标点平滑 6 处。

本批后实际复跑八项既有检查共 9866 项：allies 3079、barks 754、combat-flow 1090、defeat 33、kneel-dialogue 1617、kneel 2178、waypoint 952、exposed 163。原报告保留在 `evidence/history/boss-before-recovery-2026-10-16/`。defeat 夹具新增固定 OpenDir=0，与其 H5 oracle 原本的固定方向一致；该项不声称覆盖开放方向。

## 原生取景验证与失败保留

标准原生注册名：`boss-scene-capture-native`。入口 `tools/migration/verify-boss-scene-capture-native.ps1 -ExclusiveNativeWindow`，只由 root 在独占 GPU 窗口执行；本子任务没有启动 GPU。

首轮 root 证据 `evidence/boss-scene-capture-native-2026-10-16T02-55-50-891Z/`：实际红色 3D 像素、绿色 NanoVG UI 的排除负控和 20/20 断言通过，但进程退出 1、validator FAIL，不能签成功。原因是 UI.Init 使用不存在的默认 NotoSans 字体；另有引擎初始化在项目资源挂载前读取默认 DDS 和缺失 Themis DLL 的错误，这两项也出现在较早 BossExposed/MissionTimers 启动日志。

已修夹具字体为实际项目 VoxIndustrial，runner 在启动时挂载现有项目 DDS 至 CLI 初始资源目录，并通过子进程 PATH 引用已安装编辑器的真实 Themis DLL。仅删除本轮创建的 DDS，保留已有文件；SDK 和 DDS 的来源路径及 SHA256 写入 manifest。没有改生产三文件、过滤日志或降低验收门槛。fixture/runner 的 SelfTest 1 正控、4 负控实际通过，未启动 GPU。

第二轮 `evidence/boss-scene-capture-native-2026-10-16T02-59-34-551Z/` 已取得 exit0、20/20、零错误及 before/after 哈希一致，但 stdout 日志桥在 shader 加载输出处截断，runner 未读到完成标记而失败。实际官方 Lua 日志存在完整执行记录；没有把该次 runner 失败改成成功。随后将 finish 延后两帧，并将 stdout 明确宣告的本轮独立 Lua 日志复制进 evidence，验证路径位于引擎日志根且创建时间属于本轮，再从该真实日志读取完成标记。

第三轮由 root 实际执行：`evidence/boss-scene-capture-native-2026-10-16T03-01-19-906Z/`，`validator.json` 为 PASS / PASSED、20/20、零 Lua/资源/引擎错误；manifest 为 exit0、未超时、输入变动为空。`script-log.jsonl` 含开始、红色 3D 中心 `(0.8039,0,0)`、绿色屏幕 UI 中心 `(0,1,0)`、完成标记和 `__VALIDATE_TEST__:PASSED|20:20:0`。本子任务只读核实上述文件并查看两张实际 PNG，确认其红方块/绿覆盖层与像素断言一致。前两次失败证据保持原样。

该次冻结夹具 SHA256 为 `7788c341b8901517f450e5179550c7bd786ede3736fae1bc36061bee7ffa4daf`，runner 为 `e97a0d4e48cb3bd38f45b09af04379f617b8b714db56638ff7220a49ec1b5b82`。生产三文件 SHA256 与上表一致。

原生夹具验收内容为：延迟分配、独立 key、1280 上限/屏幕比例、手动 surface、保持主 viewport、三次呈现后发布、detach 后冻结、3D/UI 像素隔离、取消、双重 Dispose 和退休队列清空。夹具使用简化 3D 场景，不能代替完整陨坑后处理管线或自然第五关验收。

## 仍需验收与已知差异

- 完整第五关自然流程：首次跪地、大招、击倒、逃生舱、卡车、片尾漫画连续执行，确认没有 HUD 污染、错误朝向、机位碰墙或场景释放回归。
- 陨坑自定义后处理最终 viewport 的离屏结果、GPU/内存成本尚未验证；简化场景通过也不能替代它。
- 源捕获额外使用 contrast 1.25 / saturate 1.2，源片尾还叠 contrast 1.08 / saturate 1.1。当前 helper 复制最终 viewport，尚未加这两层额外滤镜，不能宣称像素 1:1。
- 逃生舱模型既有旋转动画没有在本批重写。片尾页切换保留/淡出和 page shake 不在本批独占文件内，交由对应 agent。
- 90 项离线检查及 20 项原生夹具都不是整场流畅度、Web、移动真机或用户视觉验收。

## Freshness 映射

离线报告的 `productionHashes` 对应上述三文件；`inputs` 对应 `story-boss-recovery-source.mjs` 与 `verify-story-boss-recovery.py`。原生报告按每轮时间戳独立存放，其 manifest 记录同三文件、RenderTargetLifetime、fixture、runner、空入口、项目字体与 DDS 的 before/after 哈希，并要求运行中零输入变化。共享注册表、CURRENT_EXECUTION 和合包验证由 root 更新，本报告不替代它们。

统一审计使用的 `story-boss-exposed-offline.json` 也已实际重跑默认 checker：10 个源场景、163 项检查通过，四组负控有效，绑定当前 `227d5...` 的 StoryBoss。此前默认路径仍是旧报告，而上一次复跑写入了 `story-boss-exposed-production-offline.json`；本次纠正了注册路径。默认旧报告另存 `evidence/history/boss-before-recovery-2026-10-16/story-boss-exposed-offline-registry-before-rerun.json`，没有仅编辑哈希。
