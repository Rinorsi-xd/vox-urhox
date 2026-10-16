# 14f 开篇连续性时间线与证据边界

本轮只对齐已有证据，不改生产代码、不重新运行 GPU、不将未完成项标为通过。

## 固定构建与结论

- H5 基线：`2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`。
- 目标提交：`9541dc59ef2f281cafa5126762a57550189e04dc`，含工作区迁移改动。
- 构建：`manifest-14f59378.json`；指纹：`8e0db284b925572d0a10249309ac7de9dffdd79ab920de8cfac1e8cd18cffa7b`。
- 自然开篇流程功能 PASS：54 项检查，游戏错误 0，无 OOM，关闭 CLOSED。
- 连续性 FAIL：音频回调最大间隔 705.065 ms，9 个饥饿候选；RAF 最大间隔 650.5 ms，4 次超过 250 ms。RAF P95 为 66.725 ms，P99 为 100.09 ms。
- 该次运行包含截图和方法计时包装，不能当作无插桩性能基准，也不能作为移动端性能结论。

证据：`evidence/intro-natural-web-1600x900-manifest-14f59378.json`、同名 `.log`、同名 `-audio-timeline.json`。

## 回大厅窗口的精确对齐

时间原点 `1792095439875.55`，浏览器 `timezoneOffset=-480`。下表均为 2026-10-16 北京时间；浏览器事件用 `timeOrigin + at` 换算。

| 事件 | 本地时间 | 证据 |
| --- | --- | --- |
| 进入 gate | 04:22:37.724 | 原生日志 2875，frame 8569 |
| 最后一次开篇 F8 | 04:22:44.064 | 日志 2896，frame 8946，gate age 6.3384 s |
| 第一段迟滞 RAF | 04:22:44.244860 至 44.511735 | 266.875 ms；对应 longtask 44.245175 至 44.523175，278 ms |
| 第一段音频回调迟滞 | 04:22:44.238335 至 44.585975 | 347.64 ms |
| 首次真实大厅控件探针 | 04:22:44.577 | 日志 2897/2898，frame 8958 |
| 最大 RAF 间隔 | 04:22:44.795300 至 45.445800 | 650.5 ms |
| 对应最长主线程任务 | 04:22:44.796935 至 45.429935 | 633 ms |
| 最大音频回调间隔 | 04:22:44.795550 至 45.500615 | 705.065 ms |
| 音乐下载组完成 1 项 | 04:22:45.345 | 日志 2899，frame 8961 |
| 大厅音乐装载成功 | 04:22:45.427 | 日志 2900，`hangar-03-service-interval`，compressed=true，3122198 bytes |
| 大厅 F8 | 04:22:45.433 | 日志 2902，frame 8962；教程未显示，voicePlayed=0 |
| 教程下载组完成 25 项 | 04:22:45.814 | 日志 2903，frame 8970 |
| T-01 已显示并播放 | 04:22:48.052 | 日志 2905，frame 9104，voicePlayed=1 |

最大冻结发生在真实大厅控件已经出现之后，应归入回大厅窗口。RAF/音频中的 `shot:"gate"` 是旧标记：测试的 mark 只在 opening 模式更新，最后标记停在 318275.585 ms，进入大厅没有刷新，不能据此认定冻结仍发生在 gate 动画中。

回调周围 AudioContext 都为 running，过渡时 peak=0，冻结后回调集中恢复。这证明回调饥饿，不单独证明说话音节丢失。教程 25 项资源完成晚于最大冻结，不能将该冻结直接归因于首句 T-01 装载。

## 可疑工作与尚不能确定的根因

该窗口发生了显著资源释放：44.064 的 resourceBytes=253740635、Lua=103865.415 KiB；45.433 降到 82227022、38518.916 KiB，模型从 83335061 降到 16309957 bytes，数组纹理和 Image 归零。48.052 教程 resourceBytes=83312096、Lua=39881.871 KiB。

`scripts/app/HangarApp.lua` 的 `ReleaseSettledAssets` 连续调用完整 GC、RenderTargetLifetime.Flush、environmentBakeCache.ClearCache、资源释放回调；DeferAssetRelease 等待 3 帧。App.Update 先推进 ResourceGate 和音乐，再检查待释放资源。现有日志没有各释放操作的开始/结束时间，不能划分 GC、渲染目标退役、环境缓存、原生资源释放各占多少时间。

`scripts/audio/MusicPlayer.lua` 的下载完成回调同步 GetResource('Sound')、创建 SoundSource、Play、Fade、Played/Save、PauseBus，最后才打印成功。下载组完成至音乐日志约 82 ms，处于最大 longtask 内，但不能证明整个 633 ms 都由音乐解码造成。

44 至 46 秒窗口没有 shader BeginLoad/compile 日志；最后一条 shader 编译日志为 04:21:04.312（日志 2510）。所以本次最大迟滞不能认定为首次 shader 编译，仍未测量的驱动或原生工作也不能排除。4 条 Windows .7z 回退 URL 404 没有证据与该晚期冻结直接相关。

## 插桩口径更正

`identity.combatProfile=false` 没有关闭开篇方法包装。`tools/migration/probe-outgame-web.lua:140` 的 MeasureOpening 仅检查 ready/session，770 行在 opening 时无条件调用；包装了 session Tick、world、Bullet、车辆、AI、效果、页面渲染和音频更新。

实际 F8 明确含 openingTiming 和 `timingInstrumentation: QA instance method wrappers; Time:GetSystemTime milliseconds; includes wrapper overhead, not an uninstrumented performance baseline`。例如末次 gate 累计 sessionTick 1791 次/72277 ms/max160 ms，vehicleStep 36423 次/37507 ms/max65 ms。顶层 methodTiming 仅根据 combatProfile 判断为无包装的说明不准确，不能以此重写为性能通过。

## 下一次最小验收

先修正开篇插桩开关，再在现有测试工具中窄范围计时：GC、RT Flush、环境缓存清理、资源释放回调，以及音乐 GetResource、Play、Save 和 ResourceGate 完成回调。随后对同一包做无截图、无内存采样的自然回大厅比较；保留原流程、画面和音频，不引入新页面。当前结论仍为功能通过、连续性未关闭。

### 下一批最小实现：同一曲目的准备与播放分离

只读调用链已确认：`IntroSession.Finish` 先 Dispose（停开篇音频、关页面、调用 host.Dispose），host.Dispose 当帧销毁开篇场景并安排 3 帧后的资源释放；然后 host.Finish 重建大厅 UI。开篇期间 App.Update 给 MusicPlayer.Update 传 hidden=true，CanPlay 阻止 Next。冷启动首次大厅曲目因此直到回厅后才 Choose，再经过 Gate 下载和同步 GetResource/Play/Save；没有预先准备的大厅音频。若重播开篇前已有同组当前曲目，保留并恢复该曲即可，不能强制换歌或归零。

最小候选改动限于现有 MusicPlayer 与 OpeningHost：在现有开篇 boot 加载页、对白播放前，把必要的首次大厅曲目保留在当前播放器的同一 pending slot 中；Gate 完成只标记字节就绪，随后在加载阶段准备 Sound，持有强引用。恢复大厅时复用这个 slot/track/sound，执行原 Play、2.4 秒 Fade、Played/Save，不再选择或同步装载一次。加载阶段不创建正在播放的 source、不推进音乐时钟、不写 last/history、不提前从 bag 移除曲目、不改变 enabled/volume/unlocked/userPaused/hidden。保持两槽上限，已有合法 current/pending 不另行分配。

资源准备可沿用 `audio.StoryComms` 与 `audio.UiSound` 的现有模式：字节 Gate 后先 GetExistingResource，缺少时 BackgroundLoadResource，再跨帧读取已有资源。这不是后台能力已被证明无卡顿的结论：Web 的 MP3 结束装载、首次 Play 是否仍主线程工作必须实测。prepared Sound 的强引用是否确实跨完整 GC 与 ReleaseAllResources(false) 存活，也须在同包验证。不能因为预下载完成就认定解码完成。

曲序与取消要求：同一次准备只选一次，Next 消费同一预定曲目；延后到实际开始播放才 Played，失败走原 failed/retry，Clear/切组/手选曲/Dispose 必须令旧 token 失效，晚回调不得播放、污染新 pending 或修改存档。不能为预热调用 Choose 两次。Choose 会生成 bag 并调用共享 math.random；提前选曲会改变全局随机调用时点，因此不能声称与旧包同种子时逐首 ID 完全相同。若要求连旧包这一点也严格不变，保留原选曲时点，仅预取候选字节，并把选定 Sound 的准备安排到现有回厅加载遮罩内；代价是仍需验证加载遮罩中的同步费用，不能擅自改成固定首曲或预载整个音乐库。

验收限定：先记录 GetResource、Play、Save、GC、RT Flush、ClearCache、release 各段耗时，再做同路线无截图比较；检查完整开篇、重播已有音乐、禁音/暂停/未解锁、快速取消/Dispose/迟到回调、同一 track 的一次播放提交、历史/曲袋只提交一次、两槽内存上限及 GC 后资源留存。没有这些数据前，只能称候选减碰撞方案，不能将 633 ms 全部归因于音乐或宣布连续性关闭。本批没有实施生产改动，也没有新增前端或 GPU 运行。

## 打捞工具修正的边界

同包自然打捞上一轮停在工坊购车前，游戏错误为 0、正常关闭；工具寻找旧按钮“放进新车位”，而真实打捞商店按钮是“购买整车”。现有工具仅改成点击真实按钮，继续原有“用仓库里的零件拼”对话流程；若车库已有同名车辆则优先正常选车。未改玩法、注入车辆、库存、坐标或时钟。

冻结包 `UI/SalvageRules.json` 自带 `testFill:999`，`SalvageLobby` 据此填充库存。999 库存与该购车路线只能证明功能流程，不能作为真实账号、实际赚取库存或经济平衡的证据。完整自然搜刮与撤离仍待主任务按同包重跑验收。
