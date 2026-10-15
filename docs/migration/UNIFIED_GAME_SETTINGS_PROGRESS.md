# 局内统一设置

2026-10-15：按用户新增要求把所有局内设置入口汇入同一原版暂停卡。原生PC实际控件38/38、触屏策略59/59通过，Lua/资源错误0；性能仍FAIL，20:9新包画面仍OPEN。root维护 TrialSession.Escape 与统一包Web验收，本专线维护面板、HUD和触屏入口。

## 接口与行为

`ui.GameSettings.Open(owner)` 暂停输入并打开原 `PauseMenu`；`Attach(session,root,top)` 在所有 `DriveHud` 模式提供同一个“设置”入口。`DriveHud.buttons.settings` 为新引用，`buttons.audio` 暂留同一控件别名供已有调用兼容，不存在第二个声音入口。旧 `AudioSettings.Attach` 也委托给统一入口。

原暂停卡480参考宽、原SourceButton/字体/动效/滚动继续使用。局内可见“继续”与“返回车库”，声音/画质/触屏子页完成后返回设置；只有继续按钮调用一次Resume。返回车库仅设现有 `wantsReturn`，由实际会话的打捞退出/结算门禁处理，不从UI直接销毁战场。原模式介绍、PC帮助、建造保存/返厅与触屏专属操作继续保留；大厅教程不在活战斗上重启。

root接线：已接管第一Esc释放输入，未接管第二Esc打开GameSettings，有弹窗Esc关闭后仍释放输入，避免松鼠标直接返厅。声音/画质/触屏子页及返回不请求Capture。

触屏操作菜单保留传送/出生点、竞技战绩、无尽维修/下一波/改装等模式专属动作，新增统一设置，移除原内嵌触屏设置副本。进入设置时关闭触屏菜单但不先Resume，避免立刻捕获后又释放。触屏建造“设置”及PC建造OpenPause走同一入口。

## 文件范围

新增 `scripts/ui/GameSettings.lua`；修改 PauseMenu、DriveHud、AudioSettings、GraphicsPanel、TouchSettings、TouchDriveControls、TouchBuildControls、SourceTouchOverlay、DialogHost，以及 `scripts/app/BuildSession.lua` 的OpenPause单行。没有改 HangarApp/OpeningHost/TrialSession。GraphicsPanel只补与现有Pause/Audio一致的ref1080/紧凑ref600局部缩放、返回和resize，未改渲染参数/渲染代码。

顺带修复实际入口隐患：TouchSettings原先改值无条件调用 `owner.hud.Refresh()`，DriveHud没有此方法；现在清触点、失效触控relayout，并仅在有Refresh时调用。DialogHost.Notify增加局内app.toasts后备，避免局内模式介绍/画质保存通知访问不存在的message对象。

## 原生验收与边界

独立 `verify-game-settings.ps1` / `check-game-settings.lua` 使用实际TrialSession、DriveHud、PauseMenu、AudioLevels、GraphicsSettings与真实UI Pointer/Key分发，覆盖Esc→设置→声音/画质→返回→继续→原返厅请求；触屏覆盖触控设置存档与原操作菜单/无尽专属按钮。记录截图及实际viewport，不把参数请求等同实际窗口。

- PC证据：`evidence/game-settings-2026-10-15T11-01-44-332Z/`，38/38，Lua0、资源0，首场景初始化100ms阈值失败（见result.json）；已打开menu/audio/graphics截图检查，控件无明显重叠。
- 触屏策略最终证据：`evidence/game-settings-2026-10-15T11-02-37-185Z/`，59/59，Lua0、资源0，1685.13ms首场景初始化尖峰，100ms阈值保持FAIL。已打开menu/touch截图，全部卡片边界在viewport内。截图与实际交互是原生触摸PointerEvent分发，不是真机操作。
- 两次实际物理窗口均1740×921、DPR1；PC逻辑1740×921；触屏策略逻辑1020.20×540、UI缩放1.70556。请求1200×540未改变引擎窗口，因此不能签20:9/compact分支。需要root的统一Web包1200×540及1920×1080实测。
- 试验夹具使用真实TrialSession和世界/车/相机；存档使用记录型内存后端，音乐播放器是接口替身；GraphicsSettings实例真实，但app.ownsScene=false，避免设置测试改动渲染。声音/画质数据和存档调用已验，不能等同发布端实际听感/渲染即时变化。
- 无尽按钮检查为真实TouchDriveControls加spy控制器，验证维修、下一波、改装的分发；不等同无尽完整战斗和返回门禁验收。

历史失败保留：11-00-11首轮仅8条（逐帧Update覆盖atFrame回调，证据无效）；11-01-54触屏47/49（同帧换卡点击未布局、手动结束模态后触控容器仍blocked）。夹具已把Update注册移到显式回调前，触屏换卡隔20帧并按生产HUD行为解除blocked；最终没有改生产逻辑来规避失败。

root后续修正PollKeys在dialog存在时仍允许Esc关闭。上述38/59使用的是直接Escape方法，不验证PollKeys这一层。夹具现已补KeyPressed注入经过真实PollKeys的开→关→再开、typing保护和模态阻挡T，但该delta未再跑原生；root统一Web脚本连续三Esc承担最终验证，不能把旧38/59归到此项。

旧 `check-touch-drive.lua` 依赖被移除的 `layer.settings` 已更新为实际TouchSettings数据控制器；原无关失败证据保留。root更新Web声音检查的统一入口路径，避免继续期待“声音”按钮直开子页。

20:9新包实际入口、compact滚动与控件布局、发布端设置即时生效/跨启动持久、每个模式返回门禁、真机持续性能保持OPEN。触屏设置原有“对准自动开火”标签在当前截图右缘偏紧，未声明像素级样式一致；按源样式核对留到新包布局验收。

## 同包真实 Web 增量

`manifest-264a138b.json` / QA4309：PC1920×1080 **18/18 PASS**，20:9触屏840×378、DPR3 **14/14 PASS**，运行/探针错误0。证据 `evidence/audio-settings-web-manifest-264a138b-2026-10-15T11-09-46-846Z/`。已实际查看两比例设置菜单PNG，卡片及文字在viewport内。

真实鼠标/触屏入口、声音三路控件、完成返回设置、继续保留车辆与场景均通过；PC连续三Esc依次释放鼠标、打开设置、关闭设置，始终保留试车，已覆盖PollKeys修复。声音卡尺寸与既有冻结源实测参考差小于1.5px。该脚本未新增每模式完整返回门禁、触屏子页全部控件和跨启动云端恢复；并发浏览器结果不作性能证据。
