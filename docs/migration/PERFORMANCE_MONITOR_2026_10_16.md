# 实时卡顿监控与复现

本轮只增加诊断，不调整车辆、AI、物理步频、画质或战斗规则。H5 对照仍为 `2026-10-15@b276064942ae09c0227ec28d4cfda1d5ff006455`，UrhoX 构建父提交 `25149307e790b7799d40012d02e1b67a6af09ab7`。

## 试玩方式

普通游戏入口（没有 QA 玩法注入）：

<http://127.0.0.1:4471/outgame.html?-game_url=http://127.0.0.1:4471/game-dist/&-log=info&cached=1>

- 自动开始记录，分别正常进入匹配和剧情，按平时操作复现即可。
- F6 显示/隐藏右上角面板，隐藏不停止记录；点击面板标题可以折叠。避免占用编辑器 UI Inspector 的 F9。
- F10 记录 `user-mark`，卡顿恢复后可立即按一次，便于关联操作。记录本身不要求按键。
- 正常退出或切场后等约两秒再关闭页面，给异步日志留出发送时间。浏览器强退或进程崩溃可能丢失最后一批尚未发送的记录。
- 面板显示帧间隔、FPS、近期 P95、最大帧间隔、超过 80ms 的帧数、固定步数量、Lua 耗时和内存、最耗时段、车辆/弹丸/特效数量。

## 记录内容

整帧间隔采用本次 Update 到下一次 Update 的真实时钟差，并分别保存 Update 到 EndFrame 的 `wallMs`、被测 Lua 总耗时 `scriptMs`、EndFrame 外部间隔。超过 80ms 的帧自动记录完整分段；单次被测调用超过 80ms 时另记 `longSpans`。

分段覆盖加载提交/预热、固定步、物理积分、车辆/悬挂/腿部/机翼、武器与 AI、破坏/碎块、表现同步/特效、驾驶与战斗音频、HUD、显式 GC。慢帧附带前 15 帧、剧情任务与步骤、匹配状态、地图、车辆和零件数、弹丸数、补步/丢弃时间、资源内存与后台加载状态、保留的大厅/预览/开篇状态及运行错误。

每一帧保存所有被调用分段的名称编号、总耗时、自身耗时、调用次数和单次最大耗时，按秒批量输出。用 `stageNames` 字典和 `stageTimes` 数字数组避免每帧反复复制阶段名称和对象。零毫秒但有调用的阶段也保留，表示低于整数时钟分辨率；不是没执行。日志包含采集丢弃数量、跨帧协程排除数量和部分监控维护耗时。面板每 0.25 秒刷新。

## 日志落盘

网页必须通过带 `--perf-monitor` 的本地服务运行。该服务将 Lua 记录、浏览器超过 80ms 的 longtask、页面异常、可见性变化写入：

`docs/migration/evidence/performance-live/<服务启动时间-进程号-随机值>/`

目录包含构建 `identity.json` 和按会话区分的 `session-*.jsonl`。实时查看实际目录及成功写入数量：

<http://127.0.0.1:4471/__vox_perf_status>

Lua 面板中的 `performance/...` 是 Native 日志标识；Web 不在引擎内存文件系统重复写一份。Web 真正持久化位置以上述服务状态接口为准。普通部署页若没有收集器，只有 console 输出，不能保证刷新后保留。

Native 在运行时可写目录下的 `performance/` 写 JSONL，约每秒 Flush，单段 8MiB、每会话最多 16 段，达到上限会显示错误，console 继续输出。网页发送队列限 4MiB，拥塞、重试、丢弃均显式记录，不保证无限日志无损。

停止后汇总某个会话或整个目录：

```powershell
node tools/migration/analyze-performance-log.cjs "实际日志目录" --frames
```

生成 `performance-summary.json` 和逐帧分段 CSV，按地图、剧情步骤、匹配及加载阶段分组，列出 P50/P95/P99、慢帧及 self/inclusive 热点。旧版日志没有逐帧分段时会标记 unavailable，不能倒推出未保存的数据。原始 JSONL 保留以便复核；不要只提供平均 FPS。

## 归因边界

- 这里测量真实时钟经过时间，不是线程 CPU 计数器，也不是 GPU timestamp。包含子调用的时间不能相加，优先看 `selfMs`。
- `unattributedMs` 不等于 GPU 耗时，可能包含 UI 绘制、引擎、驱动、等待等；外部间隔还可能包含浏览器调度、后台限帧。会记录可见性供排除。
- `monitorMs` 是已单独计量的维护成本，不包含所有包装器、上下文、UI、传输的开销。监控构建不替代关闭监控后的性能验收。
- 跨帧 yield 的整个调用不计作连续 CPU 工作，其内部同步被测分段继续计时。Start 前的模块加载只能记录浏览器总停顿，无法由 Lua 逐段归因。
- 音乐准备、存档后台任务和部分 UI 绘制仍归上层或未归因；遇到这些热点后再按实测细拆，不猜测瓶颈。
- 当前桌面功能验证不代表骁龙845在 TapTap 内持续30FPS达标。也没有宣称本轮修复了所有卡顿。

## 冻结构建与验证

- 最终逐帧冻结目录 `.tmp/outgame-cached-1792155052577`，`manifest-6bafddc3.json`，537 Lua；脚本指纹 `d18bd5d3ae0a3f41edd0f4eccfd0199284a04b3ce518290f8792dfa63cfbd82a`。逐字节包检查见 `evidence/performance-monitor/package-check-final-frames.json`。此前 `0ebcf612` 是 F6 修正包，尚未包含每帧完整分段。
- `verify-performance-monitor.py`：46项行为检查、537 Lua语法通过。覆盖嵌套 self 时间、协程、异常、多返回值、时钟回绕、场景回收、停止恢复、逐帧字典/归零/零毫秒调用和尾样本。
- `check-performance-web-logging.cjs`：真实 HTTP 落盘、同源/大小/队列限制、重试去重、未改启动 URL、异常和尾样本解析均通过。此脚本中的性能记录是夹具，不是游戏性能。
- 前一冻结 `1dc62aae` 的真实 Chrome 启动/面板/F10/日志8检查通过、错误0、日志截断/丢弃0。截图见 `evidence/performance-monitor-web-1792154178066/`；该包使用 F9，不能用于签最终 F6。
- `0ebcf612` 最终 F6 普通页8项通过，实看显示/隐藏截图；`1dc62aae` 真实匹配13项通过（实际入场、倒计时、开战、正常返厅、资源释放、错误0）。两者不用于签逐帧增强包。Native90ms人工睡眠夹具实测91ms，JSONL落盘及读回通过，见 `evidence/performance-monitor/native-check.json`，此记录也是增强前版本。
- 旧剧情入场实测到原始第一步、玩家可操控且采样完整，但runner最终状态仍RUNNING、进程会话中断，不能将这次标记完整PASS。原证据 `evidence/story-natural-s1-manifest-0ebcf612-2026-10-16T12-45-06-111Z/` 保留，后续用增强包重新验收。
- 逐帧增强包实测结果在本节后续记录；不以单独计时夹具替代完整战斗验收。

重跑最终普通监控入口：

```powershell
$env:VOX_PREVIEW_PORT='4471'
$env:VOX_PREPARE_FILE='.tmp/outgame-cached-1792155052577/identity.json'
node tools/migration/serve-outgame.cjs --perf-monitor
```

不要让收集器增加或重新编码引擎 URL 参数；引擎启动前曾因额外参数触发 WASM 越界，当前收集器完全不改 URL。完整 G0–G6 开放项沿用原验收清单，本轮不重开阶段。

## 已有日志里的真实帧

下面取自本会话桌面自动匹配功能验证（6辆车），不是用户旧4350页面的测量，也不是隔离帧率基准。日志会话 `20261016-2041...` 的精确文件为 `evidence/performance-live/2026-10-16T12-40-29-802Z-45796-4d6ff5/session-33786b7521c16556b4a19f61.jsonl`，按 frame 可复核。

| 帧 | 完整间隔 | Lua分段合计 | 固定物理步 | 实际工作（self，不重复相加父调用） |
|---|---:|---:|---:|---|
| 3886 | 43ms | 25ms | 3 | 步态4ms/6次、悬挂采样3ms/18次、Bullet3ms/3次，另有车体/腿碰撞/显示/环境/音频/HUD |
| 3909 | 56ms | 38ms | 4 | Bullet7ms/4次、AI6ms/20次、腿更新4ms/8次、车辆self2ms/24次、武器1ms/24次，其余18ms为其他Lua分段 |
| 3924（退场附近） | 88ms | 60ms | 0 | 显式GC44ms、瞄准线5ms、环境4ms、HUD3ms、相机2ms、其他2ms；EndFrame外另10ms |

43ms一帧约23FPS，56ms约18FPS。这些已采到的帧表明，多车固定步补跑和GC都值得排查；不能据三帧认定整局唯一瓶颈。前两帧分别还有约18ms未归入Lua（含EndFrame外1ms），未归因部分不能直接叫GPU。现有日志没有用户旧端口的运行证据，因此不能声称解释了其全部卡顿。

特别核查3924前后：3916–3924的steps均为0，3925进入loading cover；rules仍标live不等于正在持续模拟交火。`gc.Step`没有 `app.ReleaseSettledAssets` 父标签，结合两个生产调用点，支持 `RenderTargetLifetime.Step` 退休纹理回收路径。记录未包含退休队列和具体纹理，不能归因到某张图或认定为持续战斗唯一GC瓶颈。

## 逐帧增强包实测

`performance-route-match-1792155375988` 已完成真实大厅→匹配→倒计时→开战→手动前进和开火；117项分段及运行检查PASS，111帧在测试窗口直接断言，最终落盘汇总开战阶段126帧。全部126帧可恢复各段，收集器parse/dropped/oversized/sendFailures均0。实看 `active.png`，面板当时24FPS/42ms/Steps3，不宣称流畅。对应会话目录 `evidence/performance-live/2026-10-16T12-52-31-528Z-4828-82ffc4/` 的JSONL、汇总和CSV。

| 项目 | 每帧平均 | 说明 |
|---|---:|---|
| 完整帧间隔 | 54.55ms | 中位46ms，P95 91ms，126帧短窗口 |
| 已测Lua合计 | 34.07ms | 不能叫精确线程CPU时间 |
| Vehicle.Step | 13.43ms | 包含悬挂、腿、接触与推进等子段，不和子段相加 |
| Bullet物理积分 | 4.83ms | 每帧平均3.07步，总387步 |
| AI | 1.89ms | 各AI所有补步累计 |
| 其余Lua | 约13.93ms | 总Lua减上述三个互不嵌套部分；包括武器、表现、环境、音频、HUD等 |
| 帧间隔减已测Lua | 约20.48ms | 含引擎/驱动/UI/等待及监控等，非GPU计时 |

车辆子段按self平均：步态3.24ms、腿控制1.90ms、悬挂施力1.92ms、悬挂采样1.83ms、腿命中盒1.72ms。另有表现更新1.38ms、武器1.35ms、Effects.Update1.34ms、环境1.83ms。1ms整数时钟对许多短调用分布会有量化误差；30–40ms散落在不同scope的尖峰也可能包含GC/调度，不能把某个scope最大值直接认作算法自身成本。

这一短窗口已确认“Lua负载+多补步”的问题，不足以签长期帧率或手机性能；下一步应在用户实际复现会话中确认同一热点，再对腿/悬挂/命中盒及回收分配做保持玩法等价的对照。不要先减AI数量/改物理频率来隐藏开销。

最终同包剧情 `performance-route-story-1792155622415` 已实际进入第一关、接管输入、前进开火，188项运行及逐帧格式检查PASS，182帧直接断言，截图实看。不是整关通关验收。解析/发送/oversized/drop计数均0。精简归档 `evidence/performance-monitor/final/` 含两条真实路线的原始记录选段、原日志SHA256、检查摘要、逐帧CSV和截图，可离线复核，不含人工生成计时值。

Git归档保留原始选段与检查摘要/截图，CSV与派生summary在本地已生成，其他部门可从归档的 `match-active.jsonl` / `story-active.jsonl` 用上述分析命令重新生成。

监控扰动另做4轮真实Native六车/Bullet平地对照，固定seed、180预热/1200计时步，无渲染/地图/AI/开火。disabled为1875/1179ms，enabled为1639/1429ms，启用含真实Attach/Context/包装器及内存JSON编码，未包含落盘/UI/浏览器传输。两轮顺序差异方向相反，热机和调度噪声明显，不能将平均差0.0058ms/步称作“零开销”，也不能将第二轮增加0.208ms/步当确定扰动。四轮最终车辆/telemetry与32个RNG尾值完全一致，证据见 `evidence/performance-monitor/overhead/`。桌面插桩值只用于定位，再用关闭监控后的同场景对照确认优化收益。

此前遗留工具变更（home-route投影、HTTP hash、巨型车和打捞数量验收脚本）一并保留；已检查语法和监控相关HTTP路径，本轮没有重新签巨型车/打捞交易完整浏览器验收。
