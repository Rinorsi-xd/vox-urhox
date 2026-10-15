# LA02 安全重置接续

## 当前接续位置

- **18:02 最终统一包20:9窄复验完成，生产冻结**：`manifest-e1faa514.json`，fingerprint `11c223a54d66f2d77161e9134cd385494dc600c81926526a3aaa36dd0a270a15`，QA4307，只做真实T入试车→物理tap捕获→真实R显示读条→真实R清理，**6/6 PASS、运行错误0**。证据 `evidence/practice-web-manifest-e1faa514-2026-10-15T10-01-08-429Z/report.json`。实际打开 `20-9-r-progress-css-pixels.png`（840×378），读条约180 CSSpx宽、视口中心下118 CSSpx、13px文案，确认不再被UI.Scale=.7缩成70%；这属于显示几何与可见性核对，不宣称逐像素完全相同。完整取消/完成/冷却21项仍归属于下述561包，未改挂新manifest。新旧包生产脚本差异仅`ui/ResetProgress.lua`由主代理核实；本轮没有继续修改生产代码。浏览器检查进程exit0且finally释放。自然翻车触屏翻正、真实狭窄空间、真机持续性能仍OPEN，不能以本专项替代。
- **17:57 CSS像素修正已冻结，等最终Web图**：仅 `ui/ResetProgress.lua` 改围绕视口中心使用 `pixel=graphics:GetDPR()/UI.GetScale()`，保持源码全部13px字体/3px字距/118px偏移/180×3细条/阴影/光晕CSS常量。SHA256 `D52AD43E1DAA0365008495E3DE722D8E7740BDB7F4E7097051119D0D9DDDB55A`。最终原生 `evidence/safe-reset-2026-10-15T09-57-21-546Z/` **42/42、Lua/资源/engine0**，实际UI.Scale1/.7两张图已打开，视口中央+118px、180px宽条保持；100ms阈值未改，但g4功能浏览器并行，**不能据此签独占/真机性能**。`.7`样例显式`UI.Layout()`，旧漏Layout导致根尺寸未更新证据09-56-34原样保留。生产与临时入口均已释放。下一包只用 `VOX_QA_CASE=20-9 VOX_QA_VISUAL_ONLY=1` 检真实T→R图→取消；561输入通过不改挂到新manifest。
- **17:53 真实Web功能通过，移动样式窄差异OPEN**：统一 `manifest-561eef79`、fingerprint `d8ce9ddb44253bd039e60e4ee33941bb30d6dfdbc8c41881a03b363a32023165`，QA4305，`check-practice-web.cjs` 正常T入试车、物理点击捕获、真实R取消/完成/4秒冷却拒绝，PC1920×1080 **10/10**、20:9 840×378 touch **11/11**，运行错误0。证据 `evidence/practice-web-manifest-561eef79-2026-10-15T09-50-37-892Z/report.json`，两张 `*-r-progress.png` 已实际打开，组件可见。**20:9 UI.Scale=.7 导致本组件13px/118px/180px被缩为9.1px/82.6px/126px；原版 `_resetBar` append body 是CSS像素，不在#ui缩放树。此窄差异已交root，生产冻结下未私改，不签移动样式精确1:1。** 车实际正立，情景触屏翻正按钮未自然出现，保持OPEN，无状态注入。浏览器均finally关闭。首轮15秒等F8超时证据保留，实际还在118.5MB启动下载，不能归因R功能失败。
- **17:47 已冻结**：最终既有 `retained-post` 隔离入口专项 **39/39功能PASS，Lua/资源/引擎错误0，100ms阈值下整体PASS**。证据 `evidence/safe-reset-2026-10-15T09-47-14-135Z/result.json`。实际打开 `reset-progress.png` 核对：中央下方原文案、3px细线、半程蓝色光晕可见，无额外底板。实际原生窗口1740×921，不能冒充16:9/20:9专项。主代理已接共享生命周期；后续仅做统一包真实Web输入与两比例验收，生产冻结。
- 2026-10-15 17:40：`SafeReset`、`ResetProgress` 已实现并由主代理接入共享 `TrialSession/DriveHud`。专项 **38/38功能PASS、Lua/资源0**，证据 `evidence/safe-reset-2026-10-15T09-40-20-733Z/result.json`；5条100–122ms尖峰使整体FAIL。截图实际打开后发现被启动全屏加载页覆盖，**此轮不能签HUD视觉PASS**。仅修隔离截图夹具，等待root统一构建/浏览器窗口结束后复验，生产冻结。不重启G0。
- 底层 API 原生探针 `evidence/reset-overlap-probe-2026-10-15T09-35/result.json`：5/5 功能 PASS、Lua/资源错误0；100ms 阈值尖峰令整体 FAIL，不能当性能通过。

## 固定基线

源分支 `2026-10-14`，提交 `2b169a9964645f5f346a7158bcb14447f040814a`，只读快照 `.tmp/outgame-source-2026-10-14T10-09-50-505Z`。

行为逐条对应 `three/src/drive/testDrive.js:791–894` 的 `_beginReset/_tickReset/_safeSpot/_resetBar`；地图射线 owner 语义对应 `shared/drive/trackSim.js:240`。未改源仓库、武器能量、车体尺寸和100ms验收阈值。

## 已实现与接入契约

| 项目 | 原版规则与实现 |
| --- | --- |
| 输入与时序 | `Begin()` 开始1.2秒读条；再次调用取消；完成后4秒墙钟冷却。死亡中止。`session.resetChan/resetReady` 给现有触屏读取。 |
| 安全历史 | `Update(dt)` 每渲染帧一次，模拟时间间隔严格大于0.5秒，位移严格大于1.5米，最多24点；支撑条件包括轮、悬浮、机械足、空速大于15。`upY>.87`。 |
| 历史回退 | 从新到旧，点龄至少1.5秒、距当前2.5–60米；落脚点重新检测。 |
| 附近搜索 | 半径0/5/9/14/20/28/38米，除原点外各12方向；维持当前yaw。全部不符时按原版半径原地抬升。 |
| 地面检测 | 当前车身高+60向下160米；法线坡度不得超过25度；拒绝车、靶、锥桶、碎片等可交互对象屋顶。迁移版把静态地图也登记owner，显式放行ground/obstacle/sign，保留原版语义。 |
| 体积检测 | 使用真实Bullet `PhysicsWorld:GetRigidBodies(queryBody)` 全车OBB窄相检测；bounds中心与原版yaw经镜像坐标转换。检测体禁用、layer0、trigger、无事件，永不参与求解器；排除自车与传感器。没有用AABB或若干射线代替。 |
| 执行 | 只取消钻头并调用主代理提供的 `session:ApplyResetSpot(spot)`，由其Place并同步插值；不补充武器能量。 |
| 生命周期 | `Clear()` 仅取消读条，保留冷却/历史；`ForgetHistory()` 显式清历史；`Dispose()` 幂等释放查询节点、读条及历史。 |
| HUD | `ResetProgress.Attach(session,root)` 加入现有UI组件树，不独立创建NanoVG上下文。原版500/13px、字距3px、中心下118px、180×3细条、蓝色光晕、原文案，不加底板；禁止拦截输入。 |

## 验证入口与边界

`tools/migration/verify-safe-reset.ps1` 最终运行16帧专项（早期12帧），底层几何、射线、旋转、传感器、斜坡、三角网格全部走真实Bullet；时间与历史使用隔离session，不能代替玩家物理键盘自然操作或Web/真机验收。检查包含实际HUD截图，需打开PNG核对。失败原样保留。

最终wrapper复用仓库已有 `tools/migration/entries/retained-post.lua`（仅设置验证窗口inactive FPS120），临时复制到 `scripts/_safe_reset_check.lua`，退出finally立即移除，不启动真实机库。100ms阈值未改变。两次旧真实main启动证据保留：首轮38/38、第二轮39/39均被启动加载页遮挡；第二轮 `evidence/safe-reset-2026-10-15T09-43-38-761Z/` 有8条100–123ms尖峰。最终隔离PASS仅适用于该专项，不能消除真实启动及场景的性能问题。

仍需主代理同构建验收：真实R按键和触屏、暂停/复生生命周期、Place之后视图插值、地图真实狭窄空间、16:9及20:9最终显示。源码专项通过不能替代此链。
