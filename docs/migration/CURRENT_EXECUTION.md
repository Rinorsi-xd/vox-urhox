# 当前迁移执行位置

恢复工作先读本文件，再读总计划和各并发任务的进度文档。不要重复从 G0 开始。

## 固定基线与运行包

### 最新整理增量：接续 d6fcf0de

- 按用户“整理成最新版本、干净一些”的要求收口本批，不扩展新功能。本地最终检出 `main`，与 `codex/h5-2026-10-15` 和私有 GitHub 两个同名分支同步；当前源码以 Git HEAD 为准。H5 最新分支再次实查仍为 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`。旧无父交接分支没有合入。
- 新收入逐事件鼠标尖峰过滤和 Space 无 vehicle owner 空扫描跳过；root 重跑实际 Lua 5.4 分别 8757/8757、85132/85132。只签离线行为，尚未实际 native/Web/真机验收。本批没有新运行包，4331/4332 的 d7af 均不包含这两项，不可用旧包结果签新代码。
- 七份当前 CPU profile 的分类报告和原始聚合已整理。稳定战斗主要落在未符号 WASM，不能直接说是 shader 等待。32/64 米散布分组实测改变组中心距离语义，明确拒绝生产接入；最终 native validator 未产出，整体不签通过。完整实验记录保留，不继续新实验。
- 上批零件详情 Web 会话 70055 已正常完成：22项检查、12个源/目标页面状态、运行错误0。已查看 PC 天元钻头与20:9夫元钻头四张配对底部图，发现 PC 断行和20:9布局比例仍不一致；G2视觉未关闭。本批只整理证据，没有凭数据一致签页面1:1。
- 精选本批报告与四张配对截图归档 `verification/2026-10-15/`。下一迁移工作继续现有 G1/G2/性能待办，先统一新包验证鼠标/物理增量；不从G0重启，不把仓库干净当迁移完成。

### d6fcf0de 整理时的运行包

- 当前开发分支已切到 `codex/h5-2026-10-15`，对齐 H5 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`。按用户最新要求整理当前完整开发成果并同步私有 GitHub 的开发分支与 `main`，不合回旧无父交接快照。具体包含内容和验收边界见 `LATEST_VERSION_2026_10_15.md`；整理提交以本分支 Git HEAD 为准。旧 706d 分支只保留性能复现用途。
- 最新实测包 `manifest-d7af571f.json`，`.tmp/outgame-cached-1792074566364`，467 Lua 逐 SHA 匹配，指纹 `99ac8e3ba04b01496c10f33175ce2bed8bbe724ea971f331cd2ec74ec2b3a04d`。普通预览 4331、QA 4330。两次公开菜单实际匹配/驾驶/射击/瞄准/退出完成，运行错误 0，右键 8/8、会话/小地图生命周期 4/4，退出后自有渲染目标 0；两次局内及返厅截图已查看，小地图有实际场景。性能仍 FAIL：首局 live p50/P95 110.990/139.170ms，二局 117.805/145.785ms；首次加载最长 4708.205ms。原始报告与 CPU profiles 精选收录 `verification/2026-10-15/`。包身份中的 targetCommit 为整理前父提交 ad72080，具体脚本以逐 SHA 和指纹确认，不能误说测的是未改的父提交。
- 本批已收入 shell 材质共享/所有权释放（native 413/413，性能 FAIL）、MapShot 下载取消/兼容及真实底图 rebake（103/103，图片字节未改）、331 零件详情/钻头行/数字字体（离线 5867/5867）、源狙击伤害/穿甲/溅射数据及 Beam 事件字段（native 3729/3729，性能 FAIL）。散布细分仍只是 QA 实验，未改生产地图、未做实际配对渲染，不算优化通过。
- 仓库整理已排除 SDK/cache/临时包/用户存档/批量历史截图和可重建 source fixtures，均保留本机原文件；保留当前精选实测材料。G0-G6 继续原进度，严重战斗帧率、冷加载、整体视觉/手感、完整自然剧情/无尽/打捞、真实账号/编辑器与手机持续性能仍未关闭。下一性能工作沿实际 CPU profiles 与散布剔除实验推进，不从 G0 重启。

## 历史执行记录

以下记录描述各次更新当时的分支、运行包和待办，不代表当前分支状态；最新状态以上方和 `LATEST_VERSION_2026_10_15.md` 为准。

- 本轮继续原G0-G6，不从G0重启。已实查分支区别：H5当前`2026-10-15 / b276064`，迁移基线一致；UrhoX本地仍`codex/h5-2026-10-14 / ad72080`且大量迁移尚未提交，私有交接`5e45931`为独立ref，GitHub默认仍main，不可说本地已切新分支。下一候选待统一构建：ShellMaterials第三次真实native413/413功能PASS/22租约归零/可见模型18PNG，338个>100ms尖峰使整体仍FAIL（零Lua/resource，stderr既存DDS/themis另列）；MapShot生命周期103/103及真实rebake4/4PASS，1146输入check通过，图像字节不变；G2正补InventoryDetail钻头专属行与tabular数字字体。root新增QA-only弱引用资源所有权观察及公开输入重复匹配进出，待新包验证，当前普通4329仍706d。g5仅制作静态散布细分剔除实验，不改生产地图或烘焙输入；legacy只拥有InventoryDetail及新Rows模块。生产全程GPU测试串行，离线工具并行。
- GitHub私有交接已完成并经API复核：`https://github.com/Rinorsi-xd/vox-urhox/tree/codex/engine-handoff-2026-10-15-706d`，commit `5e45931519fab260f0a93f7aa5c2dd11e7131109`，仓库仍private。无父独立快照15758文件（含自身外的15757输入清单），runtime严格来自706d固定包；仅明确工具/文档和约1GB运行资源，排除27份约123MB可重建fixture与本机SDK/cache/saves。隔离GIT_INDEX_FILE建提交，未切当前`codex/h5-2026-10-14`/未覆盖本地工作区。入口`docs/migration/ENGINE_TEAM_HANDOFF_2026_10_15.md`含实测性能失败及原始CPU profiles。用户可将该分支给引擎部，未代发消息或开PR。后续三路仍继续：g4 shell材质native夹具（生产候选已冻结，不属706d）；g5修MapShot取消/兼容+重新烘焙；legacy查真实字体队列去重。未签完整G0-G6。
- 当前用户新增授权上传GitHub私有仓库给引擎部；已实查`Rinorsi-xd/vox-urhox`为private且有ADMIN。准备单独交接分支，只取真实测过的706d快照runtime，不混入后续shell材质候选；附源码资源/精确构建/CPU profiles/原始失败报告，不上传凭证、SDK、.tmp或用户存档。706d普通4329/QA4328，`.tmp/outgame-cached-1792072535275`，指纹`2bfcec5e7a9851ca7da857a59f0f70b999c41b25a3b5c8fa8b405e3cd8eb1fda`，465 Lua逐SHA一致。真实匹配`13-56-49-208Z`错误0/右键4项PASS，但live中位111ms、P95 145.965ms、max215.405ms，进场max5104.195ms，整体性能FAIL。真实破坏`14-01-57-237Z`17项PASS、55 Flush max27ms、射击945帧max69.69ms且>100=0；只签射击窗口，boot/practice-loading仍FAIL。底图captured/ready而无RT views/captureFrame，与baked分支一致；后续新增代码不得套该结果。root负责私有分支推送与精确交接，三个agent继续独立工具/首启资源/审查。
- 本次并发继续推进，未重开G0：g4首发尖峰定位到实际同帧首次Stencil/实例点光shader编译，CombatWarmup新增加载期有界临时探针，22离线场景PASS，待新包Web；g5已烘焙真实陨坑静态底图，1145输入校验PASS，缺失/过期回退41/41，离线原生烘焙本身整体性能FAIL保留；legacy无用地面查询140793前后断言+23455 H5黄金PASS，并续做Nav边索引精确等价。root真实45声音分帧解码与构造复用140/140原生PASS、错误0，最大解码分片5ms、缓存构造1ms；仅签孤立native，不签Web/手机。上述增量均不属于普通4327的04a包，当前下一步固定统一新包实际加载/首发/破坏与小地图复验。
- 用户要求继续多线程，当前三路已重新派发并实际推进：g4已结束04a公开鼠标射击/拆件/击杀Web，继续分类可选引擎包404与首发138ms尖峰；g5接地图离线真实烘焙/元数据/过期fallback，当前独占native；legacy基于实际CPU证据优化EnemyDriver无用地面射线，离线逐步等价核对。root音效资源预解码分帧已落scripts/audio/SoundPreparation.lua，TrialSession音频段接线，Lua5.4分帧/去重/取消/错误检查通过，新包真实时间待测。普通4327仍固定04a，不随工作区新增改动漂移。
- 04a HUD专项实际完成：PC1920×1080与20:9 touch840×378各5/5状态检查、运行错误0，两张全图和crop均已查看：比分/000分离、N在上、凹箭头完整、真实底图建筑道路清晰、无边沿拉伸。独立视觉结论`evidence/hud-04a23389-visual-review.json`，原工具report的PENDING不冒写成程序像素断言。只签本次重叠与缺地图，不签全UI/性能/真机。
- 最新运行包已前进04a23389：普通4327（同包无探针）、QA4326，`.tmp/outgame-cached-1792071037109`，脚本`ee0e9dfe08f03dc62cacfd80f40386a546386e4ee0ccfe7d114393bf01a90af6`，QA只读探针`2ad919eab0ac1716f903611a350f21a1c1af498b2cc82714633d434d247b5d09`，两端identity实查一致。9e05的实际PC已成功进场/HUD5项状态PASS/errors0，截图确认比分与罗盘分离、地图有真实地形；仍发现Web重复翻转使N在底部、map imagePattern填满RT导致边沿拉伸。04a窄改MatchMinimap为无额外Web翻转、底图仅画投影矩形（与源drawImage一致，不额外铺背景），SHA862542d0...da35c5e，PC后20:9最终Web复验中。g4已准备真实试车射击/拆件/击杀回归，等待root完成两个HUD浏览器后独占4326，不并行争运行资源。
- 最新Web修复候选QA4324：`manifest-9e05de29.json` / `.tmp/outgame-cached-1792070723091` / `a6210aa2e2eaf6a3ce87162e5de8f3a9bf09102f0062d30b0e0c54e8881970fd`。3a0真实PC加载在minimap超时，证据13-14-15；同生产只读诊断13-20-53证明Begin/End事件camera与texture各67次完全匹配，但生产views仍nil，协程注册回调未执行。候选改main.Start主线程Initialize、Stop中Shutdown（main a9737c4f，MapShot60c6a345），QA移除额外事件订阅只保留New/state观察，避免干扰。第二次完整Web进场正在实测，不能拿旧native结果签新Web已修；前两包均不交付。
- HUD最终候选已固定：QA4320，`manifest-3a0f7886.json` / `.tmp/outgame-cached-1792070001444` / `a9fbf3d87c6796f0cccfc9692910f234a5a473e4449cc686a31c53b36085f28f`。MapShot最终`c218a41d...b66f1ba`、Minimap`42e75518...24a4baa`、TrialSession/BattleController/TurretRange/CombatView/VehicleView/ReticleGauges共8生产文件逐SHA匹配，收入10/15三车/20零件/品牌和质量合并约束。MapShot最终实际native33/33功能PASS、clip像素27/27PASS；PNG保存帧110.197ms使最终native整体仍FAIL。PC与20:9真实Web专项正进行，未冒签小地图实际网页内容；状态probe的base/frames不作为像素验收。3143781b为尚含错误Octree指针转换的中间候选，未进入浏览器且已停服务，禁止交付。
- 续接HUD/小地图专项：10/15基线已激活为`2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`，冻结输入2168项已核SHA。竞技罗盘漏原版向下100px位移已补；离屏NanoVG无stencil导致底色/凹箭头失效，改源形状alpha遮罩与两个凸三角。MapShot旧runtime必须关闭`fogStart/fogEnd/fogDensity/heightFog`；四块场景实际捕获已有布局，但新查到陨坑drawDistance150/220米会被1200米相机裁掉，g5补仅捕获视图覆盖和恢复。中间包`697eafb4`/`.tmp/outgame-cached-1792069804300`/`836d9a619bda2a4e99842bb31c6d47b1ddf028f124a09f9b23a5341a027d6908`尚缺距离修正，QA4320暂为中间候选，不作修好交付。
- 破坏专项更新：实际native证据`evidence/damage-native-timing-2026-10-15T13-05-13-104Z`，152/152断言通过，Lua/资源错误0。精确TurretRange样本缓存使MEGA三次存活拆件224/320/225ms→43/43/50ms；死亡静态视觉按零件身份转移，最新Consume28/29ms、动作总计42/44ms。1924项等价检查通过，初次构造多约100–200ms，加载仍需分帧。整体仍FAIL：63条整帧>100ms，不能签Web/手机或全战斗帧率；下一步同一最新包真实鼠标射击/击杀回归。
- 接续最新用户HUD截图：不重开G0。已确认顶部`000`为竞技罗盘，漏源`100px * --mh-ui`位移；g5已补。小地图实际RT像素证明原圆形hole/凹箭头在离屏无stencil时擦掉底色、箭头变方块，显式排序无效；g5改凸形遮罩/两三角箭头并接真实地图一次捕获。root已备实际公开匹配PC/20:9专项，等待统一新包；旧4319不含修正，不得报已修。10/15源HEAD已实查为`b276064942ae09c0227ec28d4cfda1d5ff006455`，三车/20零件/fox/品牌增量已落，基线激活和地图实际Web待收口。
- 击碎卡顿并线实际native分段已完成：`evidence/damage-native-timing-2026-10-15T12-48-18-043Z`，136项非性能断言通过、6动作超过100ms，整体FAIL；MEGA存活Flush216–304ms，死亡Consume250–302ms。g4负责TurretRange/Flush等价缓存，legacy负责死亡碎片显示复用；不能拿离线缓存命中或功能通过签真实性能。
- 当前破坏/击杀候选：QA4319，`manifest-8c7a8107.json` / `.tmp/outgame-cached-1792067264260` / `46b9302eb76556c5fcef3480883efac09337342b64d437f43cbf099bd2228029`。已逐hash核对伤车四模块、EffectBatch/JoinedMesh、TrialSession、击杀音频与HUD。收入邻接/炮管局部缓存、复用连通分析、空FX延迟native初始化、顶点颜色缓存、真实击杀定格/慢放/FOV/音效、积分22碎块与连杀、击杀列表/占点标记/小地图。小地图仍fallback底色，MatchMapShot未接线。legacy正在写公开输入真实击碎/击杀Web测试，g4写真实native重建/渲染分段计时，root统一串行实测，禁止把离线等价当性能PASS。
- 前包c346cd29（QA4318）真实Web已完成：错误0，右键短按入/出与长按松开退出4/4 PASS，scope及PAUSED截图已实际查看。性能仍FAIL：live p50 104.145ms/P95 131.99ms/max201.045ms，loading max5152.69ms；focus=true、minimized=false、maxFps60，不能归因失焦10fps限制。证据 `evidence/combat-performance-2026-10-15T12-24-22-048Z`。此前0b包因MatchBanner错误绑定GetSystemTime而FAIL，已按Time:GetSystemTime修正并在c346实际通过，不覆盖旧失败。
- 真实native深度像素检查5/5 PASS：普通Glow被墙正确遮挡，源ObjectiveOverlay刻意透视仍显示；仅签native该材质，不签Web或所有特效。34个100ms尖峰仍性能FAIL（隐藏native窗口10fps限制，max489.99ms），证据 `.tmp/effect-depth.json` 与out/err日志。地图尚无地理流式卸载/软件遮挡实施，不冒称已做。
- 10月15日最新并线：普通待启、QA4317（无细粒度CPU探针）固定 `manifest-0b4790c3.json` / `.tmp/outgame-cached-1792066463328` / `53c8fb04cd902b99b577fff2a3b0698c4521a493009760e79e9070767cf5deae`。含机械腿精确IK复用、真实会话FX预热、剧情刷兵规格预计算、PC Web 60帧上限修正、右键真实事件边沿/250ms、相机车辆遮挡桥、移除竞技全屏暂停黑罩/源横幅，以及源射击FX首批。root补占点3米墙、源水平距离淡出、overlay/volume拆批、橙色3+2米虚线与检查点柱，11项实际Lua几何检查PASS。新包真实Web性能/右键正在测，不能标修好。
- 前候选5e477668真实性能FAIL：细探针匹配live中位90.085ms/P95 132.035ms，关闭细探针同包仍104.13/145.94ms，错误0；两次随机阵容/机器运行差异不支持严格归因。第二次已真实captured但仍卡。证据11-56-32-513Z与12-05-42-944Z。不能用百万离线等价断言宣称性能已改善。剧情S3短路线仅parley、敌人0，不能签AI压力。
- 当前三个子agent续做：legacy已冻结右键/相机并接管掉件Flush/邻接图/炮塔射界缓存；g4已冻结射击FX并补击杀音效/碎块真实事件链；g5已冻结横幅并补积分/击杀播报、占点/推车UI、小地图。root统一构建/单浏览器实测。0b包已固定，各后续增量不得冒挂0b证据。
- 10月15日性能专项接续：不重开G0。最新UI包为 `manifest-b24c5ecb.json` / `.tmp/outgame-cached-1792063134142` / 指纹 `0ad8074d316775c6ed10abe2a811b156b23587ded7d7c2fccd471c6140a49579`，普通4311、QA4312；开篇长句三比例6/6与20:9 S5页面11/11实际Web通过，错误0，仅签专项。用户严重卡顿升级为当前优先事项：独占4313同生产包测量，第一轮匹配live rAF中位50.035ms、P95 83.405ms，进场最长3903.02ms，仍性能FAIL。首轮Lua构造函数计时包含coroutine挂起，不得把其总跨度当单次CPU冻结；已补扣除挂起的探针并重测。现场未见旧大厅在对局后台更新，整图驻留不等于地图流式加载。详细账本 `COMBAT_PERFORMANCE_PROGRESS.md`。
- 未构建性能增量：root修加载期间旧trial PostUpdate与开篇graphics重复更新；g5保留AI静态路网缓存并做物理步内精确读取缓存；g4补真实会话特效池预热；legacy做独立生命周期与加载热点复核。新包实测前不标解决，不更改100ms失败阈值。
- 当前UI/开篇/设置统一候选普通4308（PID45988）/QA4309（PID49020）：`manifest-264a138b.json`，`.tmp/outgame-cached-1792062486110`，脚本指纹 `7a31c714de0dfaa6147cdbe65152b8f5e4ab0a40a53b943146fded6fef62a356`，两端identity已实查，QA探针 `9f940873088c61ddc7ec1498aea1b91541b23abd7586e2116c2bc5ffde54b34b`。收入LA12–15、恢复FX、LB01–03、武器图标门禁、模式/匹配/剧情页面、S5精确派生全息、开篇独立漫画clock/原对话/纹理及统一设置。新包真实Web分三路并行：root设置与三Esc，legacy页面/匹配，g4自然开篇PC/20:9/1605×388。结果未回前不冒签画面或性能；e1faa514以下保留为历史证据。
- 最新增量候选普通4306（PID49676）/QA4307（PID42984）：`manifest-e1faa514.json`，`.tmp/outgame-cached-1792058408682`，脚本指纹 `11c223a54d66f2d77161e9134cd385494dc600c81926526a3aaa36dd0a270a15`；两端identity已实查，QA探针仍 `9f940873088c61ddc7ec1498aea1b91541b23abd7586e2116c2bc5ffde54b34b`。逐文件比较561，唯一脚本差异是 `ui/ResetProgress.lua`，无删除；修原body层CSS固定像素在UI.Scale .7被缩小。原生42/42、错误0、两比例图已查看；最终实际20:9 T→tap→R→取消6/6 PASS、运行错误0，证据 `evidence/practice-web-manifest-e1faa514-2026-10-15T10-01-08-429Z`，root与g5均打开最终840×378图确认固定像素生效。561已通过的完整输入矩阵仍只记在561，不改挂新包。自然倒翻触屏、狭窄空间及真机性能仍OPEN。
- 最新普通4304（PID41360）/QA4305（PID23752）：`manifest-561eef79.json`，`.tmp/outgame-cached-1792057687135`，脚本指纹 `d8ce9ddb44253bd039e60e4ee33941bb30d6dfdbc8c41881a03b363a32023165`，QA探针 `9f940873088c61ddc7ec1498aea1b91541b23abd7586e2116c2bc5ffde54b34b`，两端已实查identity。收入LA01/02/03–09/11候选、打捞依赖修正、字体14项增量和帮助wheel根路由。新包真实Web R/HUD/help三路功能验收正在进行，不冒签性能。中间0e775676（4300/4302）缺最终Scope坐标纠正、compact比例与help根路由，保留为未验中间候选，不作最终交付。
- 历史H5基线：`2026-10-14 / 2b169a9964645f5f346a7158bcb14447f040814a`；当前已切换上方10/15 b276，旧验收结果仍只属于旧包。
- 历史源快照：`.tmp/outgame-source-2026-10-14T10-09-50-505Z`已保留；当前以 `outgame-baseline.json` 中10/15 snapshot与哈希核对资源。
- 目标：`codex/h5-2026-10-14`，已有未提交工作区保留。
- 当前普通预览4295（PID3144）、QA4296（PID50408）：`manifest-11e3cbe9.json`，`.tmp/outgame-cached-1792053971537`，脚本指纹 `20a59fc6a04583dbc61910d3cf4125527e60b15df65e2f66f88da254d85c6c23`。两服务已实查 `/identity.json`；QA探针指纹 `2b32f2d79c1f598ced89883ffefe01f0dbdb6bb24b04e51879e0097aeac8c198`。收入2729全部内容及第二批准星/音乐字体、冻结帮助48条/整卡滚动、打捞工坊Update/键盘路由。新包真实Web验收进行中。
- 上一包普通4293/PID51780、QA4294/PID47684：`manifest-2729bc84.json`，`.tmp/outgame-cached-1792052961120`，脚本指纹 `cf3298c95984ca9f17bd7cec33345187763c015120ba690d44b72c93bdba1db6`，保留对应证据。含字体/DriveReadouts、TutorialPage实际touch目标、OpeningHost延迟释放及教程门禁、共享释放回调链、音乐图标路径缓存。
- 旧4289/PID46628、QA4290/PID48728仍为d6764c9c；g5已启动的自然打捞继续完成，证据明确旧包。QA4291/PID35384为同d676生产的downloadConcurrency=1受控实验，QA4292/PID48740为音频探针修正；均不代表当前2729普通包。
- 完整范围仍是总计划 G0-G6，138 个主验收项及后来发现的源功能；没有缩成比赛演示子集。

## 本批分工与下一步

### 当前四路并发检查点（继续实施，不重开G0）

- 264a本批统一设置真实Web已结束：PC18/18、20:9触屏14/14功能PASS，运行/探针错误0；root已查看两比例真实菜单PNG。实际三Esc经过PollKeys，依次释放/打开设置/关闭设置均不返厅；声音完成回设置、继续保留车辆通过。证据 `evidence/audio-settings-web-manifest-264a138b-2026-10-15T11-09-46-846Z`。依赖审计54/54与16项静态集成通过。g5独立查出开篇chunks字距丢失、完整句提前定框，g4将在保留264a三比例证据后精确补修；不因新包功能通过就签全部字体或1:1。
- 10月15日最新UI批继续原三位子agent：g4已冻结匹配页/开局横幅/顶部计分板首批，转修用户最新开篇截图；已证实IntroPromo每次Mark重置阶段age导致旧漫画格重复入场，按冻结源改每层独立clock，不能误改单图。IntroPage多余nametag、对白字体/按钮和分层亦逐项核对。legacy修StoryPage/Frame、实际预览语音及Outgame第五关ready/place/map旧数据；g5图标/真实Session专项冻结后接统一局内设置入口。root接资源门禁、模式入口颜色与最终统一包。新批未进入e1faa514，当前浏览器仍旧包，不冒签画面。
- 独立LB01–03已修：竞技8/80旧hover预制、Radio 10条语音与死池、两条随机名，701/701离线检查PASS，52源输入和116active WAV已核SHA，见LB01_03_DERIVED_SYNC_PROGRESS.md；未签新包实际对局/听音。WeaponIconResources真实Lua/ResourceGate/TrialSession恢复重建Dispose联合43/43功能PASS、Lua/resource0；303.132/1374.53/1414.8ms三尖峰整体FAIL且无viewport，非画面证据。root已接HangarApp与OpeningHost图标依赖，真实冷Web下载仍待。
- 用户再次要求独立检查旧版残留，已新建 `legacy_independent_v2`，只读生产代码/冻结源，不承担修复、不占运行窗口。独立报告 `LEGACY_INDEPENDENT_REAUDIT_2026_10_15.md`，新发现用LB编号，避免重复LA01–15。重点是剧情/自由探索/试车/三竞技实际入口、公共逻辑与派生数据，再查局外/建造/存档；区分旧版、遗漏、引擎映射差异和未证实。g4已完成LA13/14并冻结释放槽：最终1516/1516功能PASS、Lua/resource0，但3次100ms尖峰/max275.995ms仍整体FAIL，实际Web待统一包。root、legacy的LA12动态成员与g5恢复FX继续原有集成，不重开G0。
- 本批三路生产已冻结：LA12最终646/646功能PASS（含动态加入/移除单位标识），Lua/resource0，2个初始化尖峰仍总FAIL；LA13/14最终1516/1516同上；恢复FX44/44功能PASS、Lua/resource0，三张实际图已核对、光壳错位已修，261.779/970.869ms两尖峰仍总FAIL。root开篇PracticeSession→IntroBattle转移专项23/23功能PASS，Lua/resource0，5520.588/100.135/105.054ms尖峰仍FAIL，stderr默认Cube/Day贴图/themis初始化错误亦保留。均未进入e1faa514，不冒签Web或性能。独立复审首批已定位竞技预制车8/80和Radio派生差异，精确影响及验收以即将冻结的LB报告为准，不重复LA03复活规则。
- 新实施批已启动：g4独占ReticleTarget/新增ReticleFocus补LA13/14；legacy独占DriveOverlay/DriveFeedback/新增UnitMarkState补LA12；g5独占恢复FX/ReticleWeapons补实际恢复青光与掉件琥珀反馈；root负责LA15顺序及TrialSession/资源/生命周期接线。LA15原生753/753功能PASS、Lua/resource0，但15次100ms尖峰仍总FAIL，详见 `LA15_LAYER_AND_INTEGRATION_PROGRESS.md`；尚未进入e1faa514。原生窗口按g4→legacy→g5→root串行，代码/源核对并行。
- 源语义纠正：冻结combatFeedback.partLost是空函数，禁止迁回旧文字通知；实际源由武器槽琥珀闪烁替代。LA01审查备注已纠正，恢复青光与槽位完整动效仍待实现/验收。开篇替换阵容现清理旧PracticeSession/feedbackPlayer；UI导入工具已改冻结snapshot+8输入哈希只读预检PASS，无批量重导/来源标签改写。
- 独立复审已由legacy_audit收口，生产不改。报告共15个正式ID：首批11项保留，LA12普通头顶受击/低血状态（首批备注转正式）、LA13开镜focusPick挑选/保持、LA14目标信息牌arms/警告/低血、LA15 Scope/frame顺序。全部附精确源/目标证据与验收步骤，新增四项未实施；不冒称四项都是首次发现。g4确认20:9 RNG/EN几何冲突原版也存在，顺序差异另记，禁止借此自行移动原版位置。LA10导航已校正，派生来源风险仍保留。
- 561 HUD必要剧情复验已结束：PC13记录/12断言PASS、20:9触屏18记录/17断言PASS，运行错误0/gameHTTP失败0；真实step A、任务罗盘、机枪/狙击镜与返回释放均完成。证据 `evidence/hud-unification-web-2026-10-15T09-55-31-043Z/pc.json` 与 `20x9-touch.json`，root已查看横屏任务/无线电/触屏最终图。首轮boot阶段过早检查marker的失败原证据保留；不重跑已通过试车矩阵。浏览器均退出。全状态字体/样式、无线电与摇杆重叠、scope层叠和真机性能仍未签收；原生42项与功能浏览器并行，不能解释为独占性能证据。
- 561真实R最终PC10/10、20:9 touch11/11功能PASS、运行错误0，实际正常T/点击/R取消/重开/完成/4秒冷却/单玩家均通过；`evidence/practice-web-manifest-561eef79-2026-10-15T09-50-37-892Z/report.json`，两张进度图已由g5查看。发现20:9 ResetProgress常量随UI.Scale .7被缩小，源_resetBar在body外固定CSS像素；已授权仅该widget换算并补原生比例检查，其他生产继续冻结。自然倒翻触屏按钮未触发，仍OPEN。g4实际两比例试车/机枪/狙击scope已出图，PC剧情marker首次夹具在boot过早断言FAIL保留，等待自然阶段后复验必要剧情路线，不重做全矩阵。
- 561真实Web首批：root帮助页实际mouse.wheel(1600)经引擎-1600/no-hover根回退，scrollY 0→433.5，通过；help/help-bottom/settings/workshop截图已收，运行错误0，末条J/页脚图已打开，证据 `evidence/target-font-pages-manifest-561eef79-2026-10-15T09-49-07-610Z`。g5真实PC R10/10 PASS/错误0，已看真实读条PNG，20:9尚在验证；g4试车实际机枪/狙击scope已截图，root看过5.0x/RNG30M及无黑mask/公共HUD，剧情与20:9待回。以上不等于自然全部战斗/全字体像素一致或真机性能。
- 本批原生专项结果已收齐：LA01 33/33功能PASS、Lua/resource0，4尖峰仍总FAIL；LA02最终隔离39/39 PASS/错误0，真实读条PNG已查看，前两轮加载遮挡图不签通过；LA03–05竞技162/162功能PASS、2尖峰总FAIL；LA06–09/11最终752/752功能PASS、9尖峰max493.563ms总FAIL；字体增量14/14 PASS/错误0；帮助wheel根回退与生命周期29/29 PASS/错误0（首轮23/29夹具未制造no-hover已保留）。同包561真实浏览器功能验收正在进行。最新HUD记录已纠正Body.Wrap坐标误判并加真实非原点RNG5，0e775中间包不签收。
- 独立审查后续实施批：root LA01已接真实PracticeSession/CarUnit、合批PlayerViewSync及死亡触屏保护；首轮30/31捕获未接管鼠标掉图恢复失败，修到共享Tick后33/33功能PASS、Lua/resource0，100ms门限下4尖峰仍整体FAIL，证据与缺失恢复闪光/零件丢失提示详见 `LA01_PRACTICE_PLAYER_PROGRESS.md`。root已接LA02安全R及原读条到TrialSession/DriveHud，N保留在途弹丸，Backspace全复原；候选尚未进11e3。g4 LA06–09/LA11共用HUD与源倍率/无黑遮罩、g5 LA02真实OBB、legacy LA03–05竞技15秒/22米/共用恢复均继续专项短检，原生队列g4→g5→legacy；专项文档 `LA02_SAFE_RESET_PROGRESS.md`、`LA03_05_ARENA_PROGRESS.md`、`LA06_09_HUD_PROGRESS.md`（若后者未落盘以agent回报为准）。全项目仍OPEN，不以专项断言替代真实同包入口/画面。
- 独立旧版审查首批已交付：`LEGACY_BASELINE_AUDIT.md`。对照冻结2b169与当前工作区确认LA01-09玩法/UI遗漏、LA10过期基线文档，全部保持OPEN；每条附源/目标位置及真实入口验收。重点为试车/自由玩家CarUnit链、安全R重置、竞技15秒复活/22米占点及车体容差/共享脱战维修、剧情统一HUD/罗盘任务导航/伤害跳字字体。教程16步和flows实际一致、剧情维修已实现，未误报为旧版；导入器live来源风险另列。此为独立静态审查，不代表全项目已穷尽或已修复，不重开G0。
- 11e3自然开篇最新实测：38项功能PASS、运行/关闭错误0，但音频连续性FAIL（最大回调间隙2504.695ms、59候选断流，RAF最大1117.9ms）。破坏后的CarUnit.Flush为明确CPU热点，单次最高416ms；gate→hall最大间隙具体函数未定位。回厅Crater不驻留/cache约78MB，本路线未观察OOM；教程running=true但visible=false/voicePlayed=0，不能签自然路线教程可见可播。g4已退出独占运行，仅整理证据。
- 17:19用户新增“单独审查哪些仍旧版”：已暂停字体扩审释放槽，独立legacy_audit只读对照10/14冻结源，产物LEGACY_BASELINE_AUDIT.md。首批已复核ReticleState.Chips剧情旧尺寸/位置、ReticleGauges按story隐藏新版火控、MechReticle剧情旧长提示，和源10/13剧情统一新版要求相反；此为确认迁移遗漏。字体已落地三文件及待验项保留，不回退、不重启G0。原仓库HEAD5f0bc402比冻结2b169仅多音乐听审档案提交，模式差异不能归因源又更新。
- 17:06接续：root收回dbd65e2b真实Web帮助wheel FAIL/errors0（原始-1600事件已到引擎，scrollY仍0），保留证据并增加仅QA路由追踪，不能以native直接调用modal通过替代浏览器输入。g4已启动11e3/4296唯一自然PCM/deepCPU；root/g1/g5此时离线，结束后g5实际EnterTrial资源/全敌池短检→g1字体短检。字体生产新增暂停标题原22px行盒、涂装三处原tracking，未进当前11e3/dbd包。
- 16:58发现并修新功能阻塞：11e3 miniHeavy自然打捞83秒出现动态敌人Model requested before download readiness（96a6a08c...）。根因HangarApp.options.resources的salvage分支漏已有salvage.Run.Dependencies，已补入，guard保留；g5补实际entry load列表/敌池装配短检，修复尚未进入11e3。自然搜撤仍FAIL，不以已出发替代撤离。
- 11e3字体验收：驾驶详情PC5/5、20:9触屏4/4；音乐PC29/29、20:9 29/29、运行错误0。准星中文工业字/Chakra数字及描边实图生效，但描边为八向近似、设置字形着墨仍有差异（源已由CDP证实实际Alimama、font-synthesis:none，不能私自全局加粗）。root实际help截图显示原48条/原90%卡高，但真实wheel没动；已补modal壳转发，独立dbd65e2b/QA4298/PID2644检验，结果待回，不签11e3滚动通过。native原12项复验PASS/errors0。
- 2729 host两端最终均11/11 PASS/errors0/shutdown0，真实回厅教程T-01播放且Crater模型不驻留；20:9首次旧快照超时保留，真实失败图已有教程卡，freshF8复验确认。只签skipad公共host路线，自然sortie/PCM仍待独占测量。g4等待root/help与g1/build/livery退出后做11e3细分CPU自然音频。
- 字体第二批生产已冻结、下一统一包正在构建：g1补Web准星中文显式工业字体/原数字字体与3px描边、音乐盒原行高；root修帮助旧41条→冻结48条、kbd原正文/透明边框及90%整卡滚动。帮助native12/12 PASS、错误0，100ms阈值未失败；首轮9/11因夹具未扣scroll偏移FAIL保留。帮助旧数据来自过时导入器，已改为执行冻结UI._help再DOM结构化提取，避免旧41条断言继续遗漏。工坊打捞嵌套时遗漏Update/键盘转发已补，g5短检待回报。
- 2729实际字体截图补证：root PC help/settings/workshop，20:9 settings/workshop全部CAPTURED、运行错误0，`evidence/target-font-pages-manifest-2729bc84-2026-10-15T08-34-29-029Z`；真实查看，help仍旧清单/旧布局是此包已确认缺陷，下包修复，不签此页一致。g1驾驶详情PC5/5、触屏横屏4/4功能PASS，准星字体偏差另修后下包验。
- 2729真实教程PC24/24与20:9触屏37/37 PASS、运行错误0，实际编辑/保存/返回/重播和十槽高亮；前轮查旧“删除”按钮夹具失败保留。真实开篇skipad公共入口PC11/11 PASS、page关闭后errors0、回厅tutorial运行且craterResident=false/cache73MB；20:9采样门禁复验中。此非自然sortie/PCM或全S01通过。
- 新2729包已上线。g1实际Web音乐/驾驶详情PC及20:9；root实际help/settings入口/workshop字体结构；g4先完成native host释放再真实Web教程/host；g5完成已开始的d676合法T5自然搜撤。四路沿原进度继续，不重做已验旧项。
- 字体生产首批已完成并收入2729：音乐盒恢复原工业字，驾驶详情改回底部摘要/展开双栏/3.6秒标题。音乐35/35功能PASS；readouts88/88功能PASS，但224ms准备尖峰导致总FAIL。源自然PC与840×378 DPR3原截图已查看；源中的NaN和跨列宽度两项差异单独记账。新包视觉仍待真实截图，不能以功能断言签1:1。
- d676自然开篇音频37/37操作完成，但回厅后新教程21资源组引发OOM，整体FAIL。PCM最长1196ms/41间隙，仍未关闭音频连续性；旧原报告及补充analysis均保留。音频独占已结束，当前功能Web可并发。OpeningHost释放/教程延后候选已在2729，须新Web证明后才能关闭此条。
- 字体专线已由 `g1_fonts` 接手，复用已完成的g3并发槽，不重开G0。实际原版入口 `http://localhost:5173/three/`，26份CSS归一换行后与冻结10月14日源一致；音乐盒Windows错误改用Segoe UI已改回原VoxIndustrial/精确advance，尚未进入d676包。正在核对并修复试车仍显示旧左上详情与底部长键串的结构偏差，目标为冻结CSS底部摘要/展开网格；逐项进度 `G1_FONTS_PROGRESS.md`。
- d676共享加载真实20:9路线7/7 PASS、游戏/探针错误0，实际CDP双指放大/反向恢复/触点释放与返回已执行；加载页及试车截图已查看。证据 `evidence/loading-battle-manifest-d6764c9c-2026-10-15T08-07-30-447Z`。前轮期待旧“拉近”按钮的夹具FAIL保留在08-03报告；四条可选Windows归档404后逐资源回退，不等于必需资源缺失，也不签整体样式或真机性能。
- g4唯一自然音频改用QA4292/PID48740，仍同d676生产，修QA观察过早读取未Spawn combat.easy的guard；probe `62d618ad252202c9ecaef768d20ac3d47803dbb77484b23528272521dc3dd5f9`。4290旧probe及首轮bootguard失败原样保留。g1/g5/root暂不启动其他运行实例，离线代码与源核对继续并发。
- 16:01统一d6764c9c包已固定并验证身份，收入CollisionAudio事件unit/世界COM、BossHudMotion、原开篇Equipment/Chip/Missile预热及covered暂停3D/源.05模拟步长、SceneLoader进度watchdog、无尽Records安全数校验。root完整LoadingFlow772/772功能PASS/errors0，首轮旧夹具假机翼进入物理的失败已完整归档，未放宽生产物理校验；资源加载全生命周期联合进行中。g5 Records74/74 PASS/errors0。新包g3受控并发连续换图、g5真实T5自然搜撤、root实际PC进场/鼠标/滚轮/返回并行；全部功能退出后g4独占自然开篇音频。G5/G4及G3各ID实际账本已补，仍OPEN项不隐藏。
- 15:54 接续仍为 root + 三位既有 agent，不重新启动 G0。root 修复共享 SceneLoader 在持续资源准备时累计90秒误超时：资源索引、scene asyncProgress、分阶段checkpoint真实推进才刷新停滞计时，重复进度仍超时；LoadingFlow显示实际资源数量。新原生6/6 PASS、Lua/resource/engine0，`evidence/loader-progress-2026-10-15T07-53-18-330Z`；首轮夹具跳过Load初始化导致nil错误保留在07-50报告。共享完整加载回归与统一Web大车加载尚待。撞击消费者46/46功能PASS、Lua/resource0，但164ms尖峰整体FAIL；保留后处理覆盖停更18/18 PASS/errors0。g3继续五关入口及WasmFS证据，g4实际host覆盖/原.05时步/自然音频归因，g5继续N/L/D缺口与下一包自然搜撤。
- 6d暂停菜单真实Web：PC9/9 PASS；20:9首轮错误使用mouse wheel的夹具FAIL保留，改真实CDP触摸滑动后10/10 PASS/errors0，底行完整可见截图已查看。6d五关s1-s4真实入口各3/3 PASS/errors0，不等同完整通关。真实FS扫描未截断：初厅296.85MB→陨坑532.25MB，项目chunk.vdat80.44→312MB，完成后XHR响应0；FS文件大小不能单独证明堆后端，未擅删chunk。
- 15:45接续仍为root+三位既有agent。root新补原CollisionAudio侧向撞击音效，真实Bullet墙碰/落地/空中制动及29源规则43/43 PASS，错误0；发现共享CombatView事件需要unit引用后已补并追加实际消费者回归，待原生队列复验及下一统一包。进度`G1_COLLISION_AUDIO_PROGRESS.md`。6d自然音频33项后FAIL：导弹探针条件漏采样，仍实录PCM最长3205.67ms、94间隙，RAF最长1264.03ms；g4补准确探针与缺漏冷编译预热，不冒充完整开篇通过。g3同包连续OOM与五关入口、g5合法T5/COM自然搜撤、root暂停菜单PC/20:9功能Web并行。新只读COM QA4288/PID43404仍6d包，probe指纹`1282e39407c410c5a7bf617c188808ebd5d89c6736b8f06b9d60778e7e2019d1`。原生当前g5短搜撤→g3 Boss UI时序→root撞击消费者。
- 15:30：g5实际无尽联合45/45 PASS、Lua/resource/engine0，覆盖真实伤害/死亡/五秒复活/三命结算、实际Edit→Reload与Edit→Stop、首次正确退出及重复Leave不触旧主人、旧damage恢复与引用释放。证据`evidence/endless-runtime-native.json`；仅功能阈值，不作性能通过。新6d包生产未变，g5继续打捞实际返厅释放，结束交g4独占自然音频。
- 15:27：三路生产冻结后已创建上述6d18072e统一包，收入共享释放/死亡HUD/Install及Stop退出顺序、原PauseMenu、保留开篇post、装配池、原图预热与contain、剧情警报/三行横幅、无尽/打捞持有链清理。新包功能/音频/连续OOM路线均待实际Web回归，不能沿用8db结果。无尽联合首次实跑死亡/复活/结算和首次实际Edit退出通过；两条二次Leave spy误判和Engine:Exit未写JSON仍保留，夹具改分首退/重复幂等并等validator终点写报告，未改生产或放宽首次退出断言。
- 15:20接续：按用户要求继续root+三位既有子agent，不另建重复任务。g3战斗/地图/剧情，g4开篇/字体/音频，g5无尽/打捞/经济；root共享驾驶输入/UI/生命周期/统一包。原生窗口仅为焦点和性能量测串行，代码和离线源核对持续并行，统一包后的功能Web分上下文并行。
- root新增死亡Reticle早退：血量仍更新为0，清fire/lock，不读取已销毁车辆的native。g3实际Boss死亡/重生/三钻头/三飞机/结束/片尾/Reload及持有链112/112 PASS，Lua/resource/engine0（该wrapper阈值20秒仅功能，不作为性能证据）。root实际CarUnit死亡HUD与共享释放11/11功能PASS、Lua/resource0，仍两100ms启动尖峰导致整体FAIL；证据`evidence/world-lifetime-2026-10-15T07-19-42-886Z`。App.Install/Stop先退局内改装再替换/销毁旧HUD和后处理，g5完整Edit→Reload/Stop待联合复验。
- g3原三行MissionBanner与爆炸新短检514/514功能PASS、Lua/resource0，100ms尖峰仍FAIL，实际截图已查看；g4开篇14张原图分帧预热66/66 PASS，并修contain图片铺满裁切产生边缘条纹，最终联系表已查看。以上生产增量尚未进入当前8db包，不能套用旧Web结果。
- 15:10接续仍复用原三位子agent，未重开G0。root新增共享Body失效断native、Vehicle/Space/TrackWorld/DriveView幂等释放和TrialSession先退局内改装再销毁、末尾断会话引用。真实Bullet/实际模型/持有wrapper回收10/10功能PASS，Lua/资源0；273/351ms启动尖峰使整体性能FAIL，证据`evidence/world-lifetime-2026-10-15T07-02-05-756Z`。新清理后原装配池21/21 PASS/errors0；完整自然连续路线尚未复验。
- 同包8db网页声音设置PC及20:9各11/11 PASS/errors0，真实入口、checkbox、滑杆、持久值、局内返回均通过，实际三张目标/源图已查看；证据`evidence/audio-settings-web-manifest-8db734ff-2026-10-15T06-47-57-087Z`。新暂停菜单补原模式介绍重播/源蓝色/PC与紧凑横屏尺寸/全部滚动/触屏条目，原生26/26 PASS/errors0；实际Web待下一统一包。
- root原开篇保留后处理链14/14 PASS/errors0，切回同scene/camera复用实际29pass，停用不更新、释放全排空；不保留所有地图。g4真实431hero装配池21/21 PASS；完整host1700帧34/35、运行错误0，最终m-missile完成被fixture帧预算截断仍FAIL，不冒充自然整段通过。
- 8db横屏story5→完整自然片尾→wing→第二次crater仍OOM/FAIL；共享WASM固定1719533568字节，cache用量不代表整堆。g3补首关原警报灯及Boss/地图持有链，并继续补原collector/fight三行横幅。g5自然打捞两车均真实死亡返回，T3已搜到货并验证携货死亡10项PASS/errors0；成功撤离仍未通过，后续合法车辆/路网实驾，不注入状态。
- 本批唯一集成动作：原生短回归收齐三路冻结代码后打一个新不可变包；先g4独占自然音频PCM/RAF，再root暂停菜单PC/20:9、g3连续OOM/五关、g5成功搜撤同包并发。用户Editor运行实例不归本任务，不擅自关闭。

- 本轮统一包8db734ff已收入：声音设置PC/紧凑横屏源尺寸与最终主题、三路音量、SourceLayer纹理桥接/自有纹理释放、Hangar独占材质释放、地图FX幂等释放、片尾视频桥接API修复、431零件原装配动画/639flash显式预热、普通剧情原爆炸与Radio接线。root实际Web声音入口/布局，g3横屏story5→wing→crater，g5真实购强车搜撤/死亡结算并发；这些新包结果尚待返回。功能浏览器全部退出后g4独占自然开篇PCM/RAF。
- 本轮原生增量：Story爆炸/普通Mission Radio495/495功能PASS、Lua/resource0，33个100ms帧尖峰使性能FAIL；Flash真实预热collector覆盖15/15 PASS、运行错误0，但该短检不能证明新Web包已预编译。声音真实路由29/29功能PASS、错误0，仍有5个129–779ms尖峰，性能FAIL。旧失败均保留。
- 14:30接续：四个现有agent均保持运行，未另开重复任务。root完成原声音设置ref1080/紧凑横屏ref600的局部尺寸/字体/控件缩放，新增真实源三尺寸测量证据；共享弹窗改回源最终蓝色主题。新增SourceLayer显式Retire自有双纹理；card拥有composite上下文内的图片桥接，所以必须先Dispose card再composite（反序试验8条Invalid context失败保留）。真实双层弹窗resize/销毁/复开/Retire.Flush新增7/7 PASS、Lua/资源/引擎错误0、419ms，不改100ms阈值。Hangar仅释放Mat.Bind独占克隆并清节点引用，实际进出回归待复验。
- 声音UI首轮测试FAIL保留：boot遮罩未退便点击，试车后探针仍读VOX_HANGAR导致连锁错误。g5现仅接手这两份测试改动态门禁和持有app引用，生产设置由root维护；不以绕过真实点击替代。g3地图FX15/15、片尾Texture2D桥接11/11功能PASS/Lua资源错误0，但100ms尖峰仍性能FAIL。g3修正nvgCreateVideo错误配对nvgDeleteImage；20:9连续路线OOM待新包复验。
- g4实际431零件装配池化11/11、音频registry38/38、StoryRadio62/62功能PASS/错误0，驾驶音频及warmup新增检查进行中。g5新b8自然搜撤遇真实敌人低血卡路，未撤离，整条FAIL/运行错误0，已关闭浏览器；不把载入/搜到货算成功撤离。
- root：原声音设置、共享弹窗最终主题、三路音量云键和局内入口已接；新增`check-audio-settings.lua`真实鼠标/键盘/存储/回场生命周期检查，等待音频独占结束再运行。尚未打入b8包，不能套旧结果。
- g4_opening：原`vox.audio.v2`三路音量/Intro与MusicPlayer、Story说话压音乐已实现，新增模块原生29/29功能PASS。实际MasterGain上限1，SoundSource.gain允许1.5；因此其他音效以每源raw gain调制，不能用master比例假支持大于默认音量。b8自然开篇音频正在独占复测，其余任务不启动运行实例。
- g5_endless：b8真实PC与20:9无尽各8/8功能PASS，运行错误0，包含完整AI、补给、G改装与返回保留战场；两浏览器已退出。自然打捞搜到3件但直追撤离口爬山失败，保留FAIL；已离线核原845节点/908边，下一轮按原路网实驾撤离，不改地图或注入货物/时间/血量。
- g3_g4_battle_story：935 PC自然片尾8句/4panel/盖章/自动回厅及Boss后半/feather/边界共40/40功能PASS。盖章图发现旧漫画未完全淡出，最新生产透明度和原1.65s声音延迟已修，原生7/7功能PASS、启动尖峰仍性能FAIL。20:9自然片尾完成，但连续story5→wing→crater在再次进图时OOM，整条路线FAIL；不能写成双端完整通过。旧失败日志保留并追查资源持有。
- 音频测试独占仅针对测量有效性，三路代码/源核对/离线路由仍并行。下一动作：g4自然音频结束后按原生窗口队列验增量，固定下一份不可变包，同包真实回归；不重复身份调查或旧项。

### 接续检查点：935b3961统一包

- 最新候选已推进`manifest-b8b63ade.json`，快照`.tmp/outgame-cached-1792044093624`，脚本指纹`477f9b9e7214352d45012b57825a5591d3e8b43a3ff636bb27b2147fa46417a6`。普通4281/PID6364、QA4280/PID9844；收入无尽shieldTarget契约修复、打捞原爆炸实际Run hook、开篇原逐字双底板/Track33字图、剧情LINE_LIST/spawnFlash和刹车重复分摊修正。新包结果待实际验证；爆炸余烬投影修正在copy后，不属于该包。
- 不重开G0，复用g3_g4_battle_story、g4_opening、g5_endless三个子任务继续G1-G6。root负责共享输入/显隐/分帧/统一构建及真实物理曲线。
- 本批统一普通4277（PID34176）、QA4278（PID34696）：`manifest-935b3961.json`，`.tmp/outgame-cached-1792043283252`，脚本指纹`494022f184eb6e207d03086817785d92f28e15fa9d0ea764518ae02bc8c38f7e`。上方cbeb包为历史，不再代表当前候选。
- 已收入root开镜持续隐藏/原mask恢复、Esc延迟接管、装车内部协程/取消、伤害击杀归属；g4原GameFont219字形/原sortie光效；g5打捞Fx和无尽改装adapter；g3动态甲板及自然片尾推进/字体。未挂钩的新SalvageExplosion不能算此包功能。
- 935真实PC滚轮、第一人称鼠标/WASD、上色、Esc释放后真实点击重新锁定、涂装缩放、MEGA取景全部PASS，游戏/探针错误0。报告`evidence/web-camera-input-935b3961-2026-10-15T05-49-17.json`，对应建造/MEGA两图已实际查看。
- g3动态甲板原生6050/6050功能PASS、Lua/resource错误0；4条100ms尖峰导致整体性能FAIL，未放宽阈值。Boss/完整自然片尾935同包Web进行中；g5同包改装/打捞进行中，之后g4独占自然开篇音频验证。
- root新增真实Rapier0.21世界：同3份冻结蓝图、每车3次、固定60Hz加速/滑行/反向制动/转弯，共2430样本；Bullet同条件测量待原生窗口可用。此为量测，不凭公式签收手感。
- 上述真实世界已完成三组实验，详见`G1_ACTUAL_WORLD_MEASUREMENTS.md`。4km单块box造成Bullet接地剧烈异常，不能直接归因驾驶控制；双方同1km地面后GT末速26.1189/源26.1200，停距11.8421/源11.8092；GT转角仍差0.7035rad、履带加速距离仍差7.7143m、COM仍不同，未签收G1。2439/2439只证明量测成功。
- 935原scope两端FAIL已保留；probe原来在Update内、动画启用后但PostUpdate隐藏前取样。QA4279同935生产快照、只将trial采样延后真实PostUpdate后，两端13/13 PASS，实际开镜231/visible0、释放恢复mask、错误0。不是通过篡改生产显隐或跳过开镜断言。
- 935真实无尽两端均FAIL：shieldTarget缺冻结源pos/zone/aimPoint导致AI Spatial(nil)。g5已按源补target，新增完整真实driver原生25/25 PASS错误0；新b8b网页待验。旧失败不覆盖。
- 新发现fixture文件NUL异常已让g5隔离处理；root扫描当前scripts及935快照全部Lua均无NUL。后续Track原GameFont33张文字纹理已由g4核源推广，尚未进入935包。
- 下一动作：收齐935各Web功能结果，修实际失败；全部功能浏览器退出后独占测自然音频。保持旧失败与真机/真实账号缺口，不回到G0重新调查。

### 接续检查点：04:00并发批

- 仍为root加三个既有子agent，不重开G0、不另建重复任务。g3负责第五关甲板原动态接口与Boss；g4负责原开篇催促/锁圈光效和自然音频；g5负责无尽局内改装适配、打捞原爆炸火烟；root负责共享输入/显隐/装车协程/同包集成。
- cbebfb9c两端Boss真实开镜FAIL：231个玩家StaticModel有10个仍可见，根因为WeaponPresentation每帧重新enabled。root正在原生回归自存显隐mask、开镜持续隐藏和实际重建后恢复；不是删除模型。原生新增恢复断言先FAIL（4702/4703，Lua/resource/engine错误0），暴露引擎重复递归操作覆盖内部mask，失败记录保留。
- cbebfb9c自然开篇真实ESC再捕获FAIL，迟到锁请求与长帧使pending超时；root DrivePointer/BuildCamera已改按响应帧累计等待并主动释放无授权迟到锁，新增夹具通过。当前包尚未收入生产修复，完整自然开篇/PCM间隙仍FAIL，下一包单实例无PNG编码重验。
- root装车内部checkpoint已接VehicleView/DriveView/CombatView/TrialSession，候选场景每零件让现有SceneLoader预算决定yield，并在首次yield前交所有权以允许取消。实际feather同步/分片模型、颜色、边界、飞控绑定与取消释放检查通过；不因此宣称整体加载性能已达标。
- g5 cbeb自然搜刮真实驾驶/搜索/货舱/放弃/回厅7/7 PASS、游戏错误0。证据`evidence/salvage-natural-manifest-cbebfb9c-2026-10-14T19-43-03-567Z`；不是成功撤离、死亡、超时或真实账号恢复证据。新Run/Fx与Edit后续增量待新包。
- 原生窗口队列：g4短sortie-fx→g5局内改装适配复验→g3甲板ray/显隐/唤醒→root联合。代码并行，原生窗口串行避免焦点争抢；统一包后Web各功能上下文并行，音频性能最后独占测。
- 当前唯一下一动作：完成上述增量原生验证后固定一个新不可变包，实际ESC释放/重捕获、scope零子模型泄漏、Boss后半流程、无尽局内改装和打捞新效果同包回归。旧FAIL保留；完整G0-G6仍按138项追踪。
- root最终联合原生`evidence/physics-batch-2026-10-14T19-55-54-208Z/result.json`：4788/4788 PASS、测试范围错误0。已包括上述scope原mask/损坏重建、pointer-delay、真实分片/取消，18源伤害/击杀归属和24源CarUnit有效/拒绝命中归属。g5最新Edit23/23、Run/Fx29/29 PASS错误0；g4新GameFont字体短检、g3甲板/完整自然片尾仍待本批验证。下一动作仍为统一包真实Web，不重复原生旧项。

### 接续检查点：显隐、预热、驾驶反馈

- 沿用三位现有 agent 与冻结10月14日基线，不从 G0 重开。native 队列为 g4 预热/教学 → g5 打捞 director → g3 Story/Boss/Boundary 显隐 → root 联合物理；Web 同包独立上下文并行。
- root 已补仓库专属 PreviewRoom；原生仓库几何诊断1/1 PASS且无白面，但该诊断绕入口门禁，Web白色横面仍待真实采购入口射线定位。
- root 修复 CarUnit 毁车分类漏 wings/mechLegs；626项冻结源分类与受损机翼/机械足真实Bullet重建检查已加入联合检查。首次982项遗漏旧story-marker帧42，现分类移到44，不能把982当完整联合通过。
- root 新接冻结源 CameraFeedback：武器开火、近爆、钻头、加特林震颤、机械足落脚/腾空/落地弹簧与 Story/Salvage stompV；新增8场景960帧原JS黄金夹具及实际引擎相机姿态检查。第一人称车体改递归显隐。完整联合4595/4595 PASS、测试范围错误0；新增MechView空中插值引用修复及真实T3/T4/T5渲染14/14 PASS。证据与边界见 `G1_CAMERA_DAMAGE_PROGRESS.md`；待统一Web包，不签收完整G1或手感。
- g3 修真实递归显隐并补原glow metadata/collector落地；g4 预热去重实际291呈现帧/276批次并保留4实例覆盖instancing；g5 恢复源锁红/开青/撤离绿信标及原生成/采购/搜撤规则。生产稳定后统一新包，不将旧1f35093f结果套入增量。

| 任务 | 执行者 | 状态 | 所有权与下一动作 |
| --- | --- | --- | --- |
| G2/S02 跳过确认覆盖路线按钮 | root | 子检查 PASS | Web 96/96、4种 PC/20:9 实际两次点击；图见 `evidence/tutorial-layout/2026-10-14T15-50-07-298Z`；非真机 |
| G4/S01 开篇五阶段 | g4_opening | IN_PROGRESS | 新 `intro/*`、`ui/Intro*`、`audio/Intro*`、`assets/Intro/*`；原宣传、现实、通讯、合同、出击；进度 `G4_OPENING_PROGRESS.md` |
| G5/N01-N07 无尽 | g5_endless | IN_PROGRESS | 新 `endless/*`、`app/EndlessSession.lua`、`ui/Endless*`、`assets/Endless/*`；原波次/掉落/仓库/改装/生命；进度 `G5_ENDLESS_PROGRESS.md` |
| G3/M03-M05/W08、G4/S06-S07 | g3_g4_battle_story | IN_PROGRESS | 地图边界、狙击识别、第五关/Boss/片尾；进度 `G3_G4_PROGRESS.md` |
| 公共入口和统一验收 | root | IN_PROGRESS | `HangarApp`、`TrialSession`、`GarageHud`、`HomeBattle`、`BuildSession` 由 root 集成，避免多人相互覆盖 |

子任务先交可接入代码及精确接口，root 持续集成，不等待全部代码完成才开始验证。所有任务按源行为和资源实现，不拿静态图、空回调或测试赋值替代原功能。

## 10月15日接续批

- G3 边界与狙击瞄准线/威胁 HUD 已接入 `TrialSession` / `DriveHud`。原生发现 shader 保留字 `line`，子 agent 已改 `hexEdge`；后续同包 Web 再验。
- G4 第五关已接真实独立 `EnginePit.xml` / `EnginePitWorld`，从冻结源导出 168 模型、26 材质、原 194 碰撞描述（18 个源 fallen 禁用，启用 176）、500x500 高场、路宽与顶棚，五组 shader hook 与陨坑源逐字相同；烟/风特效仍待完整接入及场景实际验收。
- G4 开篇模块最新85/85、真实host16/16、live24/24、宣传演出8/8通过，运行范围错误0。原版55音频/14图片、实时场景/装配/驾驶/导弹/光束、签约和闸门已接；清理教程叠层及延迟三帧抓取的实际图片已核，Web完整播放仍待验。
- G5 644/644 源规则对照、18/18 原生真实入口→出兵→补给→保留战场改装→复活→三命结算→回厅通过；原音效、零件缩略图、限量库存、HUD/选车与云键已接。Web与真机、商店/补给视觉验收仍进行。
- G1 机械足3557/3557源黄金、56/56 Bullet行为、11/11实际骨架/护盾/喷口检查通过；首次快进的性能FAIL单独保留，拆帧后行为通过。root已修FK X角/镜头俯仰并补护盾扫描/落脚脉冲及2.4倍喷焰。新喷焰截图正在补，见 `G1_MECH_PROGRESS.md`。
- G1 机翼源黄金5865/5865（含正反推进）、实际wing2..5骨架/舵面/尾迹20/20通过；整体检查的启动/脚本尖峰仍FAIL，不能算性能通过。受损飞行、真实Web控制仍待验。
- G3/G4 Boss 原生107/107重跑通过、FOX四足真实装配通过；已补display lean、露天跳砸重定向、冲击衰减/腾空免疫与钻头驾驶。片尾董事长修用源透明cut图片，完整淡入截图已核；自然完整战斗及全片尾仍待验。
- 源主页 `shared/ui/home.js:44` 隐藏无尽，保持这个入口状态；可通过 `app:SelectEndless()` 真实选择，不自行增加替代卡片。
- PC相机检查在4261中间包通过：原版像素滚轮可逆、FP鼠标接管/WASD、涂装缩放、MEGA预览墙体约束，运行错误0。此前首滚轮FAIL是测试在boot-exit遮罩关闭前操作；失败证据保留于 `evidence/web-camera-stale-probe-ef8eb4a7.json`，测试已改等实际可操作。
- root本批公共伤害修复：CarUnit狙击armor绕盾、贯穿余量/倍率/溅射，TrackWorld/各模式透传shield/pierce，HUD分行伤害/穿甲/抵抗、原字体/字号/1.1s动效/大块击碎门槛。冻结源96层+12贯穿夹具，原生112/112 PASS，运行错误0。对应原生真实HUD132/132 PASS；保留之前截屏裁切与测试缩放/过早返回失败报告，不作为生产问题关闭依据。
- 同包9100f4af：PC真实滚轮/FP接管/WASD/涂装/MEGA相机Web PASS，运行错误0；20:9触屏建造返回、试车加载/摇杆/release/返回8项PASS，运行错误0。冷厅53.746秒、试车10.094秒仍为性能不合格；桌面模拟不等同真机。证据 `evidence/web-camera-input.json` 与 `evidence/full-parity/2b169a996464/G0/manifest-9100f4af/2026-10-14T17-53-09-434Z`。
- 继续源对照发现HUD仍读旧总耐久：新增CarUnit:Life，对齐核心/15%预算瘫痪线/车体耐久取最小值；HUD/目标/低血和维修声音改接Life。新增144个冻结源黄金场景，连同伤害验证原生256/256 PASS，运行范围错误0。新包运行回归仍待验。
- 当前三路下一动作：G3/G4使用QA4265的大厅F4、局内Home避开生产F5重载冲突；G4真实开篇等待loadingFlow完全退出再点击；G5修商店980px源宽及编辑投影并跑20项原生和Web。只回归实际变动，不重开G0。
- 三个子agent并行制作，原生窗口验证按g3→g4→g5→root排队，避免抢焦点；Web可分开浏览器上下文并行。生产稳定后统一包，同包验证不重新审计G0。

## 已完成的前批内容

见 `G0_BATCH9_2026_10_14.md`：原启动页、有效首帧加载门禁、教程通讯卡连续布局、可见视锥预热、旧加载 toast 移除。原生加载 722/722、教程 41/41；这只证明对应子检查，未签收 G0 或所有教程状态。

## 保留缺口，不阻塞后续实施

- G0/Q01-Q05：当前冷启动与陨坑总等待仍长，最大实测 rAF 停顿 4.84 秒；加载性能 FAIL。暂不重复进行归档/并发调参调查，后续统一构建采样。
- G0/D03、Z04/M08：真实账号刷新恢复和编辑器操作证据缺失。
- G1：地面/悬浮/空中等已有迁移与原生结果，Web 各移动方式和手感完整对照未完成。源建造夹具 `mixed 43 / T1` 转轴环递归失败保留，不改冻结源或删除失败样例。
- G2：全页面、长文字、所有字体/光效/动态状态未完整验收；当前确认按钮是新增发现。
- G3-G5：以上并发工作进行中，其余总计划 ID 均继续跟踪，不能因先补主要缺失系统删除已有规则或验收项。
- G6：同包全流程、连续进出、弱网、实际手机/M1长期性能未完成；桌面20:9不能代替真机。

## 交接要求

每批结束更新本文件的当前包、任务状态、失败证据和唯一下一动作。源内容已冻结时只核身份一次，不反复重跑整个G0。当前下一动作是收集并修复三路真实Web功能结果，收入Life/safeCam/商店宽度增量并固定新包，继续G1-G5源遗漏；不是从头审计。

## 并行接续：02:10批

- 三个既有子agent持续执行，无重复创建：g3_g4_battle_story 完整源AI；g4_opening 开篇原演出及短radio cue；g5_endless 缺料采购及云恢复校验；root 原版触屏驾驶与统一包。
- 同包9100f4af，真实Web开篇PC、20:9各10/10 PASS，包含实际文本输入、空签名拒绝、笔迹、签约、闸门、返回及输入释放；旧返回probe假阴性归档保留。原生开篇89/89、最新演出12/12 PASS，完整自然演出/声效持续性仍未签收。
- QA4266同包Boss/片尾/原feather飞行/陨坑边界PC与20:9各19/19 PASS，游戏错误0。每端4个引擎缓存7z回退404单列，不计为游戏资源成功。
- 无尽商店修为源实际Panel/ScrollView，3列/980px/80vh；最新原生真实链21/21 PASS错误0，实际商店和车居中截图已核，等待新包Web。
- root发现并补旧触屏驾驶UI：复制25个冻结源原图标（证据touch-icon-import.json），右手切角弧形键、开火就绪条、按载具隐藏无用键、情境翻正/交互、飞机方向舵、浮动八边形摇杆及机械足外圈冲刺。源真实构造器/样式重新量201摇杆样例与4比例，旧touch对照不能作为新源验收。新增verify-touch-drive.ps1原生656/656 PASS，运行范围错误0，实际画面已核。首次旧别名传nil样式导致加载失败已修；第二次Yoga像素取整误差为测试容差修正，两失败报告均保留。新包Web20:9/16:9进行中。
- 尚缺触屏设置持久化、原版移动编辑器完整布局/点放长按删、辅助瞄准与自动开火。当前drive补齐不代表所有移动端功能完成。

## 并行接续：完整AI与移动建造批

- 不重启G0；继续G1-G5实施，G6随统一包验证。三位原子agent持续复用，未新建同名工作。
- 43b0ce1d实际Web触屏驾驶16:9、20:9各19/19 PASS，运行错误0；无尽PC和20:9各6/6 PASS，但后者touch=false，是横屏布局/流程证据，不是真手机证据。无尽加载约67秒，性能仍FAIL。
- 完整源EnemyDriver已替换旧简化决策；65场景11700帧23455/23455功能PASS，源route夹具改深拷贝后重验通过，100ms尖峰总报告仍FAIL。BattleController、Mission、Boss ally、EndlessSession、salvage/Run均透传reset/flip/salvo，DriverActions按原版先reset再flip再物理。
- StoryRadio短cue原生62/62 PASS，运行范围错误0；自然完整开篇/全剧情声音连续性仍OPEN。
- 源AimAssist纯函数336/336黄金PASS，root新增DriveAim接准星附近裸露零件吸附、scope1.8/触屏2.2角、鼠标减速、触屏跟随和可选自动开火；生产入口与新设置仍待本批统一验。修ReticleState距离X符号及辅助目标HUD引用。
- 原版移动建造TouchEditorLayout/Widgets/TouchBuildControls由g4并行制作与验收；root已接TouchTarget/TouchAt、指尖射线、tap模式不重置到中心、PC保持中心射线，并隐藏触屏下旧desktop层。手势及移动stats源比例由g4核对。
- TouchPreferences按源默认/枚举落盘，并接touch-settings云键；TouchSettings按原7类分段设置接入，驾驶菜单补原试车传送/出生与无尽维修/下一波/改装。按钮大小、敏感度、飞机模式共用偏好；真实账号刷新恢复和平台全屏能力仍须实测。
- 打捞StashRules严格数值与事务70/70、缺料购买/批量/Undo补买/整车失败退款14/14原生PASS。公共BuildSession.Attach、GarageHud采购入口已接，源禁止的建造内load/import被守卫，save/export允许。采购新580px样式是后续增量，不归入旧Web包已验。
- 下一动作：g3生产自然AI、g4实际移动建造、root公共集成输入/设置验证；稳定后制作唯一新包，分浏览器上下文同包回归。真实手机/M1、真实账号和冷加载失败不隐藏。

## 并行接续：8d52110f统一包

- 继续原三位子agent，不从G0重启：g3自然AI/任务目标，g4自然开篇及真实音频时间线，g5真实采购PC/20:9，root移动建造实际触摸与共同故障修复。
- 原生移动建造1067/1067 PASS、驾驶660/660 PASS。驾驶第一次643检查有1 FAIL，实际为TouchDriveControls局部adapter闭包nil使LoadingFlow失败；已修作用域后660项重验。失败报告单存touch-drive-settings-adapter-failed.json，不因引擎summary错误数0掩盖LoadingFlow日志故障。
- 公共同进程1069/1069 PASS：输入/设置/自动开火门禁、数值存档、AI源生命/瘫痪判定195、任务指引/投影732、新车创建9种成功/部分写入/抛错/回滚故障。报告current-integration-native.json；Lua/资源/引擎错误0。宽松尖峰阈值只为功能验收，不能签收性能。
- Garage.CreateVehicle任何SaveSlot/Switch失败（包括抛错）退休刚分配车位的双代存档并恢复原车与元数据；清理或恢复失败显式rollback，采购不得假退款。实际购买UI扩展原生及Web继续由g5核验。
- 新唯一包已启动并核对身份；当前下一动作是4路同包真实流程与截图。旧包的通过结果不套用；冷加载、账号刷新、自然完整剧情与真机性能仍OPEN。

## 并行接续：真实流程发现与收尾

- b3a7f84f（QA4271/普通4272）修采购实际回车库；两端真实采购各5/5 PASS、运行错误0，明确检查车库“拆掉这辆车”按钮和新车渲染。旧8d的统计通过没有发现子页未切换，不作为此修复通过证据。
- b3实际触屏驾驶20:9/16:9各19/19 PASS；实际移动建造各23项通过但总体FAIL：DOM touchcancel被引擎映射普通结束导致误放置。问题/根因/证据见WEB_TOUCH_CANCEL_BLOCKER.md，不以纯Lua取消夹具覆盖真实平台缺口。已查看20:9实际stats截图。
- 8d PC自然竞技12/12 PASS：真实5AI位移/多战术/交火损伤，未传送或注入HP/kill；冷厅58.186s、战场98.187s性能FAIL。剧情4横屏实际16/16 PASS（敌人/采集器/指引/返回），全剧情未签收。
- 自然完整开篇首次真实到comms发现Plain/gsub第二返回值误入utf8.len，无标签对白崩溃；已修单值返回，原生91/91 PASS。长播放声画连续性仍FAIL，最大音频callback gap14.31s；g4继续原演出机位预热及源sortie准星/标记，不能拿skip路线签收。
- 当前候选1f35093f（QA4273 PID27768/普通4274 PID36572）：.tmp/outgame-cached-1792003884897，指纹5ebde9bdac61daa63cbc313eb654ce11a12479513efb6fc14297d34fc3849572，包含采购回车库与Plain修复。g4在该包重跑自然开篇，其他长测试保持各自旧包身份。下一生产增量不要套用此包。
- g5新结算/两代重开/云解码隔离store25/25 PASS，含开局raids计数/幂等/失败回滚；这不是自然搜撤或真实账号证据。新BeginRun等delta待下包。root接仓库白色遮挡实际射线取证；g3继续信标色/淡化和Boss安全提示；g5继续原巢穴/巡逻/营地生成、车队额外奖励和警觉HUD。
