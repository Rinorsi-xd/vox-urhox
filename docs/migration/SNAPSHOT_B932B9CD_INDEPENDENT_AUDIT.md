# b932b9cd 独立包审计

**后续真实运行判定：FAIL，不可交付。** root 的同包释放后取消测试复现黑屏与恢复死锁。下文的离线身份检查仍成立，但不构成功能通过；后续工作区修复不属于 b932b9cd。原报告和截图保留，详见末尾增补。

继续现有 G0-G6，未重启阶段。本批仅独立审查、执行离线工具和整理证据，未修改生产代码，未提交或推送。

## 唯一包身份

- H5：`2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`。
- 快照：`.tmp/outgame-cached-1792081345365`。
- manifest：`manifest-b932b9cd.json`。
- 脚本指纹：`b4b4b349d6a7635a6b610f245510ebaa139bb58d927ab45f4bd54b7db03dc53b`。
- targetCommit 字段：`9541dc59ef2f281cafa5126762a57550189e04dc`；本包包含未提交增量，具体代码以逐 SHA 和指纹为准。

## 实际完成的检查

| 范围 | 结果与边界 |
| --- | --- |
| Lua 身份 | 源码、快照、identity、manifest 各 478 项一致；实际发布的全部 478 个 Lua payload SHA 也一致。manifest 共 7465 文件。 |
| 既有离线证据 | 13 份报告中的 63 条生产文件 SHA 全部匹配；初审 3 条漂移原样可见，实际重跑原工具后为 0，不以修改旧 hash 代替执行。 |
| 结算工具重跑 | `check-combat-result-production.py` 13005 项通过；实际执行 MVP Skip/Update 和 Matchmaker，HangarApp/MatchHud 仅记录接线文件 SHA，不能宣称这两个文件完整行为均验证。 |
| 竞技动作工具重跑 | `check-match-actions.py` 103 项通过；实际 MatchActions 与观战数值、接线文件语法检查。实际浏览器输入、自然死亡/再匹配仍另验。 |
| 本批切场生命周期 | `check-web-map-transition.py` 114 项通过，实际执行过渡状态机、HangarApp 进场/释放/Update/Reload/Stop/PostUpdate 及 SceneLoader Cancel/Fail/Commit。恢复回调中的 Install 与原生资源、UI、renderer 使用替身。 |
| 发布依赖 | 459 个启动资源预载及 payload 完整；Track 253、Crater 540 个冷入场下载依赖可解析。Crater 按需下载。 |
| 原始纹理字节 | 13 个 CPU PNG.bin 与 RGBA16F LTC 原始发布字节一致；12 个地形原 PNG 与 sidecar 未重复打包。 |
| 并发新增资源 | 新 Readback、WebMapTransition 均发布且 blocking。Minimap JSON/bin 和 Boundary/AimLine/RestoreFlash shader 的实际发布字节匹配快照。13 个小地图 runtimeChecks 对实际包 payload 全匹配。 |
| 小地图烘焙 | `bake-match-map.cjs check` 1147 输入通过；13 个 runtimeChecks 的 LF/CRLF 变体均验证可接受，包含新 Readback 依赖。 |

未发现本批确定的新增切场所有权缺陷。WebGPU 无同步读回时，现场小地图捕获明确降级纯色底、存档缩略图捕获返回失败；Crater 烘焙有效时仍使用完整底图。这是平台能力边界，不能签缩略图或其他地图底图等同 H5。

## 仍然未关闭

- 旧包第三次入图 OOM、严重帧率和冷加载 FAIL 保留，离线通过不证明这些已解决。
- 本包真实连续三次匹配进出、释放后取消与完整恢复、故意失败恢复仍待浏览器验证。
- 自然整局、完整剧情/音频连续性、全页面视觉、真实账号、编辑器及手机/M1 持续性能仍不在本次签收范围。

## 证据

- `evidence/unified-snapshot-manifest-b932b9cd-audit.json`
- `evidence/web-map-package-b932b9cd-audit.json`
- `evidence/web-map-transition-offline.json`
- `evidence/combat-result-production-offline.json`
- `evidence/match-actions-offline.json`
- `WEB_MAP_TRANSITION_2026_10_16.md`

## 真实取消失败与后续修复审查

root 真实进入队列、退役旧机库后按 Escape，恢复 boot 加载的 `pageFrames=0` 不再增长；`released-0.png` 是空白。工具由 root 在确认死锁后停止，尾部 TargetClosed 不是自然通过。证据原样保留：`evidence/map-cancel-manifest-b932b9cd-2026-10-15T16-25-26-606Z/report.json` 和 `ROOT_CAUSE.md`。

独立代码核查确认根因：`GarageHud.Dispose` 清空当前根节点；实际引擎 `UI.Render` 在 `root_==nil` 时立即返回，注册为 global component 的 LoadingPage 也不能绘制。离线 114 项使用的 UI 替身未覆盖这个引擎 guard，因此漏掉了真实阻塞。

g4 工作区修复 `HangarApp.lua` SHA `ee1177c4d5dfb4e4206f6dc3d72067b198456e1231a4e1708fdb5f71ab8ef496`：Dispose 旧机库 UI 后立刻安装全屏 `pointerEvents='none'` 轻根节点。审查未发现它接管后续游戏 HUD：实际 DriveHud/GarageHud 都以 `SetRoot(...,true)` 替换并销毁该根；较晚释放 BuildHud 时仅清除其自己的旧根。

独立重跑并加强 `audit-loading-root-lifecycle.py`：**13/13 PASS**。实际抽取并执行引擎 `UI.SetRoot/UI.Render`、LoadingPage.Render、ReleaseMapHangar、BuildHud.Dispose、DriveHud/GarageHud 的 root 安装语句，覆盖 root=nil 复现、加载页呈现、恢复三帧栅栏、晚到/重复旧 HUD 释放及新 HUD 接管。主生命周期 **122/122 PASS**。原生对象、完整 HUD 构造与实际绘图仍用替身；这些是后续工作区离线证据，**不抹去 b932 真实 FAIL，也不等于新包浏览器恢复成功**。

新增证据：`evidence/loading-root-lifecycle-offline.json`。下一步须固定新包后重验真实取消恢复与非空加载页，再验多次进出/OOM。
