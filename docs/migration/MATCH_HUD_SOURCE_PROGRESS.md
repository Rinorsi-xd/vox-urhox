# 竞技 HUD 冻结源补齐

## 2026-10-15 横幅批

- 基线仍为 `2026-10-14 / 2b169a9964645f5f346a7158bcb14447f040814a`，读取固定 snapshot；不重开 G0。
- 根因一：冻结 `matchHud.js:12` / `endlessHud.js` 隐藏通用 `.dh-pause`，目标 DriveHud 却对竞技和无尽继续显示试车全屏黑罩。已按源模式排除，普通试车仍保留自己的暂停页。
- 根因二：旧 MatchHud 横幅只画 80% 宽实心黑块和两行字，品牌色取到全局 cyan，固定 3.2 秒；源是全宽多段透明渐变、80% 渐变色线、三行内容、逐通知时长、mini 与 3 条队列。
- 新 MatchBanner 恢复 24% / 150px 正常横幅、16% / 96px mini、76px / 44px 工业字标题、原 tracking / 阴影、tag 两侧短线、副标题、band / text / tracking 入场与 300ms 退场。
- ENGAGE 使用源 `#ffd36a`、1800ms；PAUSED 使用白线、1500ms mini。BattleController 的 36 组通知按源逐字段迁入，包含此前缺失的 pointLost、完整盾提示和推车文案。
- 采用真实时钟，HUD.Update 的模拟 dt 被截断或为 0 时仍按实际时间结束横幅；不会再因固定步追赶让提示长期盖住战斗。重开和结算清理队列。
- MatchHud 自己按源 compact 600px 高、额外 0.8 缩放；PC 保持 1920×1080 参考比例。
- DriveControls 对未接管鼠标的任意 PC pointerdown 请求 Resume，与冻结 testDrive 对应；touch 路由不变。
- TrialSession 的 PAUSED 精确 Escape 接点由 legacy_audit 负责；本批没有修改相机或输入生命周期。

## 离线验证

- `verify-match-banner-offline.py`：**1499 / 1499 PASS**，Lua 5.4。
- 源黄金不是重写预期：Node VM 真实执行冻结 `EliminationMode / ConquestMode / EscortMode.onEvent`，录制 36 组 banner 调用。
- 比较 text / sub / cls / ms / tag / mini 全字段；实际 BattleController.AfterStep 再执行相同 36 个事件确认接线；结算清队列通过。
- 实际 DriveHud.Create 在 battle / endless / practice × 捕获 / 释放六状态下检查 pause 显隐；实际 DriveControls 三鼠标键 / touch / 已捕获门禁通过。
- 实际 MatchBanner 绘图命令确认三行原字体、通屏 150px 高渐隐带、透明两端、两条80%宽2px色线及14px glow；没有通知时零绘制。
- 实际 MatchHud.Update 在 dt=0 但实时时钟已经超过1500+300ms时清除 PAUSED，通过。
- `evidence/match-banner-offline.json` 含固定源与五个生产文件 SHA256。未启动浏览器或原生窗口，不把离线绘图命令当最终像素验收。

## 下一批

- 已接手旧 MatchObjectives 的三节点环、完整占点牌、贴边标记和遗漏小地图，按同一冻结源实现。
- 横幅批先冻结交给 root 固定构建，下一批新模块先离线制作；不把未完成 UI 混进正在采样的不可变包。

## 2026-10-15 占点、小地图与击杀批

- MatchObjectives 按实际冻结 MatchSession._objectives 接入：点位 lift7、运输 lift6、原40px/110px贴边算法；world marker 不受 uiScale 缩放。进入点位后隐藏该菱形，改为 top178px /400px 三节点占领牌，沿用实际 BattleObjectives.InPoint（22m + 半车半径、8m + 车半径高度），不再使用旧16m门槛和70%高度面板。移除与 MatchTop 重复的推车进度条。
- 恢复原28px菱形、22px三段环、13px距离与运输状态、完整占点文字/两队数量、250ms入场。距离仍是源码 flat(XZ)，不是3D距离。
- MatchFeed 接实际 BattleController.RecordKill，显示双方姓名/队色/武器，最多5条、7秒删除、本人参与橙色背景；重开清空。源环境死亡不伪造击杀者。
- MatchMinimap 恢复236px显示/472px画布、33ms节流、玩家居中与死亡保持、北向、队友120m情报规则、源圆形/切角方形、要塞/路径/推车/点位/视野扇形/队友与玩家箭头。仅增加Chakra字体，不再复制一套MiSans上下文；离开HUD释放私有VG/纹理桥/RT。
- 当前小地图底图仍是源码已有的无底图fallback。真实一次性俯视捕获尚未收入此批，不能标记小地图完整1:1；URL minimap=square 偏好跨引擎桥同样未验。
- DriveOverlay 接 G4 音频 Kill(streak) / ScoreTick 和 TrialSession.ConfirmKill；22块积分粒子抵达分别播放tick，车型击毁避免重复hit确认，非车型靶板保留kill确认。连杀4.5秒使用realFrameDt，粒子仍用模拟dt。
- `verify-match-hud-detail-offline.py` **19890/19890 PASS**，80组预期来自真实冻结 `_objectives`，并验证原InPoint、投影、CAP文字、可见范围、圆方贴边、击杀列表、300分/22tick与慢动作连杀时钟。补执行实际Minimap.New/Update/Paint/Draw/Dispose，覆盖33ms节流、两种框、路径/点位、死亡位置保持、纹理桥复用与重复Dispose；这是隔离API夹具，不是原生调用。`evidence/match-hud-detail-offline.json` 记录本批8文件hash。此结果不代表引擎画面/移动真机/实际击杀全链通过。

## 实际Web发现的时钟修复

- 0b4790c3真实Web在MatchBanner.Now报参数类型错误；原离线stub误把实例API视为合法，未能发现。
- 按现有SceneLoader写法改成 `Time:GetSystemTime()` 静态单例，scripts全量搜索同类调用已清理；stub现明确拒绝GetTime实例方式，横幅1499项重验通过。
- 失败Web证据由root保留，修复包Web仍待root复测，不能以离线通过覆盖实际失败。

## 延迟击毁通知补漏

- 原版recordKill始终独立发送amount0/killed事件；目标旧TrackWorld只标记已有pending，而pending会在.25秒后清理。经源核对与root授权，改为实际metrics:Damage(time,unit,0,pos,true)，修复延迟坠毁等没有pending的反馈丢失。
- 新增实际RecordKill→TrialMetrics→DriveOverlay隔离链：有/无pending、伤害不增加、本人source过滤、300分/音效/ConfirmKill一次、下帧无重复。最新 **19904/19904 PASS**；证据现记录9文件hash，TrackWorld增量SHA `dd3ddddb3711c51ea1d356e00e22a760a34b8784e2ba1871098c629e52848ce5`。
- 其他8生产文件继续冻结；MapShot独立模块尚未接入，防止未经实测增加入场读回停顿。
