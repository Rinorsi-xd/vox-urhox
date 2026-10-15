# 敌车出生地面查询去重

## 范围与固定输入

本批继续既有战斗性能专项，未重启G0。活跃H5基线为`2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`。只修改`scripts/combat/EnemyDriver.lua`，生产SHA256为`83b69a70186132159b173dd3682a222a811edd933a6e873b66fc0dca6f425fd5`。未改世界、60Hz物理步、碰撞、冲量、伤害、思考间隔、AI决策参数或RNG调用。

前版本直接读取root不可变运行包`.tmp/outgame-cached-1792071037109/scripts/combat/EnemyDriver.lua`，SHA256为`a80937b818c099813b192e1dcc5f4fbc2ec9073af79811fbf78809cb5158f1b8`。本批不会修改该包或把新代码结果挂在04a原验收上。

## 依据与实现

已读实际Web证据`evidence/combat-performance-2026-10-15T12-30-38-464Z/match-live.cpuprofile`；主要函数为未符号化WASM，不能仅凭函数编号指认Lua热点。已有扣除协程挂起的实际细探针`evidence/combat-performance-2026-10-15T11-56-32-513Z/report.json`记录匹配live物理查询38754次/664ms、Think165次/211ms。这些包含探针开销、且方法耗时包含子调用，只证明值得减少重复查询，不代表当前包或手机耗时。

`EnemyDriver.Step`原来每次都调用`N.Height`，结果只被出生落地分支读取。该分支在`self.time >= 1`、不可移动或已有空投标记时不会读取地面结果。现在仅在`self.time < 1`、可移动且无空投标记时执行相同的12米静态向下射线，随后保持原分支表达式及全部执行顺序。

不是复用旧地面高度，也没有降低任何参与决策的查询频率。正常出生一秒后，每个有目标且有载具的敌车每个固定步省一条无效查询；8辆敌车理论调用量减少480次/秒，这是调用数量，不是毫秒或FPS承诺。真正出生落地、缺地面、空投、失能及复活计时边界仍走原决策。

## 离线等价与调用检查

工具：`tools/migration/check-enemy-ground-probe.lua`、`tools/migration/verify-enemy-ground-probe.py`。使用实际Lua5.4执行修改前与修改后的完整生产EnemyDriver、Think、Motion、Tactics、Nav、MissileWeapons，资源读取桥接实际`assets/Combat/Weapons.json`。身体和世界查询是可观测适配器，不是原生Bullet场景。

- 65种角色/行为场景，fallback与space两条世界查询接口，原10Hz夹具、60Hz固定步和混合边界步长，共70200步。
- 140793项前后断言通过：完整command/aim/trigger/info、保留状态、武器选择、RNG调用数值与顺序、保留射线输入/返回顺序均一致。只过滤已证明未读取的顶层地面射线；不是过滤所有向下射线。
- 修改前实际调用61380次无效顶层射线，修改后0次；需要参与出生判定的查询仍实际执行。
- 既有原JavaScript黄金23455项通过，覆盖11700帧原H5决策。该黄金的`shared/ai/driver.js`SHA为`c524a6f0ec0f80d002d46ca6425d66dec39140eeb4a99a593e811025c8fc2af6`，已与当前10月15日冻结源逐SHA确认一致。
- 增加空投标记交替、缺地面、能力表缺失/载重0、目标/载具缺失、时间重置到0和精确1秒等边界；没有只测稳定直行。
- 生产依赖9项在检查开始/结束逐SHA确认未变化。证据独立写入`evidence/enemy-ground-probe-*/report.json`，不覆盖旧失败。

## 验收边界与交接

本批已实现并完成离线功能与实际Lua调用数检查；未启动浏览器、native窗口、服务或更改当前运行包。没有实际Web帧耗、原生Bullet计时、GPU或手机/M1收益结论，不能将整体严重卡顿标记为解决。

主集成下一次统一新包应核对上述生产SHA，再在相同阵容/同路线比较live射线次数、固定步数及P50/P95/最大帧耗，同时重跑实际出生/空投、绕障、开火与击杀。旧04a验收和本批新代码各自保留身份。
