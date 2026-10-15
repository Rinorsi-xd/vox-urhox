# LA15 图层与共享接续

基线：`2026-10-14 / 2b169a9964645f5f346a7158bcb14447f040814a`。接续G1–G6，不重开G0。普通e1faa514仍为上一包，本文件生产候选尚未进入该包。

## 图层顺序

- 冻结 `shared/ui/reticle.js:219` 先插入scope再frame；`MechReticle.Render` 已改成先Scope再Gauges/Compass/Weapons/Center。原坐标、倍率和字体不变，不挪动原版本身接近同基线的横屏RNG/EN。
- `evidence/hud-unification-2026-10-15T10-06-44-751Z/result.json`：753/753功能通过，Lua/resource错误0；实际绘制记录证明RNG输出早于EN。狙击镜PNG已打开，公共HUD仍可见。
- 整体仍FAIL：100ms阈值下15次尖峰，最大489.257ms；阈值未放宽。此专项不是实际Web或手机性能通过。

## 公共生命周期

- 新练习玩家链使开篇准备也先建立PracticeSession。IntroBattle替换阵容时现显式Dispose并断开旧practice，世界feedbackPlayer改指真实演示玩家，避免保留已销毁的占位玩家和误用练习重置。
- `check-intro-montage-pool.lua` 已补真实PracticeSession→IntroBattle→原431件角色池所有权检查，`check-intro-host.lua` 补实际host断言；新独立wrapper `verify-intro-player-transfer.ps1` 用时间戳保留报告与100ms阈值，尚待原生窗口。
- 新wrapper已实跑：`evidence/intro-player-transfer-2026-10-15T10-21-55-679Z/result.json`，23/23功能断言PASS、Lua/resource0；整体FAIL，3个100ms尖峰（5520.588/100.135/105.054ms）。这是准备/装配池专项，不能当自然播放或音频连续性证据。stderr另有默认Cube/Day贴图与themis_x64.dll初始化错误，原样保留，不写运行零错误。
- root已按g5模块契约接恢复青光：实际PlayerViewSync之后、CombatView清事件之前消费；各rig更新后逐帧更新；第一人称/死亡显隐和会话先释放FX后释放view。新shader加入普通进场与OpeningHost资源门禁。专项与联合运行尚待。

## 导入来源

- `import-ui-source.py` 已从live `D:/Rino_Project/Vox/shared` 改为权威manifest的冻结snapshot，写任何素材前校验8份实际输入哈希。增加`--check-source`只读预检。
- 实跑预检8份全部通过，commit为2b169，无素材写入。字体metrics子工具改为ROOT解析snapshot，避免工作目录改变时读错文件。
- 没有批量重导字体/图标、没有改既有派生资源commit标签；全派生来源核对仍OPEN。

## 下一动作

等LA12、LA13/14和恢复FX负责人完成专项并冻结，完成共享联合检查，再固定一个新包做实际PC/20:9功能/视觉回归。原生队列g4→legacy→g5→root；不对旧失败覆写或冒签G0–G6全部完成。
