# G5 打捞经济与恢复接续

## 当前接续位置

- **10/16 源功能批已冻结、待统一包**：实际补齐清据点原光柱/绿提示、警觉提示原原因/存活数/颜色与调用时序、空投青柱/姓名卡/原feed、击毁与死亡、落地/保护结束提示；保险库破解/开门及空投接原3个WAV，按原强度/gap和AudioLevels路由，预取/静音/焦点/暂停/释放齐备。50源场景→实际Lua104检查、6负控PASS，547/675/29/92旧专项按最终SHA重跑PASS。无GPU/打包/上传；详见`G5_ENCOUNTER_FEEDBACK_2026_10_16.md`，不签最终画面/试听或自然完整搜撤。
- **自然路线QA定位**：旧14f最后93条真实采样前约7秒确实近乎静止，原障碍/净空待查；后段旧best-ever距离检测又在正常行驶中反复倒退，属工具错误，已改持续实际位移检测。历史回放倒退22条→6条，原自然FAIL与成功撤离OPEN均保留。新工具语法/恢复控制通过，尚无新GPU路线，地图物理与生命/时钟/货物均未改。

- **本批增量已收入046统一包**：`manifest-046debe2.json` /483Lua，源身份仍b276。无尽同包29项真实Web通过、错误0，但搜撤成功/900秒超时没有执行，不能用无尽结果代签；详见`G5_ENDLESS_PROGRESS.md`。先前“未入4227”只是历史身份，当前撤离接应/绿色feed/信号塔卡的自然Web验收仍OPEN。无提交上传。

- **10/16 4227后功能增量：撤离接应/提示547项源对照PASS**。源b276 `salvageRun.update`重进撤离圈按`exLeft`剩余秒数接应，迁移此前动画固定原exit.wait；现Rules保存扣dt前的approachWait并发事件，实际Run/Cinematics接剩余时间，仍源3–6秒限幅。补原“撤离中”绿色feed和信号塔首次3秒NameCard，不重复追兵/警报；Feed颜色现贯穿到Hud。547检查中含70实际源更新帧/48接应机位及无尽28死亡等待入口；675保险库/92拾取/29结算均按最终SHA重跑PASS。细节与SHA `G5_EXTRACTION_2026_10_16.md`、证据`evidence/g5-extraction-offline.json`。本增量不属于4227；无GPU/构建/提交上传，自然成功搜撤/账号/手机仍OPEN。

- **保险库最终冻结补正：675/675 PASS，取代下条616的入口边界**。legacy独立发现原实际入口用`Vehicle.speed`前向投影，横滑会误判停稳；b276 `update:972–973`实际用相邻XZ位移/max(.001,dt)。已在生产`Run.AfterStep`修正，首有效采样按源速度0、只Y移动忽略、暂停/换车/复位保留前位置，不更改2m/s阈值。新工具执行未改写冻结JS`update`与生产Lua`AfterStep`，实际位置输入15帧/59项核侧移/倒车/恰好2/首落地/0dt/亚ms/暂停恢复/重建/finished；加原616合计675PASS，物理为适配器，非真Bullet滑行。最终Run SHA `bc7e42f77ddf1adacb9620e183f07f69b8798e392b07c62eb5a971e778611082`，Rules SHA `8e2e2f4fbe310a00ba12b2d90f7d0bf7ebb813cddeb2394024ea1e9ca0aa6355`。92拾取/29结算已在此最终SHA再次实跑并刷新报告，交legacy独立复核/纳下一统一包；不属于e1fc、无GPU。

- **接续生产 L02/L07：b276保险库破解反馈已冻结，616/616离线PASS**。`salvageRun.js:335–344`首次有效按住给3秒“舰载保险库 · 破解中”警报，保持进度后8秒完成，按箱内最高稀有度打光柱、闪屏alpha=.2/duration=.4、镜头trauma至少.3。原迁移只有heat/noise/hunt，现`RunRules`发`vaultStart/vaultOpened`，`Run.Events`接既有Cinematics/SalvageFx和TrialSession已消费的trauma。不改共享相机/物理；不猜测音效。新工具直接执行未改写冻结JS `_searchStep`及生产Lua两方法，14场景126帧核0–5最高稀有度/空箱、速度2边界、松手中断/重新打开、恰好8秒及完成后再进、已有.8震动保留、警报与追兵/开门顺序，616项PASS；既有92项拾取和29项结算复验PASS。证据 `evidence/salvage-vault-offline.json`，功能边界详见`G5_VAULT_2026_10_16.md`。当前生产不属于e1fc包，真实Web/原生最终画面/自然完整搜撤/音效/真机仍OPEN。无GPU、提交或上传。

- **接续功能批：结算净货物一致性已冻结，29/29 离线 PASS**。源 b276 `salvageRun.js:523-537` 会先从 cargo 扣一件撤离通行货物，再以净 cargo 形成结果/入库；`shared/ui/salvageRunHud.js:411-418` 只展示结果物品。迁移 `Run:Finish` 原仅在临时副本扣票，局内 `rules.cargo` 留着票，`SalvageRunHud.Result` 又取 10Hz 的 `run.hudCargo`，导致结算画出已付票或漏掉刷新间隔内的新货。现 Finish 同步已结束货舱为保留的净结果 cargo，失败清空货舱（仍先记录原损失），结果清单/空状态/滚动高度直接取 result.cargo；存档失败保留同一净结果，重复保存/返回不再扣票。新工具 `tools/migration/check-g5-result.py` 执行实际 Run.Finish/Commit、Lobby.CommitRun、StashRules.Valid、Result UI 树和按钮，**29/29 PASS**，源两文件 SHA 核 b276；覆盖一票清空、多票只扣一、陈旧99件HUD、死亡/放弃零入库、失败存档整对象回滚与按钮多次重试幂等。证据 `evidence/g5-result-offline.json`。UI/存储是替身，不代签账号、Web/native画面或真机；本批没有GPU运行、提交或上传。该新增生产不属于旧8d1859cd/2c911f96包。

- **10/15 23:22 同包 native 冷启动未完成，GPU 已释放**：已实际运行冻结 `manifest-2c911f96` / `.tmp/outgame-cached-1792077192303`，本批七个生产输入 SHA 与快照全等；真实引擎日志确认该 manifest。首次机库渲染持续卡 frame752 编译 Surface pixel variants，多条单变体约 23–26 秒。240 秒引擎截止因帧阻塞未退出，255 秒外层 deadline 杀本次进程，进程复查为零；未执行 G5 fixture 断言、无 PNG 或 validation.json，不能签功能或画面对照 PASS。保留 `evidence/g5-increment-manifest-2c911f96-2026-10-15T15-18-14-265Z/{identity,timeout}.json` 与 stdout/stderr；启动 stderr 两条为 `Cube/Day/DaySpecularHDR.dds` 缺资源、`themis_x64.dll` 不能加载。未改生产、未延长截止或重跑，已把 GPU 交回页面验收。92 项离线证据与本次冷启动 FAIL 分开。

- **10/15 b276 拾取反馈生产已冻结，待 root 同包验证**：对照 `salvageRun.js:263-270,386-452`，补 `RunRules` 的实际入仓批次事件与换货丢弃事件，`Run.Events` 按实际成功入仓质量给既有 `session.stompV` 一次下沉（`min(1.6,.25+kg/40)`）。换货图标立即从中央飞入、显示准确丢弃清单；残骸一批最多六种货按 260+110i ms 依次飞入，不重复当成搜箱揭示。保持真实 `Loot.Swap` 交易与玩家 Y-0.8m 原地可再搜货箱。`check-g5-edit-touch.py` 现 **92/92 PASS**，新增 22 项执行真实 Loot/RunRules/Run/SalvageLootMotion 与实际 Outgame/RunData 数据，含满400废金属→丢20换2合金→重新搜回20、无可换货不假反馈、单批质量上限与缺省 spring 保护。证据 `evidence/g5-edit-touch-offline.json`；仅 Lua 离线检查，UI/native替身，不代签最终渲染、移动端真机或自然撤离。未开启运行实例、未提交或上传。

- **10/15 功能接续**：冻结 b276 的 `three/src/salvage/salvageRun.js:1042-1043` 明确提供 `touchPrompt`（过滤 blocked）和 `touchSwap`（搜索中存在 full 项）。迁移 `TouchDriveControls` 已消费 `touchSwap`，但生产 Run 从未赋值，导致手机满仓没有换货键。现 `Run:TouchContext()` 在实际 AfterStep 更新两字段，行动结束清空，保留真实 F 换货规则。`check-g5-edit-touch.py` **70/70 PASS** 中含 8 个搜索/阻挡/结束组合及完成后旧情境键清理，源 SHA 核 b276；共享触控层 prompt 消费由 root 接线。只验证生产 Lua 与控制替身，未启动 native/Web/GPU，真实手机满仓换货待同包复验。未改货舱容量/价格/库存/地图/敌人。

- **17:27 已冻结**：`Run.Dependencies` 最终窄优化后 **198/198功能PASS，Lua/资源0**，证据 `evidence/salvage-resources-2026-10-15T09-26-06-579Z/`。8140原行按解析器实际读取的`type/rot`合并58项，已有`FromBlueprint`产生同一213种敌池资产；实际进场1470行完整，48车逐一对旧完整蓝图集合相等且实际Bullet/PartRig消费/释放通过。单独Run依赖26ms、真实入口callback239ms；前一raw未先去重版同callback3396ms，仅同机原生测量，不能代签Web/真机。71条100ms尖峰、最大567.584ms令整体仍FAIL（含旧路径对比与实际建车），不把功能PASS写成性能PASS。最终`Run.lua` SHA256 `08789c85453f6a7c8760033174825f6ca69584891d77ce374fce4bc35c277d33`，已交root统一包，不再启动长自然路线。
- **17:16 最新状态**：本路真实入口资源与全部48原敌车的创建/消费/释放 **149/149功能PASS，Lua/资源0**；34个100ms尖峰使整体FAIL。旧11e3自然搜撤仍因`kite/hover3`模型漏下载FAIL，root已补实际入口`salvage.Run`资源挂钩；自然成功撤离/900秒/真实账号/手机性能仍OPEN。当前只待g4独占PCM结束，运行新的raw依赖集合等价+真实callback计时短检，然后进入root第四统一包自然搜撤，不重跑G0。

- root已修嵌套`Workshop.Update`及冻结`shell.js:737`原键盘转发。新独立native `salvage-workshop-2026-10-15T08-49-41-733Z` **27/27功能PASS**、Lua/资源0；6条100ms尖峰（最大1287.73ms）令整体FAIL，阈值未放宽。实际feature/browse图已查看全卡显示，detail UI显示但模型仍分帧装配中，不能签最终预览。覆盖真实Hud.Update、focus=false仍推进、caption/shelf/entry/card alpha、左右/Enter/逐层Esc/数字1–5；键来自隔离input shim、lobby owner受控，不是物理键盘或自然切厅证据。首轮真实SetLobby受验证旧草稿阻挡、第二轮同帧查未重建按钮的两次fixture失败保留，Runtime均退出。新11e3cbe9 QA4296 `08-50-34-344Z`已启动实际可见alpha/工坊miniHeavy采购→自然搜撤。
- d676 `08-37-13-643Z`miniHeavy首轮未点“查看全部”，首屏仅前5原车导致夹具等待卡片FAIL、0运行错误，实际失败图已查看。补真实浏览入口后`08-42-10-284Z`进入browse，但实际“机甲”未切组（20秒FAIL、0运行错误）。由此发现生产缺口：`GarageHud.Update`仅顶层`tab=='workshop'`推进`Workshop.Update`，打捞嵌套`s.tab=='salvage'/s.salvage.tab=='workshop'`遗漏，4分钟后`ws.elapsed`、caption/shelf/grid入口动画仍0，真实截图说明/卡片/部分控件全透明。已交root修共享Update，不能把点击透明控件当用户可用；下一包需增加真实alpha/动态帧断言再采购miniHeavy自然路线。两个浏览器均已finally关闭。
- d676 `08-30-30-602Z`真实复用已购T5/自然投放/点击捕获成功，3检查PASS、运行0，但完整搜撤**FAIL**。随机S5→L119接近段实际150秒未到箱，最终COM[794.7304,36.2994,673.3603]、距23.402m、HP1，286真实按键采样包含前进/倒退但卡在桥与设施群；失败图已实际打开。不能仅凭源路宽判定碰撞根因，也不能改车尺寸迎合测试。parent授权原T3 miniHeavy“量产机兵 · 重装”较窄车对照，`08-37-13-643Z`实际工坊采购进行中；自然成功撤离仍OPEN。
- d676 `08-19-50-046Z`完整真实T5加载已完成，download44.148s/resources87.946s/scene.456s/prepare44.402s/activate5.078s、warmFrames179，原随机S5投放完成后实际点击捕获出现浏览器`The root document of this element is not valid for pointer lock.`，1检查通过、1运行错误，整体FAIL，截图已查看。保留实际加载和失败，不把新Loader不误超时当性能通过。随后夹具改专用context新建page并bringToFront，根因仍待验证。
- d676 `08-26-08-966Z`专用Chrome profile真实恢复车库2车位/已购1557件蝎型战车/余额3656，第二次“补15,624”按钮正确禁用，测试重复购买FAIL、运行0。网络43请求/21响应、磁盘缓存命中0、137,569,264字节；profile存在不代表HTTP缓存命中，更不是云账号恢复。夹具现按真实garage选择复用已有原车，不清存档、不加钱，复跑`08-30-30-602Z`进行中，尚未签PASS。
- d676首轮`07-59-40-733Z`在工坊首个过渡帧widgets为空，测试Actual button断言FAIL、运行errors0，已打开失败图；只修click等待真实可见控件。第二轮`08-02-43-543Z`实际采购T5成功，加载在夹具240秒期限到达时仍正常进行：download111.892s、resources102.696s、scene.541s、prepare24.964s，`loadingFlow.failed=false`，内部进度.8554，salvage-collision最大slice160ms。实际失败图已打开，显示“搭建碰撞体/仍在加载”而非生产失败；新Loader已跨过旧90秒错误截止，但长加载仍不合性能。浏览器已关闭给g4独占音频，未重复冷启动。
- 下一自然夹具仅功能等待改600秒，生产failed立即报错，完整保存进场phaseTimes；可用`VOX_NATURAL_PROFILE=.tmp/salvage-natural-chrome`保持专用HTTP缓存，并记录profile是否预先存在、实际CDP请求/缓存命中/传输字节，不伪造平台账号。新600秒预算不是性能标准或过关结果。
- 原nav最短路存在高差边：R1:324→R7:184高差57m/水平12m（78°），R14:128→R8:104高差30m/水平9m（73°），不能把连通当巨车可驾驶。仅QA规划优先过滤>35°原边，保留原地图；5出生均能找到8.5°–12.7°最大坡度的E3路线，但约1660–2775m且仍穿原敌营。若无坡度合格路才显式标steepFallback，实际驾驶/宽度/敌伤仍未验。语法及原拓扑离线核对通过，不代签自然撤离。
- 新可复跑`tools/migration/check-salvage-routes.cjs`直接动态执行冻结源Blueprint/buildScorpion/buildVehicleSpec并核3源SHA，输出`evidence/salvage-route-offline.json`：T5蝎1557原件，19.601m宽×29.5m长×15.947m高，9444kg、8腿4武器、源最高14.267m/s；所有5路线标记最窄8–10m，小于车宽。源路宽不是障碍实测净空，不能据此断言一定过不去或宣称已可驶；下一真实驾驶保留此风险，不改车尺寸迎合路线。该离线程序PASS仅代表源数据/拓扑，不算自然撤离通过。
- 原边寻路进一步按源营地警戒半径加暴露成本，真实几何距离与weightedCost分别记录；S2原86暴露点降到67、路线2775m变2995m，其余源路网没有更低暴露绕行。最新离线报告已重算，仍PASS；最长约3km，不能用距源直线估算完整自然测试时间。
- 10月15日15:59新统一QA4290已真实核对`identity.json`：`manifest-d6764c9c.json`，`.tmp/outgame-cached-1792051106196`，生产指纹`a7028dff4185d6a4915cd887f30231c54ac1429b71bde132310b3542ce193d81`，probe`17a19a0d3dff70411567118a5a3cdd1a63571d933a4c9dd5705659d1cab517ca`。包含共享Loader进度/模型warmWait修复、Records/碰撞unit&COM/开篇/BossHUD；真实T5工坊采购→搜撤进行中，证据`evidence/salvage-natural-manifest-d6764c9c-2026-10-15T07-59-40-733Z`，当前未计PASS。与root/g3功能并发，不作性能金标。
- 10月15日15:48修正后的资源退出链 **1565/1565 PASS**，Lua/资源/引擎计数0，`evidence/salvage-native.json`。真实冻结源starter78件→实际COM定位→HandleKey(E)/Tick→搜到货/原reveal声音→原撤离运镜→实际Save失败回滚/重试一次入账→真实回厅→保留旧Run/Director/Cine/View/FX/Audio的断链及重复Dispose，全部完成；Runtime正常退出。该fixture含受控摆车及撤离触发，仅签功能链，不代签自然撤离、当前6d网页或真机性能；wrapper旧15秒阈值不能当100ms性能验收。前两轮失败按`.previous-20261015T074123793`和`.previous-20261015T074652777`保留。
- 10月15日15:42资源退出链复跑 **1543/1545 FAIL**，Lua/资源/引擎计数0；测试捕获公共`CombatView:13 e.unit=nil`，root已确认其新增CollisionAudio事件漏unit并补齐及加消费者回归，未改CombatView绕过。另一个COM断言因fixture第二次`Vehicle:Place`把raw origin误作地面anchor、重复应用`-bounds.minY+.15`，现仅fixture改为body.setTranslation按实际COM偏移；真实E/物理/搜货仍保留，待g3/g4 native队列后复跑。首轮失败不得覆盖为通过。
- 当前6d包真实工坊蝎型战车采购→整备→进图 **FAIL**，errors0、仅采购一项通过，证据`evidence/salvage-natural-manifest-6d18072e-2026-10-15T07-40-20-217Z/`。真实1023资源下载115.399s，准备98.389s后生产`loadingFlow.failed=true / Scene loading timed out`，实际加载失败图已打开查看；并非仅夹具240秒超时，未到随机投放和搜撤。浏览器已关闭，root接共享SceneLoader修复。未改地图/敌人/血量/货物/时钟；并发仅功能验证，不作为性能采样，不重复旧包冷启动。
- 10月15日15:31资源退出链原生首轮：**1560/1563**、Lua/资源/引擎计数0，整体**FAIL**；新增真实返厅后保留Run/Director/Cine/View/FX/Audio的断链/二次Dispose均通过，原“E开箱/搜到货/reveal音效”三条失败。fixture继承验证store的350件车，只把body原点放箱边，实际COM/高度没有记录；疑为测试摆位缺陷，未当成已证根因。现fixture固定冻结源starter，并严格断言真实COM在箱XZ±.01m和Y+2m，再走原HandleKey(E)/Tick；待音频独占结束后复跑，保留首轮JSON。这些生产释放改动已进入6d新包，但新包自然搜撤仍未通过。
- 离线原路网方案已加到自然夹具`VOX_NATURAL_SAFE_ROUTE=1`：根据实际随机出生，在邻近源箱/E1或E3中按原nav距离与原营地警觉半径选路，跳过不连通图；不改地图/敌伤/出生/货物。S4→L70→E3为614m、39路点、0营地半径内路点；S1/S2/S3/S5仍有暴露（不是安全保证）。`node --check`通过，实际自然搜撤仍FAIL待新包验证。死亡时缺vehicle现明确转到自然死亡等待，不再误报读取position异常。
- 当前统一包：普通4285 / QA4288，`manifest-6d18072e.json`，快照`.tmp/outgame-cached-1792049068098`，指纹`7c5a7f028f4eb296c767a1c8bbaaefdb0aea5a20eed6d43b85832383f2acfb58`；QA4288补只读probe死亡安全访问和实际活车COM，probe指纹`1282e39407c410c5a7bf617c188808ebd5d89c6736b8f06b9d60778e7e2019d1`，生产同包。新增共享/打捞引用释放、原暂停页/原图预热/源开篇post等，8db历史结果仅属于8db，不跨包代签。
- 已通过：采购双比例真实Web各5/5（b3a7f84f）、cbeb自然开箱/放弃/回厅7/7、真实结算事务25/25；源爆炸运动7169/7169、源池/Run击毁死亡/实际投影19/19原生PASS。这些不能跨包代签或替代自然撤离。
- 当前实际失败：935b直线撤离被陡坡拦住；b8原nav路线取到L72物资后被6敌车攻击/卡住，HP降6.5%，35秒路点期限FAIL，运行错误0。失败图已开始死亡爆炸，但尚未等待正式结算，仍未签收自然死亡。
- 未关闭：自然成功撤离、900秒自然超时、真实账号刷新恢复、手机持续性能；爆炸调色仍未逐像素对比。实战死亡正式结算已经取得下述8db真实带货证据，但搜撤整条失败仍保留。
- 唯一下一动作：root接共享资源Dispose清理并统一新包；音频独占期间离线准备更安全的原路网撤离路线，不启动运行实例、不改敌人/地图/血量/货物，不重新G0。
- 14:38原声音设置实际指针/键盘/存档/进试车回厅复验29/29功能PASS、Lua/资源0；root释放顺序修正后Invalid wrapper/context已消失。5条100ms阈值尖峰仍令整体FAIL，最大779.309ms，证据`evidence/audio-settings-2026-10-15T06-37-41-210Z`；两张最新模态截图均已打开核对，780×424、无文字重叠。原生窗口已释放给g3，不重复跑音频。
- root授权probe只读新增`salvageInventory`，含实际stash物品/统计/事务ID、出击原车安装种类计数与车位；须随下包冻结，后续自然结算用真实前后差核对，不能只看committed布尔。
- 14:43新包两条自然路线已启动：原车真实敌伤死亡、原工坊量产机兵·突击实际采购后搜撤。T3采购/切车/整备出发已走真实控件，尚未完成整条结算，不计PASS；证据目录分别`salvage-natural-manifest-8db734ff-2026-10-15T06-42-54-582Z`与`06-43-04-819Z`。
- 上述8db首轮均FAIL且运行错误0，证据保留：原车已经自然搜到3类货但停在177.8m、源营地未警觉，4分钟等待没有死亡；T3测试误将A/D当转向且Space当制动，实际源机械足A/D平移、朝鼠标转、Space跳跃，导致未到箱子。测试已修为真实鼠标瞄准闭环/松键减速、死亡前开进源警觉范围。同包第二轮`06-49-53-704Z`（强车）与`06-50-43-342Z`（死亡）进行中，不把夹具失败误列为生产物理错误。
- 8db第二轮已结束并全部关闭浏览器：原车32.42秒被冶炼厂6敌车实际击毁，原死亡运镜→结算损失2624→精确扣所有安装种类/统计一次/事务→真实回厅6子检查PASS、运行0；整条搜箱未完成，完整report仍FAIL。强车已真实搜到`cell1+scrap6+ration1`、沿原nav至`R5:72`后88.13秒被矿坑敌人实际打死，原运镜→结算损失9002→全部原车件精确扣除且货物不入stash→raids不重复/lost+1/lastRun一致→回厅10子检查PASS、运行0，两张结果/回厅PNG已实际打开核对。强车成功撤离完整report仍FAIL，不能把自然带货死亡子链PASS改写成撤离PASS。

## 身份与范围

- 16:53 当前 `manifest-11e3cbe9` 的 miniHeavy 自然搜撤 **FAIL**，4 项通过、11 条运行错误，证据 `evidence/salvage-natural-manifest-11e3cbe9-2026-10-15T08-50-34-344Z/`。真实工坊采购与完整投放、鼠标捕获已经成功；83.37 秒首次伏击动态创建敌车时，`PartAssets.Model` 拒绝尚未下载的 `Parts/Models/96a6a08cd9ad7644de6feefe.bin`，调用来自 `Run→Director/CarUnit→CombatView.Consume`。已打开失败图核对：玩家在场、伏击 HUD 已出现，不能把画面存在当成运行通过。
- 根因是实际 `App.EnterTrial.options.resources` 没调用已经完整枚举原敌池的 `salvage.Run.Dependencies`。root 已把该模块加入共享打捞入口下载列表，仍待新统一包；保留 PartAssets 就绪断言，不采用屏蔽错误或擅自延后原敌车生成。独立短检将捕获真实入口列表并逐辆走原敌池的 Bullet/CombatView 模型创建，自然成功撤离继续 OPEN。
- 17:15 真实入口资源短检 **149/149 功能 PASS**、Lua/资源错误 0：实际 `App.EnterTrial('salvage')` 的 `options.resources` 为1470行，包含全部12组×4敌车的213种唯一依赖，`96a6...` 确切属于原 `kite` 四变体的 `hover3`。48车逐一实际 `Director.Add→CarUnit/Bullet→CombatView/DriveView/PartRig` 创建、消费模型、移除并释放，门禁保持开启。证据 `evidence/salvage-resources-2026-10-15T09-13-24-813Z/result.json`；采用隔离 miniHeavy/原测试库存入口前置，不是自然驾驶或平台账号证明。
- 上述检查整体 **FAIL**：34条100ms阈值尖峰，最大6989.22ms；该帧包含入口资源枚举与夹具额外构造全部48份蓝图，不能把整帧都归因于生产。已窄改 `Run.Dependencies` 复用已有 `Parts.Dependencies.FromBlueprint`，避免为下载清单构造碰撞格/连接图；新增逐原车集合等价检查、实际callback独立计时，等待音频独占结束再跑。没有提高100ms阈值，动态建车的100–280ms尖峰也未关闭。

源固定 `2026-10-14 / 2b169a9964645f5f346a7158bcb14447f040814a`，快照 `.tmp/outgame-source-2026-10-14T10-09-50-505Z`。本批只补 L01/L05/L08 与 D03 中已经发现的缺口，不重启 G0。

源 `shared/salvage/{stash,session}.js`、`shared/build/editor.js` 和 `shared/css/{salvage,new-ui-salvage}.css` 是行为/样式依据。源测试填仓 999 保留；没有擅自修改货币、仓库容量或消费规则。`buyAll` 与普通单件交易不同，不检查散件格数，因为整车和补买的零件立即用于装车。

## 本批实现

| 对应项 | 已实现 | 边界 |
| --- | --- | --- |
| L05 整批采购 | `StashRules` 精确计算需求/散件缺口/价格，`SalvageLobby:BuyAll` 一次写入，失败恢复整个数据对象 | 原生源夹具与失败回滚已验 |
| L05 缺料建造 | 同一编辑器 Commit/Undo/Redo 检查所有打捞车位与当前草稿总使用量；缺料打开原采购，购买后重做原操作 | 不允许靠撤销恢复已经卖出的零件；Dispose 恢复共享历史方法 |
| L05 零件库 | 没有可用散件时显示采购，提供 ×1/5/10/20，买完选中该零件 | 真实库存接口；没有另建一套库存 |
| L05 工坊整车 | 整车全价、使用现有散件仅补差额、满车位拒绝、取消、余额不足禁用；经已有异步换车链路放入实际车位 | 放置/存档失败恢复信用点和全部零件，保留 discard 原因 |
| L01 建造入口 | 打捞内导入与载入蓝图库被拦；新车/切车在大厅完成；保存与分享仍允许 | 源 stock.blocked 不拦 save/export |
| L08/D03 恢复输入 | stash 校验有限安全整数、已知物品、非负库存、进度、统计和 runId；CloudStorage 实际 Decode 复用 | 真实平台账号刷新/跨设备还没有证据 |
| L08 出击统计 | 对照源 `salvageRun.begin()` 开局持久记录 raids；`lastStartedRun` 防重复开始/结算计数，开始写失败完整回滚后由结算补计 | 两代存档重开通过；真实账号中断恢复仍需验 |
| L01 遭遇还原增量 | 巢穴 8 次安全落点采样与朝外、巡逻隔点出生朝下一点、营地原环形散布朝外、伏击朝玩家、源 tier/seed 与巡逻半径 6；车队清除额外 ore/cell；最近遭遇原 calm/alert HUD 与追兵提示 | 新增原生规则夹具；实际自然遭遇、渲染/AI/长局稳定性仍需新包验证 |
| L01 局内目标指引 | 源 `_objective()` / `.srh-obj`：最近未搜索核心件；货舱 ≥15/20 格或时间 >600 秒切最近已开放撤离点；随镜头转箭头，运镜/撤离时隐藏 | 决策在 HUD 原10Hz刷新复用，箭头方向实时；新包渲染尚待验 |
| L01 拆卸反馈增量 | 原拆卸每秒 heat+1，按住时显示“拆卸中…”；核心拆完原 .3/.6 flash 与2.4秒 nameCard | 两条规则检查已通过；最终反馈渲染仍待新包 |
| L01 撤离信标 | 锁定红色、开放青色、撤离绿色；独立 SurfaceShader 恢复原呼吸透明度，静态光束与环不逐帧重建，初始化即更新锁定状态 | 原生真实材质/几何/状态检查通过；最终网页渲染仍待新统一包 |

## 验证证据

- `verify-stash.ps1`：**70/70 PASS**，运行范围错误 0。夹具直接执行冻结源 20 组 buyAll、4 组 shortfall、2 组蓝图需求，并检查损坏 stash 经实际云解码拒绝。报告 `evidence/stash-native.json`。
- 发现本 Runtime 浮点 fast-math 下 `NaN == NaN` 为 true，`math.huge` 为 1e300；已用 `string.pack/unpack` 检查 IEEE754 指数位，并限制安全整数，NaN/Infinity 实测拒绝。
- `verify-salvage-buy.ps1` 初轮 **14/14 PASS**，运行范围错误 0。实际 UI 与生产调用覆盖缺料→补买→重做、×5→选中、Undo 缺料、取消、整车失败退款与 discard、整车成功扣款、Dispose。
- 扩展复验 **20/20 PASS**，运行范围 Lua/资源/引擎错误均 0（`evidence/salvage-buy-native.json`）。新增真实虚拟库存缺货卡点击：旧库销毁后打开采购，购买后重试原选中；检查回滚未完成时保留已付款记录。Runtime 已正常退出。
- 已打开并检查完整淡入后的 `salvage-buy-{missing,car,inventory}-native.png`：缺料采购与整车采购正常显示，源 580px 卡片、48px 缩略图、数量/价格行与原按钮已渲染；库存缺货“＋购买”标记可见。这是原生布局检查，不代表网页/真机或逐像素复刻通过。
- 首次测试误用不存在的 `Blueprint:All`，立即停止并修测试用 `parts`，未改生产蓝图 API。初次截图处于淡入第一帧，不能算视觉通过；已增加 28 帧等待。后续改成源 580px sv-buy 专用布局、原列表尺寸和字体，需截图复验。
- 后续补原零件卡 `×剩余数 / ＋购买` badge、缺货不可拖动、指定快捷栏补买。库存数量只在开库时按同一 usage 计算，避免每个卡每帧扫描全部车位。修复缺货点击打开采购销毁原零件库后，旧回调继续访问 Detail/hotbar；实际虚拟卡点击已列入扩展原生检查。
- 公共云元数据的 `v/generation/time/deleted/capture` 与本地两代读取现复用 `storage.RecordNumbers`；Hydrate 写前拒绝坏元数据，代数耗尽拒绝增量写。root 的统一原生检查313/313 PASS含新坏数夹具；独立fixture需同一Runtime排队，不另起窗口抢焦点。
- root 同步修复 Garage 创建车位后切换失败的残留槽；若清理失败返回 `rollback`，采购保留已有付款和零件记录，不错误退款生成免费车。普通完整清理失败仍按源退款。
- 网页同构建 QA4269 / `manifest-8d52110f` 的 PC1600×900 和横屏1440×648 各 **5/5 PASS**、错误 0：真实进入打捞、工坊、取消不添车、使用散件采购后只增加一个车位。两比例采购窗截图已查看，没有裁切。
- 上述数据检查后的截图发现实际页面遗漏：购买后 `s.tab=salvage`，但子页仍是工坊。源 `shared/ui/shell.js` 成功后明确 `salvageTab('garage')`；现已对应修复并增强浏览器检查，必须找到实际车库“拆掉这辆车”控件。旧证据另存 `salvage-buy-web-{pc,landscape-20-9}-8d52110f-before-garage-fix.json`，不能作为修复后通过证据。
- 修复后统一 QA4271 / `manifest-b3a7f84f` 再验两比例各 **5/5 PASS**、运行错误 0，实际车库页按钮必须出现。最终截图真实选中“车库”，新车位“蝎型战车”已装入，余额 3656 = 8000 − 4344。`salvage-buy-web-{pc,landscape-20-9}.json` 带完整构建身份。跳转修复后原生亦复验 **20/20 PASS**，错误 0。
- 查看 `salvage-buy-web-landscape-20-9-placed.png` 发现车库顶部近距离屋顶白面，已交 root 排查视锥碰墙；该截图不能签署车库整体视觉通过。
- `verify-salvage-settlement.ps1` 最终 **25/25 PASS**、运行错误 0（`evidence/salvage-settlement-native.json`）：实际 Run/Rules 覆盖撤离凭证消费与入仓、死亡/900 秒超时损失原车件、放弃保车丢货、写失败回滚及阻止返回、重试一次入账、实际两代存档重开与云记录解码。新增真实 `Run:Begin()` 开局就存 raids，重复 Begin 不重播投放/计数，开始写失败后结算只补计一次。
- 结算夹具使用隔离 store 与受控会话 Pause/cine 回调。不是自然完整搜撤路线、敌人实战导致死亡、真实账号刷新或真机性能证明；这些验收不隐藏。
- `verify-salvage-director.ps1` **18/18 PASS**、运行错误 0（`evidence/salvage-director-native.json`）：生产 Director 的巢穴采样、巡逻朝向/下一路点、营地散布、伏击即警觉、车队额外奖励且不污染共享表、受击警觉/距离隐藏、热度追兵；生产 RunRules 的核心优先/75%货舱/严格600秒门槛/开放撤离选择。Unit 创建/地面射线在此夹具受控，原 AI/物理实战仍待下一统一包。
- 冻结源的四格带入道具已有 UI 和物品描述，但 `three/src/salvage/salvageRun.js` 及 `shared/ui` 没有维修包/烟雾弹/护盾电池/扫描脉冲的使用逻辑引用，相关 three 引用只在缩略图。忠实迁移保留原选择与描述，不把自行发明道具效果当成1:1迁移。
- `Run` 与 `EndlessSession` 向公共 CombatEffects 传入远端标记，敌方开火不错误触发玩家本机的武器镜头震动；公共 feedback 由 root 集成。
- 最终 `verify-salvage-director.ps1` **24/24 PASS**，Lua/资源/引擎错误 0：新增拆卸热度/核心事件和真实 Scene、SurfaceShader 加载、锁定信标可见/开放/撤离状态、260米光束实际 worldBoundingBox。首次夹具错误读取没有定义的 `CustomGeometry.boundingBox`，在21条后停止；失败报告 `salvage-director-native-bounds-fixture-fail.json` 保留。查引擎 Drawable 文档后改用 `worldBoundingBox`，没有修改生产几何绕过检查。该fixture不构成最终信标画面或自然撤离验收。
- 部分采购验证使用可控放车失败和 Save 失败注入；不能替代真实账号存储、自然搜撤四种结算或完整车辆保存回读。

## 公共挂钩

- `BuildSession.New`：Hud.Create 后 `require('app.SalvageBuild').Attach(self)`。
- `GarageHud.CreateVehicle`：打捞且非 empty → `require('ui.SalvageBuy').Car(s,id)`。
- `BuildSession.OpenLibrary`：打捞只拦 load，允许 save；`BlueprintLibrary.Open` 和 `GarageDialogs.Code` 已有防绕过检查。
- 公共挂钩由 root 集成；本批所有代码仍在同一工作区，没有提交、上传或发布。

## 下一步

## 10月15日继续：真实搜刮与源特效

- `manifest-935b3961` 追加自然成功撤离尝试 **FAIL**，4条已完成检查、运行错误0：实际驶到L41并搜索收取3格货，去E3东河谷途中在约 `[-889,-20,-154]` 受地形阻挡，240秒真实键盘路线未达到撤离区。完整证据 `evidence/salvage-natural-manifest-935b3961-2026-10-15T05-58-02-229Z/`；没有传送、货舱/时钟/生命注入，浏览器已关闭。该失败说明本次直线路线未完成，未据此修改源地形或判定结算实现错误；自然成功撤离仍OPEN，后续须沿实际道路规划路线。
- 接续测试脚本支持 `VOX_NATURAL_ROADS=1`，直接读取地图原 `nav` 的845节点/908边求最短路，按原路宽控制接近半径与弯道速度；仍只读F8状态和按真实W/A/D/Space。L41→E3离线核为R9:76→R8:124、105路点、1659.61m，逐边确认均在源图；语法检查通过。该离线检查不代表实际开到，等待g4独占音频结束后运行。
- g4独占音频结束后 `manifest-b8b63ade` 实际原路网搜撤仍 **FAIL**，4条检查、运行错误0：本次原随机出生靠近L72，实际搜索收货成功，前往R9:92途中被6辆敌车攻击并受阻，35秒路点期限HP降到6.5%。失败图已打开，拍摄时死亡爆炸/电影黑边已开始，但脚本退出前尚未获取正式死亡结算，不能算自然死亡结算通过。证据 `evidence/salvage-natural-manifest-b8b63ade-2026-10-15T06-21-00-299Z/`；实例已退出。测试脚本现追加低血失败后的自然死亡等待/真实结算返回检查，搜撤原失败依然保留，不以死亡覆盖为撤离PASS。
- QA4275 / `manifest-cbebfb9c.json` 的真实键盘自然路线 **7/7 PASS**，运行错误 0、probeErrors 0：W/A/D/Space 实际驶到 L41 补给箱、E 搜索并拾入货舱、T 放弃保原车丢货、真实点击回大厅并等待遮罩释放。证据 `evidence/salvage-natural-manifest-cbebfb9c-2026-10-14T19-43-03-567Z/salvage-natural-web.json`；已打开查看 looted/returned 图。仅 F8 读取状态，没有传送、时钟/掉落/生命注入。这证明自然放弃路线，不能代签成功撤离、实战死亡、超时或真实账号云同步。并发功能运行也不算独占性能采样。
- 撤离信标进一步对齐源 24 段光柱 / 64 段环及 sRGB→linear 颜色，最新 `salvage-director-native.json` **25/25 PASS**、运行错误 0。最新精确网格修正尚未收入 cbebfb9c，不能用该包签收增量。
- 新 `render/SalvageFx` 和 Marker/LootBeam/LootCube shader 恢复源交互地环/白弧/悬浮四角标、稀有开箱柱、16 枚错峰飞行拾取方块；均固定池/静态几何，不逐帧重建。独立真实 Scene fixture **15/15 PASS**、运行错误 0，已查看 screenshot；首次 Material 局部函数遮全局和 INSTANCE_COLOR fragment 阶段错误的两份失败报告保留。该独立测试尚不能代签实际 Run 挂钩。
- `Run` 已接目标/破解进度与 Fx 生命周期，wreck 拾取改按真正取到的分组发 `worldLoot`，容量为零不虚播拾取；最新挂钩还需原生链路复验和下一统一包。
- `tools/migration/export-salvage-fx.cjs` 用 Acorn 从冻结原 `salvageFx.js` 提取实际 puffTex/dotTex，在 Canvas 固定随机种子导出原生成纹理，六张共 79,602 bytes。证据 `evidence/salvage-fx-source-textures.json` 记录源/输出 SHA；是原程序资产导出，不是另画替代特效。专用火/烟/余烬爆炸正在接续，尚未宣称完成。
- 稳定 Run/Fx 挂钩扩展后 `salvage-director-native.json` **29/29 PASS**，错误0：真实 Run.Events 消费 grouped worldLoot，wreck reveal 不重复稀有光柱，成功拆卸仅一组拾取，满仓不消耗残骸或虚播拾取。
- 新 `salvage/ExplosionRules` 直接对应冻结原 class；原 JS/实际 THREE 两组正常/精英900帧、18快照黄金 **7,169/7,169 PASS**，错误0（`salvage-explosion-native.json`）。首次72项只在未激活 ring.t、缺省 light.peak及 material alpha钳制差异，失败报告保留；火/烟/碎屑/余烬/持续余火的动力学采样全部匹配。余烬源Float32Array每写舍入与Lua double间用明确容差，未擅改运动。
- 新 `render/SalvageExplosion` 240火/40核心/200烟/600余烬、4环/2固定灯，6原纹理、GPU朝向/颜色/尺寸动画，真实Scene三阶段 **14/14 PASS**、错误0。已看非空图；初图固定随机.5导致重叠且教程层挡画面，不能签署完整1:1质感，正在补正常seed的干净图。稳定材质按kind/texture共享，不战斗临时建池或重建几何；手机性能仍未验。
- Explosion已接 Run敌车击毁/玩家死亡、Cinematics每render更新（投放时预热、死亡继续）及依赖/释放；该挂钩在 `manifest-935b3961` 快照之后，仍需真实Run回归与下一包，不能拿该Web包签收。
- 后续真实 Scene 与真实 Run.AfterStep/Events 挂钩扩展 **16/16 PASS**、Lua/资源/引擎错误0（`evidence/salvage-explosion-view-native.json`）：实际敌方击毁使用原半径上限与elite倍率，玩家死亡播原大爆炸且继续死亡运镜；240/40/200/600固定池、共享材质数量及GPU参数无增长。28/90/180帧图已打开，火/余烬/冲击环及上升灰黑烟均非空；独立教程通讯层仍挡中心，不能签署干净1:1最终画面。此证据验证当前工作树挂钩，仍非935b Web或手机性能。
- 最新短检 **19/19 PASS**、错误0：fixture仅关闭实际教程后28/90/180帧清晰图已查看；生产未为截图改教程。修正余烬原 `PointsMaterial(size=.55)` 的投影：冻结 `three.module.js:569/15308-15309` 使用 `size*dpr*height/2/depth`，billboard须除实际 `PROJECTION_MATRIX[1][1]`；实际 Camera.WorldToScreenPoint 在30/60/90度验证同一屏幕点尺寸。此单行shader增量在 `manifest-b8b63ade` 冻结之后，下包才含修复；此前16项报告另存 `salvage-explosion-view-native-before-points-projection.json`。火/核心 toneMapped 标志与引擎整场调色仍未做逐像素对比，手机性能未验。
- 期间三个新增验收fixture出现全NUL、长度不变的工具文件异常，导致一次测试载入错误（`salvage-explosion-native-nul-fixture-fail.json`）。仅重建自己新建的fixtures；root扫描生产scripts与935b全部Lua的NUL文件数为0。没有据此回滚任何共享生产文件。

采购已通过同包真实双比例点击和淡入后截图；开局统计增量需进入下份统一包。继续接自然搜撤/死亡/放弃/超时、结算后真实账号刷新恢复。真实平台身份缺失、原生字体与 H5 逐页对照、手机持续性能均保持未验收，不将 L/D 整组标完成。
