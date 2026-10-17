# 第一人称武器特效修复与验收记录

基线：冻结 H5 `b276064942ae09c0227ec28d4cfda1d5ff006455`（2026-10-15），登记在 `baselines/b276064942ae09c0227ec28d4cfda1d5ff006455.json`。这是视觉行为修复，不是帧率优化结果；实际 Web 截图与帧时间由同构建硬件测试另行验收。

## 确认的两处遗漏

1. H5 `three/src/drive/testDrive.js:1183` 的 `_fpBeam` 和 `:1191` 的 `_effects`：`cam.eye` 时不提交自己的 shot；自己的 beam 起点前移 `min(10m, 全长/2)`；自己的弹丸仅飞出 12m 后显示，飞弹为 6m，显示副本的 dist 同时减去这段长度，避免曳光尾部伸回相机。声音、后坐力等仍消费原事件。Lua 之前直接提交自己的全部事件和弹丸。
2. H5 `three/src/parts/weaponRig.js` 的持续电弧、充能球、环带、旋涡、粒子都挂在 head 后代，随第一人称车身一起隐藏。Lua `WeaponEffects:Batch` 创建的是 scene 下的独立节点，车身递归显隐不会隐藏这些批次，原先也没有单独接线。

## 最终修改

| 文件 | 行为 |
| --- | --- |
| `scripts/render/CombatEffects.lua` | 第一人称时按本车事件数组身份或显式 remote=false 过滤 shot、前移 beam；按弹丸对象身份仅裁剪本车近段。原事件和物理弹丸不变，远方车辆、未标记的 Boss/场地事件不变；普通视角直接返回原列表，不分配副本。Dispose 释放本车引用。 |
| `scripts/render/WeaponEffects.lua` | 增加 SetVisible，切换每个实际批次的 mesh.enabled。隐藏期间保留演出状态，完整 Update 不会重新显示隐藏批次；恢复只显示 count>0 的批次，不创建节点或补发粒子。 |
| `scripts/app/TrialSession.lua` | 当前 scope/group/pivot 由 ScopePivot 统一解析。Tick 在模拟前读当前输入，不依赖上一帧 firstPerson；PostUpdate 使用同一 pivot 放相机，随后同步隐藏车身和本车持续特效。死亡清除引用并隐藏持续特效，松开右键当帧恢复。 |

没有改变 shader、深度测试、相机坐标、命中、弹道、武器伤害、音效和震动；没有对敌方特效做第一人称过滤。H5 原有已经生成的瞬时特效在切镜时也不会被追溯删除，本候选保持该行为。

## 离线验证

执行 `tools/migration/check-first-person-fx.py`：**8 个源场景、295 条断言、8 个行为负控通过**。原始记录是 `evidence/first-person-fx-offline.json`，包含生产 SHA256 与源 SHA256。测试执行完整冻结 TestDrive 类中的实际 `_effects`，以及完整 Lua 模块的实际 Consume、Projectiles、Update、ScopePivot、Tick、PostUpdate、SetVisible、Dispose；渲染、输入、相机原生服务使用适配器。

- 完整长短/零长度 beam、12m/6m 严格边界与边界外 0.01m、原数据不变。
- 远方弹丸引用和次序不变，普通视角返回原数组；非战斗 nil remote 本车数组被识别，未标记 Boss/world 数组不会误判。
- 当前右键与旧 firstPerson 故意相反的首 Tick；松开、武器丢失、死亡、Dispose。
- 实际 PostUpdate 车身与独立持续批次一起隐藏/恢复；完整持续 Update 不会重开隐藏批次；完整 CombatEffects.Update 确实向 bolt/missile 渲染入口提交过滤后的列表。
- 删除 shot 过滤、近段裁剪、尾长扣减、beam 前移、持续批次隐藏、当前输入读取、Update 接线或 PostUpdate 接线，八个负控都会在对应行为断言处失败。

关联 `check-aim-fallback.py` 回归：43 条检查、6 个负控通过，车辆重建/重生后的引用更新仍正确。

关联 `aim-close-offline.py` 回归：63 个近目标、54 个 ADS 场景/648 发采样、20 个辅助瞄准、12 个准星状态、18 个相机回拉场景及3个负控通过；没有更改武器模拟公式。

## 真实引擎验收口径

相同构建公开进入 mapTest，对每个实际武器组分别截图普通、右键静止充能、右键持续开火、松开恢复；检查实际 shots 增长、camera/scope 状态、effects.firstPerson、本车各 WeaponEffects 批次 count/enabled，远方效果仍保留。必须检查画面中心覆盖和强光，离线断言不能代替这一项。

本报告不签收 Web/手机 FPS、骁龙845持续30帧、墙体遮挡、所有武器视觉1:1或用户视觉认可。不应把这次少提交近端特效自动当作性能达标。

## 真实 Web 本轮结果

- 旧 b2：`evidence/debug-settings-1792183692222/`，公开设置/调试进入试车，赤焰 GT 实际两组武器，开镜/连射/松开/公开返厅完整完成，错误0、浏览器CLOSED。`group-1-scope-fire-5.png` 实际显示贴近镜头的巨大金色枪口/曳光。功能检查PASS只表示操作完成，不表示旧视觉正确。
- 新包 `.tmp/outgame-cached-1792183721377` / `manifest-6f9297a9.json`，脚本指纹 `971222d85bc179b5bbff0bdc2f9a00409e4f50d766458cb99e1af4c223bef976`。三处生产 SHA 与离线证据一致，普通4525与专用QA4526实际HTTP身份、manifest、main及QA附加字节核对通过。
- 新包 `evidence/debug-settings-1792183832996/`：两组武器真实开镜、每组8次连续射击采样、shots增长、自车全模型隐藏、特效本车引用、常驻批次隐藏、松开引用清理与count>0批次恢复、公开返厅通过，Runtime/HTTP错误0、浏览器CLOSED。root已实看机枪连射、狙击连射及松开截图。新机枪同编号图中近镜金色光带消失，远方弹丸和命中火花仍保留。
- 当前车辆为机枪/狙击两组，不冒称 Web 覆盖全部武器或巨型T5车；其余边界由上述完整源/Lua模块对照覆盖。没有帧率A/B、真实手机或敌方自然交火的新增验收。
- QA4524/4526均已停止；普通4525保留新包供用户验收，4519旧包未改。此前一次HTTP审计在QA启动后probe新增时失败，重启独立QA后按当前附加字节复核通过，不将首次失败当作生产运行错误。

## 冻结后连续性只读复审

- 切镜不调用 Clear，不追溯清除已经产生的世界特效。H5 `TestDrive._effects` 只过滤当次 stepFx，随后仍执行 `Effects.update` / `WeaponFx.update`；当前 Lua 同样按剩余 life 自然消失，不能概括为“一两帧”。实际完整寿命：机枪枪口 flare 0.052–0.078 秒、T5 激光/狙击 beam 0.20/0.505 秒、T5 狙击尾迹 0.75 秒；狙击枪口烟 0.63–1.17 秒、导弹发射烟 0.56–1.04 秒、狙击命中烟 0.98–1.82 秒、导弹爆炸烟最长 3.12 秒、普通爆炸烟最长 2.86 秒、破块碎片 1.2–2 秒。剩余寿命取决于切镜时的 age；开镜后的命中、爆炸等事件仍可正常产生。这些寿命不证明它们遮挡了用户当前画面，也不是新增修复的根因判断；最新反馈没有对应截图，未知遮挡仍需真实定位。
- `CombatEffects:Projectiles` 只浅复制已越过近段的本车弹丸，并替换副本 dist；pos、vel、s、trail、seed 等仍保留原数据/引用。`MissileEffects.Update` 不读取 dist，不以 p 表作为缓存键；`MissileView.Add` 按每帧 count/slots 顺序设置模型位置、旋转和尺寸，不缓存弹丸身份。因此副本不会重置飞弹槽位、尾迹或物理状态。
- H5 `WeaponFx.update:396` 的飞弹渲染同样按 nm 槽位提交，读取原 p.trail；H5 的第一人称浅副本也不额外裁掉 trail 数组头部。本次保持这一既有表现，不擅自把飞弹6m隐藏规则改成新尾迹算法。

本节为实际调用链和数据读写审查，不是新增硬件测量，未修改三份已冻结生产文件。

## T5 缺失覆盖补验（2026-10-17）

`evidence/scope-fx-f1f7-t5-1017-c/report.json`：**PASS，8 项组检查，Runtime / HTTP 错误均为 0，浏览器 CLOSED**。root 已直接查看 laser / mg / sniper / missile 的右键截图：画面没有本车及近镜巨大环带遮挡。该结论覆盖本次受控测试画面，不代替用户视觉认可、敌方自然交火或全武器所有场景的 1:1 验收。

隔离包由普通冻结包 `.tmp/outgame-cached-1792193222299/identity.json`（`manifest-f1f7d033.json`）派生，补验包为 `.tmp/scope-fx-f1f7-t5-1017-c/identity.json`，manifest 为 `eb2ddbcb`。548 个 Lua 文件中仅 `main.lua` 追加 QA 后缀，其余 547 个生产模块均不变；三个修复模块 SHA 与上述离线证据一致。派生 main 的源文件、HTTP payload 和 identity SHA256 均为 `672a3009f86814eefa297460a664054ae168aec1b9df41a2f003996ddf73f1f5`。

为避免完整巨型工坊车加载干扰，本次使用明确标识的 **35 零件 QA 车架**：真实核心、30 个轻方块以及真实 `mg5 / laser5 / sniper5 / missile5`，实际 Blueprint / VehicleSpec 检查无重叠、四武器全部连通、dropped=0。普通 App 加载和 TrialSession、CarUnit、WeaponSystem、相机、渲染、音频保持生产接线。F7 仅在隔离 QA 中替换内存蓝图并进入真实试车，F6 在观察前摆放一个真实靶车并对准；没有车库存档操作，没有设置 `VOX_CLOUD_VALIDATION`。这不是公开入口或自然驾驶流程验收。

F9 仅请求只读快照，实际采样在生产 `PostUpdate` 完成车身遮罩后执行，每份快照记录 `samplePhase=post-update`。真实左右鼠标控制开镜和射击，每组保留普通、3 张右键连射、松开截图及对应 JSON。

| 真实武器组 | 普通截图累计 shots | 最后右键截图累计 shots | 右键自车可见模型 | 松开自车可见模型 |
| --- | ---: | ---: | ---: | ---: |
| laser5 | 1 | 22 | 0 / 92 | 92 / 92 |
| mg5 | 39 | 94 | 0 / 92 | 92 / 92 |
| sniper5 | 98 | 100 | 0 / 92 | 92 / 92 |
| missile5 | 100 | 114 | 0 / 92 | 83 / 92 |

上表为同一场连续测试中的累计 shots，不能相加当作独立场次总量。导弹使用真实锁定、开仓与齐射流程。12 张右键截图对应状态均为第一人称、本车武器归属正确、92 个实际本车模型全部隐藏。普通状态实际可见的 Band、Swirl、Ribbon 均先有非零 count 才允许进入检查；801 次右键 `PostUpdate` 观察中，隐藏批次的非零 count 最大分别为 **Band 4、Swirl 20、Ribbon 84**，mesh.enabled 违规次数 **0**。这避免了用未创建或空批次冒充隐藏成功。松开后仅恢复当时 count>0 的批次；已自然结束的旋涡或电弧保持关闭。

2026-10-17 独立核对原始 `missile-released.json` 与 `report.json` 后更正：导弹松开快照为 **83 / 92**，此前表格的 92 / 92 是记录错误。原 runner 的恢复判据是 `visible>0`、已退出第一人称、持续特效仅启用 count>0 批次，并未断言全部 92 个模型启用。其余三组松开快照确为 92 / 92。现有快照只记录 StaticModel 总数与有效启用数，没有这 9 个节点的名称、零件归属、姿态或弹仓状态，因此不能把差值归因于舱内导弹显隐，也不能判定为遮罩恢复故障；原始证据保持不变。

工具：`tools/migration/scope-fx-isolated-{observer.lua,prepare.cjs,run.cjs}`；离线最小车架验证为 `tools/migration/verify-scope-fx-fixture.py`。JSON 传输先校验有限数和引擎 encode/decode 完整性，再由接收端校验 UTF-8 字节数及 FNV32，分片不是完整性的替代检查。

### 保留的失败与更正

- `evidence/scope-fx-f1f7-t5-1017-a/`：FAIL / CLOSED，原因是 QA 把 Lua 空表编码的 `{}` 当数组调用 `widgets.find`；未进入武器检查，运行和 HTTP 错误均为 0。该工具错误已修复，不作为游戏或特效失败结论。
- `evidence/scope-fx-f1f7-t5-1017-b/`：FAIL / CLOSED，右键 laser 的状态在 `Update` 结束、生产 `PostUpdate` 尚未执行遮罩时采集，读到动画重新启用后的 **51 / 92** 个模型。旧 runner 随后先在 finally 释放左右键，再保存 `failure.png`；这张截图中的底部武器不能证明按住右键时发生渲染泄漏，也不能单凭中间态推断没有泄漏。c 将观察移到生产 PostUpdate 之后，并保证若组检查再失败，先保存 `*-scope-failure-held.png/json` 再释放输入。c 的后置状态和实际右键截图共同通过后，才关闭本次 T5 近镜遮挡验收。b 原始记录完整保留。

本次截图、轮询和受控摆放不构成帧率测试；没有新增 Web / 手机 FPS、骁龙845持续30帧、墙体遮挡或其他特效的性能签收。

### 当前普通包一致性

最新普通预览为4584，冻结`.tmp/outgame-cached-1792206583227` / `manifest-0baeef97.json`，三份瞄准修复模块仍与下述已验SHA完全相等。549份Lua及13关键模块实际HTTP字节独立核验见`evidence/independent-unified-0bae-4584-a.json`；同冻结派生的八车对局及返厅已PASS/CLOSED/0错误。这不是新增右键视觉测试，原四组T5/12图证据继续适用，不扩大未知遮挡验收。最新入口为`http://127.0.0.1:4584/outgame.html?-game_url=http://127.0.0.1:4584/game-dist/&-log=info&cached=1`。

较早的 2026-10-17 接续记录从当时服务的两个端口读取 identity、manifest 及三个实际 Lua payload：**4504 是旧包，三个 SHA 均不匹配；4582 的 `2a9723f0` 包三个 SHA 均与下面已验生产值匹配。** 当时普通验收入口为 `http://127.0.0.1:4582/outgame.html?-game_url=http://127.0.0.1:4582/game-dist/&-log=info&cached=1`。该检查只证明当时下载内容，不是新增视觉或帧率验收；旧4504仍可访问不代表它已更新。当前入口以本节4584记录为准。

只读复核：当前三份生产文件、普通包 `.tmp/outgame-cached-1792197751695` / `e119fabb`、上述 T5 c 补验包的 SHA256 完全一致：`CombatEffects.lua` 为 `57899721a52eff5e42a255bd3f7c9effcfe7daa27fb1f153582f6a33c18060f3`，`WeaponEffects.lua` 为 `36c9212e41faa10fac4c00f55ac48399f879fca5b645c551b00d65b14cc66a1d`，`TrialSession.lua` 为 `12d469b42c66eb570b4f3ab2f886010ffaae9718000a8795413a20759084afcf`。已验的是近镜本车持续批次、当次 own shot 过滤和近端弹道裁剪；这不扩大为所有世界瞬态、自然交火、墙体遮挡或用户当前未知遮挡已解决。

2026-10-17 本次独立接续再次实际 HTTP 读取 **4584 / manifest-0baeef97.json** 的 identity、manifest 和三个 Lua payload：上述三个完整 SHA256 均逐项等于当前磁盘、冻结 identity 及该端口下载内容。源基线仍为 `b276064942ae09c0227ec28d4cfda1d5ff006455`，目标提交为 `f94827b26fc12b707e6d6904d093e16358caaf41`。本次只读字节核对没有启动浏览器或 Runtime，没有新增右键截图，不能把 c 包的受控 T5 结论扩大为最新未知遮挡已定位或修复。
