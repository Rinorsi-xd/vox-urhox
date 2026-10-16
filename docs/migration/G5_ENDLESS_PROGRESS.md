# G5 无尽迁移进度（继续工作先读此文档）

## 当前接续位置

- **10/16 046同包五波/改装29/29功能PASS，性能FAIL**：QA4353 / `manifest-046debe2.json` / `.tmp/outgame-cached-1792088233891` /483Lua/指纹`0b49218d133898ab42032b9248b9116d21a2f52f85e960912ff0c77f4c527207`。证据`evidence/endless-banner-manifest-046debe2-2026-10-15T18-22-07-300Z`，运行错误0，probeErrors1（wave3单条5663字符JSON截断，后续完整探针恢复）。真实自然倒数出兵、既有F2实际销毁清波、五次补给/Enter、第五波T2复合横幅、G暂停世界时间75.81666666666365保持而壁钟4383ms、实际出发横幅到期、初始及改装返回升起/保护双相/模型恢复通过。已亲自查看随机维修卡crop、第五波、编辑与返回截图，维修符号清晰；源toast暂遮横幅保留。7049rAF全部保留（含9个跨stage间隔），p50 16.685/P95 50.050/max4103.165ms，191帧>100ms，性能FAIL。wave2/3/4各0帧>100ms不代表自然战斗压力；其余stage和冻结未删。工具正常exit0、浏览器finally关闭、GPU已归还root。含本批SpawnSpecCache，但没有受控A/B，不能宣称网页加速；未触发自然死亡/复活，自然完整战斗、账号、手机仍OPEN。

- **10/16 4227后出兵重复构建已补，1291/1291离线PASS**。唯一生产改EndlessSession，最终2661cbf...8572e；复用既有scene-owned SpawnSpecCache，原整spec缓存改为spawnRadii数值；首次Spawn和直接SpawnUnit均Prepare/Get，真实Unit获取私有clone，Dispose释放模板。全部51原prefab连续3车Build实际204→51，完整规格/强化hp/中心位置/源队列时钟/出兵门控一致；实际核心伤害后同型第四车恢复全装满血且0额外Build，template/兄弟车/源数据不污染。源出生497/退休22/横幅222/死亡撤离547全部最终SHA实跑刷新。详见`G5_SPAWN_CACHE_2026_10_16.md`和`evidence/endless-spawn-cache-offline.json`。新包Web加载收益未测，不签性能/自然战斗，无GPU/构建/提交上传。

- **10/16 4227后功能增量：死亡等待入口与金币提示源对照PASS**。源b276 `waitForRespawn`先于NextWave/EnterEdit，现恢复原剩余ceil秒数提示，等待中不触发下一波/改装检查，包括pending0与已到期尚未消费。金币Push补源1400ms，零件仍2200ms。已核源EndlessHud层80、story.css全局toasts层860，源本身可能短暂重叠，不擅自改位置/层级。新联合547项含28实际JS/Lua入口反例和实际Events→SourceToasts生命周期，横幅222重跑PASS。最终SHA与范围见`G5_EXTRACTION_2026_10_16.md`；未入4227，无GPU/构建/提交上传；自然死亡复活/最终画面仍OPEN。

- **10/16 最终b6f同包真实五波/暂停改装29/29功能PASS，性能FAIL**：QA4349 / `manifest-b6f6882e.json` / `.tmp/outgame-cached-1792086326119` /483Lua/指纹`8ceefc88d627175bd25d3678bef0dedb4b29b23ee8af7172f5012556e882b7c7`。证据`evidence/endless-banner-manifest-b6f6882e-2026-10-15T17-48-52-266Z`，runtime错误0，probeErrors1（edit-return单条4060字符F8 JSON截断，后续完整采样恢复）。第五波真实T2横幅、G编辑世界76.16666666666363保持/壁钟4347ms、出发横幅过期、初始与编辑返回升起/保护两相通过。第1波正常随机维修卡整页/crop已查看，白色✚正常；已看wave5/editor/return，toast仍遮横幅，整体1:1不签。6936rAF/208帧>100ms/max3886.34ms，9跨stage间隔全保留。工具浏览器已finally关闭/GPU归还root；死亡复活/自然完整战斗/账号/真机仍OPEN。

- **10/16 e1fc真实五波与暂停改装29/29 PASS，性能仍FAIL**：QA4347 / `manifest-e1fc12f8.json`，`evidence/endless-banner-manifest-e1fc12f8-2026-10-15T17-29-09-255Z`，运行错误0/probe错误0。真实隐藏选车、自然五轮倒计时/出兵，仅既有F2实际销毁敌车，逐波真实领取补给/Enter；wave5实际 `第 5 波完成 · 敌人升到 T2`/tier2，G编辑入口提示尚活跃，世界时间75.95不变而壁钟4413ms，出发提示过期、同wave/lives、实际升起/双相模型闪烁/恢复通过。浏览器已关闭/GPU归还root；不是自然打完整五波或手机/账号证明。
- **同包性能/视觉边界保留**：完整6638rAF/211帧>100ms，总max3586.1ms属加载；boot55/initial-spawn含加载123，wave1-5各6/6/6/7/7帧>100且max366.945/216.84/350.305/216.975/567.13ms；editor261帧max16.84/0超，edit-return max216.835/1超。9条跨stage帧全部保留，未丢弃。已亲自查看wave5/editor/return截图：三补给/模型/编辑页完整，但奖励toast部分遮挡波末横幅、维修加号缺字；不签像素1:1。死亡复活呈现、自然压力、账号刷新恢复、真机持续性能继续OPEN。下一步接G5打捞确证功能遗漏，禁止重开G0。

- **10/16 事件边界修复最终独立24/24 PASS并冻结**：`evidence/trial-event-boundary-offline.json`，实际旧e266 Tick零步复现失败1、新修复23；真实Tick/CombatView/DriveView/Vehicle.Dispose/WheelPose/PlayerViewSync配适配器，覆盖0/2/3步、死亡/重建/玩家死亡noBind与单次反馈、early editing/over不render保留事件。TrialSession完整SHA `a869b6a78f71b322a36c78b7674f46cc8a8cf0493ca5b822abf4dc2e71b6decb`；未再改生产，交root下一统一包真实五波复验，不能用本检查签自然击杀或网页已修。

- **10/16 e266网页已进无尽，wave1后实际FAIL，事件边界修复冻结待下包**：首轮2项通过但工具读未绑定的Node.enabledEffective而失败，旧报告/TOOL_FAILURE保留；仅改工具使用真实StaticModel.enabledEffective计数。第二轮 **7项通过/1Lua错误**：实际root升起、两相模型保护闪烁及恢复、自然wave1、三命清波和波末文字通过；F2在主Update之后实际销毁车体，下一零fixed-step帧未消费unitKilled而更新旧DriveView，报Vehicle.suspension=nil。工具自动关闭，完整4509rAF/184帧>100ms保留，max3869.61ms位于加载stage；wave1含补给max366.9ms/4帧>100，性能FAIL。`evidence/endless-banner-manifest-e266101a-2026-10-15T17-18-57-499Z/ROOT_CAUSE.md`。已冻结TrialSession `a869b6a…16decb`统一事件消费并在呈现前处理pending，未在WheelPose吞错；g4实际旧快照复现/新契约联合检查中，spawn497/lifetime22已重跑PASS。**五波/改装返回未验，修复不在e266**；root统一下包后继续，不重开G0。

- **10/16 上述调用契约修复已独立联合47/47 PASS并冻结**：g4执行实际View/ObjectiveView/ObjectiveRoute/Coin36项（Warn/Drop/Elite/清空/盾/Dispose）及既有竞技geometry11项；`evidence/endless-view-contract-offline.json`。原生节点/材质/向量与零件VehicleView是替身；两生产文件SHA见 `G5_BANNER_2026_10_16.md`。已联系legacy纳入统一audit；下一统一包重新实际网页验证，不能用本离线结果覆盖b239失败。

- **10/16 b239实际无尽入口FAIL，已定位并修调用契约，等下一包**：真实QA4341选择先锋后在 `ObjectiveRoute:14 path=nil` 失败，随后自动恢复大厅；第1波未进入、0检查，原log/report及人工结束TargetClosed说明保留在 `evidence/endless-banner-manifest-b2399110-2026-10-15T17-03-03-991Z/ROOT_CAUSE.md`。实际代码还沿用旧mesh/origin接口；现ObjectiveView新增显式 `Geometry(scene)` 无模式几何容器，Endless/View构造和每次Update均通过Begin建立mesh/origin，原竞技New/route分支保持。g4进行实际ObjectiveView/Route与Warn/Drop/Elite/清空/Dispose联合检查；**修复未进b239，不能签Web修好**。工具已补LoadingFlow Failed即刻失败，GPU已归还root。

- **10/16 tierUp/复合横幅已冻结，继续G5**：按10/15 `b276064942ae09c0227ec28d4cfda1d5ff006455` 实际JS事件消费，补Boss波完成 `第 5 波完成 · 敌人升到 T2`、同批tierUp最后值和源真实时间3500ms到期；正秒复活倒计时保留源覆盖语义。实际冻结JS43事件批/18时钟步骤与生产Lua Events/Run.CheckClear/挂载Hud共 **222/222 PASS**；出生497、严格退役生命周期22、编辑触屏92项重跑PASS。精确SHA和未验边界见 `G5_BANNER_2026_10_16.md`。只读probe已加实际root/壁钟/横幅字段，`check-endless-banner-web.cjs`已备好逐波真实F2销毁/补给/Enter到wave5，再G编辑4秒/出发；**尚未运行，不签Web或像素1:1**。root在b239工坊入口实测发现异常，修复后下一统一包再串行执行；不重开G0、不上传。

- **10/16 出生呈现增量已冻结，等下一统一包**：补冻结10/15源初始/复活/改装返回 `.6s` 按实际高度升起、保护期绝对时间 `.12s` 闪烁；保持scope/死亡/改装mask和独立恢复光壳对齐。实际冻结JS 228黄金 + 生产Lua5.4 **497/497 PASS**，包含真实PlayerViewSync重建和TrialSession相机执行顺序；native边界为替身，未占GPU、不属于b932b9cd、不签画面/性能。精确SHA及待验见 `G5_SPAWN_PRESENTATION_2026_10_16.md` 和 `evidence/endless-spawn-offline.json`。后续tierUp横幅仅登记，不在本批扩展。

- **10/15 功能接续，非性能实验**：重新对准冻结 `b276064942ae09c0227ec28d4cfda1d5ff006455` 的 `three/src/battle/endlessEdit.js`，补齐原商店购入后首个空快捷栏接入（重复不加第二个快捷键，满栏不覆盖，失败不改栏）、重置清理剪贴板/粘贴/拉伸/命中/多选/输入持有、禁止 Ctrl+S 绕过灰色保存按钮和原 back 按钮。商店改源 `auto-fill/minmax(210px,1fr)` 的动态列数，PC 宽屏保持四列/窄横屏改两列或一列；不另加主页无尽入口。`check-g5-edit-touch.py` 执行实际生产 Lua 方法及商店购买 callback **70/70 PASS**，包含六种 480–1920 宽度和打捞情境键；两源 SHA 已核固定基线。证据 `evidence/g5-edit-touch-offline.json`。依赖使用替身，**未启动 native/Web/GPU，不签真实画面、性能或账号恢复**；待 root 同包真实输入复验。生产范围 `endless/Edit.lua`、`ui/EndlessEditBar.lua`、`salvage/Run.lua`，未改公共 Session。

- 最新统一QA4290 / `manifest-d6764c9c.json`，快照`.tmp/outgame-cached-1792051106196`，生产`a7028dff4185d6a4915cd887f30231c54ac1429b71bde132310b3542ce193d81`，probe`17a19a0d3dff70411567118a5a3cdd1a63571d933a4c9dd5705659d1cab517ca`。含本轮Records数值校验修复；该新包无尽尚未复验，不以旧b8 Web或原生代签。当前先执行同包自然T5搜撤。
- 10月15日15:58追加存档实际缺口：`endless/Records`残留`n==n`无法可靠拒绝当前fast-math Runtime的NaN，现复用现有`storage.RecordNumbers` IEEE754有限安全数/整数校验。独立实际Runtime **74/74 PASS**、Lua/资源/引擎0，含run/best各字段、库存/kill/supply、NaN/±Inf/负数/超safe整数/小数及生产Cloud.Decode拒绝；源合法checkpoint和小数累计量仍接受。报告`evidence/endless-records-native.json`，未重跑1565项。首轮frame1注册未执行得到0项，失败保留；改frame3实际执行，100ms阈值未放宽，空场景非游戏性能。已交root待下一包冻结。
- 总计划N01-N07/L01-L08/D01-D08逐项当前证据与未关闭门槛已汇总`G5_ACCEPTANCE_LEDGER.md`，自然战斗/真实账号/真机/跨key云事务未写成完成。
- 10月15日15:28资源退出链真实联合 **45/45 PASS**、Lua/资源/引擎计数0，`evidence/endless-runtime-native.json`：真实波/伤害→死亡/五秒复活→三命结算→回厅→第二次真实Edit/Reload→第三次真实Edit/App.Stop，全链完成；首退严格检查主人仍活着、重复Leave计数2且幂等、world damage函数恢复、旧controller不留scene/world/host。10条受控Dispose方法顺序也包含在内。第一次30条通过后Body读取失败、后一次47/45/2由重复Leave spy误判均保留边界；root修Reticle死亡HP0，fixture只修spy，未改生产结果。实测Engine:Exit提前退出不会写validator报告，现Finish后加快空闲帧到正式终点，正常保存报告。该wrapper沿用15秒阈值，只证明功能，不是100ms性能通过。
- 当前统一包：普通4285 / QA4288，`manifest-6d18072e.json`，快照`.tmp/outgame-cached-1792049068098`，指纹`7c5a7f028f4eb296c767a1c8bbaaefdb0aea5a20eed6d43b85832383f2acfb58`。QA4288补只读probe死亡安全访问及活车center，probe指纹`1282e39407c410c5a7bf617c188808ebd5d89c6736b8f06b9d60778e7e2019d1`，生产同包；8db及b8历史结果保留原身份，不拿新包代签。Web无尽/自然搜撤仍待同包回归。
- 已通过：前b8包PC1600×900与20:9横屏1440×648真实点击各8/8 PASS、游戏错误0；当前shield目标契约/实际改装链原生25/25 PASS。规则644、Raider144等历史子项保留各自身份；8db新包无尽尚未复验。
- 已修实际失败：935b完整AI在玩家基地护盾中收到nil瞄准目标，真实Web每端44条错误；补原pos/zone/aimPoint，下一b8包复验已通过。PC有一次长JSON探针截断，独立记录。
- 未关闭：自然完整波次、真实账号刷新恢复、八敌车同屏真机性能、全源页面像素验收。浏览器QA的销毁敌车/回基地不替代自然战斗。
- 唯一下一动作：root下一统一包后继续同包功能与真实自然战斗；生产当前冻结，公共音量设置测试仅改tools并按native队列验证，不重新G0。

## 固定基线和边界

- 源分支 `2026-10-14`，提交 `2b169a9964645f5f346a7158bcb14447f040814a`。
- 冻结副本 `.tmp/outgame-source-2026-10-14T10-09-50-505Z`，完整身份见 `outgame-baseline.json`。导出工具核对 11 个源文件 SHA256，未读正在继续修改的源工作树。
- 目标分支 `codex/h5-2026-10-14`，与其他迁移代理共享现有修改。未提交、未上传、未提审或发布。
- 源 `shared/ui/home.js:44` 明确“无尽模式先隐藏（代码保留）”，公共主页维持三个竞技模式。源 `three/src/main.js` 保留 `shell.onEndless`、`drive=endless` 自动入口及 `bench=endless` 调试入口。目标通过 `App:SelectEndless()` 和 `App:EnterTrial('endless')` 对应，未自行加第四张主页卡片。
- 当前源 `tierLimits=false`，玩家不再被旧策划案 T1 限制。所有规则采用该提交实际配置，不能把历史策划再混进来。

## 本批已经接通

| 项目 | 实现 | 验收状态 |
| --- | --- | --- |
| 原始内容 | 50 个常规源敌车蓝图、原隐藏 huhu-fuyuan 特兵（共 51）、3 辆源起步车、配置和角色数据 | 已导出，源 hash 校验通过；未擅自把特兵加进正常波表 |
| 波次 | 原 RNG、点数预算、阶位、精英、5 波 Boss、最大 8 敌车、120 秒冲锋 | 160 个源黄金波次逐项匹配 |
| 实际战斗 | 原地图、真实 CarUnit、Bullet、武器、敌人驾驶、出生口占用和空投着陆 | 原生真实对局通过；所有角色实际战斗未全验收 |
| 玩家生存 | 3 条命、5 秒复活、3 秒保护、基地护盾、15% 回复、0.4 秒零件复原、离基地 5 秒后 10% 回复 | 规则和实际伤害/复活通过 |
| 掉落经济 | 幸存武器/移动零件、必掉金币、精英最强件、Boss 双掉落、吸附、自动波末拾取 | 30 组源黄金掉落及实际奖励通过；原始外观对照未关闭 |
| 波间补给 | 原三选一、武器饥荒保底、维修、下一波倒计时、80px 原零件缩略图 | 72 组源黄金补给及实际领取/下一波通过 |
| 局内改装 | 同一个暂停世界内使用真实 BuildSession；独立蓝图/历史，不写机库草稿；库存限制、撤销重做、出发校验、原地返回 | 实际编辑与原位返回通过；触屏及缩放复验未关闭 |
| 商店 | 原图纸价格、T1–T5、仓库数量、购买扣款；源矩形 section 对应独立 UI Panel/ScrollView | 规则通过；修复 Show 未挂载与默认 Modal 480px 裁切；真实 Web 点击仍待验 |
| 结算 | 波次/得分/时长/伤害/击杀/纪录、再来/存车/主页 | 实际三次死亡结算通过；最终画面证据更新中 |
| 源音效 | 原 10 个 WAV 的倒计时/波次/Boss/冲锋/金币掉落/吸附/波末/补给/失败，源变体、增益和冷却 | 最新原生功能链通过；听感/手机连续播放未验收 |
| 钻头特兵 | 原 20–32 米距离带、整车对齐、蓄力释放、保护/遮挡取消、200ms 甩飞自爆 | `verify-drill-raider.ps1` 144/144 源对照通过，已接无尽；真实该兵驾驶未全验收 |
| 存档 | 原两个 key、严格验证、本局休整 checkpoint、最高纪录；允许 CloudStorage 同步这两个 key | 校验通过；真实登录账号跨刷新/设备证据未取得 |

## 当前验证证据

- `tools/migration/verify-endless.ps1`：**644/644 PASS**，包括 160 波次、72 补给、30 掉落源黄金数据；运行脚本和 shader 错误 0；记录 `evidence/endless-native.json`。
- `tools/migration/verify-endless-runtime.ps1`：最新 **21/21 PASS**，真实加载、波次、伤害、补给、暂停编辑、限量拒绝、原位返回、复活、结算、返回释放、实际编辑世界坐标相机投影及商店挂载/可见；运行错误 0，记录 `evidence/endless-runtime-native.json`。新商店截图已打开查看，标题、钱数、关闭按钮、完整三列卡片及滚动区域均可见。
- 最新新增 `endless/Coin.lua`：源半径 .55m、高 .14m 的三枚六棱币和 .4rad 分层偏角，替换默认圆柱；材质补源 .35 发光。新版已随20项完整原生流程通过。
- `combat/DrillRaiderDriver.lua` 的 140 个原 H5 距离/角度/蓄力组合及 4 个自爆边界检查：144/144 PASS，运行错误 0。精确边界输入通过 IEEE754 位串保留，避免 JSON 解码在 20m 分支产生 1ulp 偏差。
- 原生启动历史 DDS / DLL 日志与测试窗口错误分开记录，不能声称所有平台启动日志为 0。
- 最新原生截图 `evidence/endless-result-native.png` 已在结算 HUD 更新并实际渲染后捕获、查看。展示完整结算；测试主动触发的即时 toast 仍叠在上层。未宣称与完整 H5 最终画面逐像素相同。
- 编辑最初新增截图暴露真实生产问题：直接替换主 viewport 时陨坑后处理继续提交旧源，报 `DepthResolve (depth_buffer)` 缺失。`endless/Edit.lua` 现复用同一源后处理 viewport 只切相机，退出恢复；20项复跑错误0。该失败没有被掩盖成通过。
- 编辑出画截图另有 QA 脚本问题：误用基地护盾椭球底 `shield.pos.y=0` 放车，平台实际 `base.pos.y=6`。测试改用真实基地高度后，实际车完整居中，投影约 `(0.499999,0.500001)`，干净图已查看。生产地图/物理未因此修改。
- 新实际浏览器流程 `tools/migration/check-endless-web.cjs`：PC与20:9选择、自然倒计时/出兵、补给、真实G编辑、商店、返回原波次。QA只通过真实CarUnit销毁和实际玩家放回基地到达休整页面；不把这种UI复验称作自然打完整波。
- `manifest-43b0ce1d` / QA4267：PC 1600×900 与横屏1440×648 各 **6/6 PASS**，运行错误0。已打开查看商店三列/滚动和完整居中战车截图。横屏测试 `touch=false`，仅证明比例，不是真手机。证据 `endless-web-{pc,landscape-20-9}.json` 与同名前缀 PNG。最初 probe 未持续刷新及空Lua表被当数组的测试失败已保留；修测试后重跑通过。
- 同包无尽加载各步骤总等待约67秒，下载约33秒、装配预热约20秒；功能通过不等于加载性能通过，仍为FAIL。最新整车采购与完整AI是后续脚本，不能用此旧包签收。
- `DrillRaiderDriver:Step` 已按完整 EnemyDriver 第四返回契约透传 reset/flip/salvo，活动钻头提前返回明确 salvo=false；避免特兵绕过普通翻正/救援。源 Policy 144黄金仍适用，第四返回集成待新包。
- 打捞 L01/L05/L08 与云恢复 stash 新增源对照、采购和缺料改装接入，见 `G5_SALVAGE_PROGRESS.md`，不与无尽限量仓库混用。

## 当前文件与接口

- `scripts/endless/{Data,Random,Inventory,Run,Records,View,Edit,Audio}.lua`：独立源规则、内容、校验、掉落、原音效和 retained editor。
- `scripts/app/EndlessSession.lua`：`Dependencies / New / BeforeStep / AfterStep / Update / SyncPlayer / HandleKey / Snapshot / Dispose`。
- `scripts/ui/Endless{Widgets,Select,Hud,EditBar}.lua`：选车、HUD、补给、结算、改装栏和商店。
- `assets/Endless/Rules.json`、`tools/migration/export-endless.mjs`、`source-endless-fixtures.json`：可重复源导出和黄金夹具。
- 父代理已接入 `DriveMaps / HangarApp / TrialSession / DriveHud`，并处理再来一局。`CloudStorage` 已增加两个源无尽存档键及验证器。

## 下一步直接继续，禁止重新从 G0 开始

- 统一 `manifest-935b3961` 的 PC 与20:9真实 Web 均发现同一生产错误：`EnemyDriverMath:10` 收到 nil 目标，完整AI在玩家处于基地护盾时无法计算可见性；每端44条运行错误，未记为通过。PC失败归档 `evidence/endless-web-pc-935b-shield-contract-fail.json`，横屏失败见 `evidence/endless-manifest-935b3961-2026-10-15T05-52-47-038Z/`。根因为 `EndlessSession.shieldTarget` 缺冻结源 `endlessSession.js:88-91` 的 `pos/zone/aimPoint` 契约，现已逐项补齐，aimPoint 使用真实椭球射线交点。
- 修复后真实原生链扩展为 **25/25 PASS**、Lua/资源/引擎错误0，`evidence/endless-runtime-native.json`；新增基地内完整 EnemyDriver 经过空降/think 的实际调用与护盾表面瞄准。此修复在935b快照之后，下一统一包才可复验 Web；不把旧包失败抹去。浏览器脚本已分离probe错误并在实际运行错误时立即终止，新增改装期间所有battle子模型隐藏/返回恢复断言。
- 下一统一 `manifest-b8b63ade` / QA4280 PC1600×900与横屏1440×648真实 Web 各 **8/8 PASS**、运行错误0：完整AI出兵不再报护盾目标错误，补给、实际G改装、进入编辑battle全部子模型隐藏、回原战场全部恢复、原波次和源商店通过。证据 `evidence/endless-manifest-b8b63ade-2026-10-15T06-03-35-753Z/`；PC有1次长JSON探针截断，独立记录probeErrors，不伪报全日志0。浏览器已全部退出并释放给g4独占音频。该脚本用F2销毁实际敌人/F3回基地进入休整，不是自然打完一波或真机性能。
- 10月15日接续：root 的真实显隐发现后，Edit Enter/Leave 改用共享 NodeVisibility 递归处理，新增实际 battle 子模型进入编辑隐藏/出发恢复两条检查。第一次完整回归确实在触屏布局初始化报 `[TouchPreferences]:17 host.store:Read nil`；失败证据保留 `evidence/endless-runtime-native-touch-host-fail.json`。修为从实际 app 获取 touchPrefs、保存转回真实 app，局内独立蓝图 store 继续维持限量约束。
- 修复后完整真实原生链 **23/23 PASS**、Lua/资源/引擎错误 0，`evidence/endless-runtime-native.json`；实际暂停编辑、可见模型、同世界/同波次返回、复活/三命结算均通过。Runtime 已退出。这些增量不在 `manifest-cbebfb9c`，仍需下份统一 Web 包回归；不是自然打完整波或真机性能证明。

1. 已补源音效与有界声源；继续 Web/手机听感和连续性验收。
2. 已补源零件预览、动态仓库剩余数字和 resize 后限制重接；实际触屏库存/商店点击待复验。
3. 21项真实完整流程通过，补给、编辑车居中、商店源矩形页面三张截图已核。Coin和Raider均在本批生产流程中加载。继续同包 Web 真实点击，不以原生截图代替手机/浏览器验收。
4. 同构建 Web 与 20:9 横屏点击、真实账号恢复、连续 8 敌车性能；没有证据保持未验收。

G5 功能主链已接通，但**尚未整体关闭**。源像素级 UI、所有敌人实际驾驶、真实账号云同步及手机持续性能不得以规则测试代替。
