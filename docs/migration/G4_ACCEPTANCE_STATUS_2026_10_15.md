# G4本路逐项证据与未关闭项

更新：2026-10-15 17:25。恢复先读CURRENT_EXECUTION；不重开G0，不重新定义范围。

冻结H5基线：`2026-10-14 / 2b169a9964645f5f346a7158bcb14447f040814a`，源快照`.tmp/outgame-source-2026-10-14T10-09-50-505Z`，源哈希账本`outgame-baseline.json`。目标分支`codex/h5-2026-10-14`，已有工作区未提交内容保留。总计划为FULL_PARITY_PLAN_2026_10_14.md的138主项；本文件只登记g4_opening负责的子项，不能替代root/g3的教程、五关、Boss、片尾、公共设置及全局UI验收。

最近实际自然Web包：`manifest-6d18072e.json`，QA4287，生产指纹`7c5a7f028f4eb296c767a1c8bbaaefdb0aea5a20eed6d43b85832383f2acfb58`；所有带6d测量的结论只属于它。其后Equipment/Chip/Missile精确预热、covered背景停画、simulation.dt=.05为本批待统一的新代码，不能借6d结果签收。原生检查读当前工作区，结果按各报告目录保留；下一不可变包身份由root记录。无发布/提审/提交操作。

root已固定下一包`manifest-d6764c9c.json`：普通4289、QA4290，快照`.tmp/outgame-cached-1792051106196`，生产指纹`a7028dff4185d6a4915cd887f30231c54ac1429b71bde132310b3542ce193d81`，只读probe`17a19a0d3dff70411567118a5a3cdd1a63571d933a4c9dd5705659d1cab517ca`。此处为root核对的候选身份，g4尚未运行自然音频；待其他功能实例退出后接力。

当前候选已推进`manifest-2729bc84.json`，普通4293/QA4294，快照`.tmp/outgame-cached-1792052961120`，生产指纹`cf3298c95984ca9f17bd7cec33345187763c015120ba690d44b72c93bdba1db6`、probe`2b32f2d79c1f598ced89883ffefe01f0dbdb6bb24b04e51879e0097aeac8c198`，本路实际读取`/identity.json`确认。2729包括OpeningHost资源释放后再注册/启动教程，以及root共享defer回调链。下面d676音频/lateOOM失败仍是历史未关闭证据，不能由新的skipad功能路线替代自然整段。

2729功能实测：教程PC24/24、20:9真实触屏37/37，运行错误0、关闭后错误0。触屏旧测试错误期待已隐藏的删除按钮，24项后失败报告保留；改为源实际tap放置/长按删除后真实209→211件并成功保存/返回、重播。原生隐窗同host首轮20/20短项因无焦点而180秒TIMEOUT；只补fixture focus后第二轮30/30到实际gate，仍因10Hz/2460帧超过旧180秒总时限而TIMEOUT，0Lua/resource，两报告均不当完整host通过。wrapper总时限现300秒覆盖原2460帧，未改inactive帧策略或性能阈值，未重跑。

2729公共开篇PC和20:9均11/11功能PASS/errors0/shutdown0：实际skipad、通讯、Unicode签名/笔迹、gate、回厅、真实教程T-01播放及2.5秒后响应；回厅两端`craterModelResident=false`、缓存73,057,913/73,514,576bytes、retiredTargets0。PC实际bag/save及两端开篇回厅图已查看。20:9第一轮旧wait不发F8而停留清理前三帧的snapshot，9项后timeout/errors0，最终failure图中实际教程已显示；原FAIL保留，runner仅补定期真实F8后新时间戳11项PASS。自然sortie/PCM和真正手机性能仍待，不能据此关闭S01/A04。

## 主项状态

最新自然全流程实际包为`manifest-11e3cbe9.json`，QA4299，快照`.tmp/outgame-cached-1792053971537`，生产指纹`20a59fc6a04583dbc61910d3cf4125527e60b15df65e2f66f88da254d85c6c23`，修复后的只读探针`4decf927ac0f718fa09e5c4d9ea020b25b8fa7c87c5b868464cc17a6d3d70cda`。实际自然操作38/38功能PASS、运行/关闭错误0，整体仍FAIL（A04）。自然回厅确认陨坑模型已释放、cache78,326,200B、retiredTargets0，无lateOOM；只保活2秒，最终教程running=true但visible=false/voicePlayed0，不能借2729跳过路线宣称自然教程已经可见或播音。首轮11e3 QA wrapper误丢EnemyDriver四返回值的11error/0actionchecks失败另存，已修探针并用同生产包完成新测。当前所有本路测试进程已退出，QA4299交root；依root指示停止长实验，进入独立审计汇总。

| 总计划ID | 当前状态与已经完成的实际子项 | 证据 | 尚缺的关闭条件 |
| --- | --- | --- | --- |
| S01 开篇 | PARTIAL，11e3自然38/38操作项通过，运行/关闭错误0；实际W/LMB/Esc/毁车/27镜头/原导弹/签约/门/回厅与2秒响应通过，陨坑模型释放且未观察到lateOOM。d676旧lateOOM失败保留。整体因A04仍FAIL | intro-natural-web-1600x900-deep-cpu-four-return-release-gate-11e3cbe9.json/log/-analysis.json；原生91/host16/旧实际24 | A04；首次/重播/中途退出/连续两次与源同状态画面对照；自然路线教程最终running但未显示/播音，不能签S01关闭 |
| S02 教程 | PARTIAL，2729真实PC24/24、touch20:9 37/37，运行/关闭错误0；原声、实际bag/改件/save/back/双跳过/帮助重播/记录保留通过，实际全可见十槽和触控按钮高亮通过。原生43项功能PASS但100ms尖峰FAIL保留 | tutorial-web-pc-manifest-2729bc84-2026-10-15T08-36.json；tutorial-web-phone-landscape-manifest-2729bc84-current-touch-2026-10-15T08-40.json；原生tutorial-targets目录 | 完整16步/18配音两路线、正常不跳过继续战斗教学/续接；实际手机。此次build路线在battle处确认跳过并验重播，不等同所有教学路线自然完成 |
| S07 片尾 | OPEN，本路提供同源GameFont字形与三路音量/Radio支持；片尾流由g3维护 | intro-game-font-import.json、story-radio-native.json；g3的G3_G4_PROGRESS.md | g3最新统一包五关完成→自然片尾→回厅及进度；连续路线OOM仍由g3/root追查 |
| S08 任务通讯 | PARTIAL，StoryRadio实际并发/duck/释放62项；开篇原通讯卡独立页面/原14图准备和显示，未修改普通任务布局 | story-radio-native.json；intro-image-warmup-native.json；intro-web-* | 四角色全部任务/选择/安装/横幅/评价的源同帧A/B及全部状态由g3/root收齐 |
| S09 跨全篇 | OPEN，无全篇同构建关闭证据，6d自然开篇A04仍FAIL | 6d自然原始报告、G3_G4_PROGRESS.md | 开场→教程→五关→片尾、重开/退出/进度/音频/资源释放与同构建完整路线 |
| A01 全声音映射 | PARTIAL，开篇55声音全部实际资源+事件；原驾驶8类状态映射450项；StoryRadio62项；三路registry38项。root正在补原碰撞/受伤实际消费者 | driving-audio-native.json、story-radio-native.json、audio-levels-native.json；G4_OPENING_PROGRESS.md | UI/环境/升降/奖励/MVP/战斗所有事件的共同映射和实际消费者。素材存在不等于所有事件已接 |
| A02 台词与所有权 | PARTIAL，开篇原文/原声音/打字/选择/合同、55资源独立Audio scene持有；切页不Dispose声源。StoryRadio队列/urgent/停启/duck62项 | intro-native.json、intro-host-native.json、story-radio-native.json | 普通五关全台词/多角色/结束跳过/跨场景单例的同构建逐事件和试听；开篇新自然完整回厅待验 |
| A03 无线电音色 | OPEN，原静电/前后提示、归一化gain与StoryRadio事件已接，但原WebAudio DSP未等价 | story-radio-native.json；scripts/audio/IntroAudio.lua、StoryRadio.lua | DSP压缩器、TV/无线电lowpass、RMS口型尚无公开Lua等价实现；不得把普通SoundSource或voicePlaying开合说成原DSP/RMS已完成。需明确可用引擎实现或保留具体阻塞并A/B试听 |
| A04 音频连续性 | FAIL，11e3单QA无PNG：PCM最大2504.695ms/59间隙，RAF P9576.375ms/P99145.81ms/max1117.9ms/47冻结。sortie最坏采样窗口actorFlush2358ms/Bullet71ms/UI20ms，Flush单次416ms；gate→hall最大间隙2390ms与长任务重叠但无方法样本，具体函数未归因 | intro-natural-web-1600x900-deep-cpu-four-return-release-gate-11e3cbe9*；d676/6d失败均保留 | 修破坏后Flush连通性/分裂/刚体重建热点及gate→hall长任务；0个>250ms停顿。用户Editor43020仍保留；嵌套时长不能相加，采样窗口不是精确调用栈，QA计时有开销，不能作为无探针金标 |
| A05 武器/移动混音 | PARTIAL，原驾驶450项、旧1e6e8933 Web PC8/横屏6项通过；同源三路增益/音高/驱动状态；原SFX默认偏好保留 | driving-audio-native.json、driving-audio-web-pc.json、driving-audio-web-phone-landscape.json、audio-levels-native.json | 同新统一包全武器阶位/距离/并发及全部车型实车试听；旧包结果不证明6d后的所有消费者，手机浏览器viewport不是真手机 |
| A06 伤害威胁/碰撞 | OPEN，root拥有CollisionAudio/CombatFeedback实际消费者；本路不开新替代实现 | root G1_CAMERA_DAMAGE_PROGRESS.md与CURRENT_EXECUTION | 实际碰撞强度、破件/死亡/维修/盾/锁定/来袭/心跳等全事件新包声音验收 |
| A07 音乐与增益 | PARTIAL，vox.audio.v2原3路默认及音乐enabled；原voice duck与恢复、gain>默认的每源registry38项，StoryRadio62项 | audio-levels-native.json、story-radio-native.json；root声音设置同包报告 | 空间声像、压缩/滤波、全场景并发/切换A/B及实际设备试听。设置页PC/20:9由root独立验收 |
| A08 演出节拍 | PARTIAL，原开篇时序/BGM/SFX/合约门、原装配.24s/.3s、真实431hero池化；新14效果预热检查通过 | intro-live-native.json、intro-montage-pool-native.json、intro-effect-warmup-native.json；装配短检 | 自然新包实际齐射和完整结尾、MVP/奖励/补给等由root/g3/g5收齐；不能用加速fixture证明实际声音不卡 |
| A09 声音生命周期 | PARTIAL，开篇独立13声源只初始化一次、55Sound持有；失焦暂停/恢复、Finish显式释放；StoryRadio62与三路registry38项 | intro-native.json、story-radio-native.json、audio-levels-native.json | 当前统一包重播/取消/失焦/失败/重入和自然回厅后无残音；真实账号音量恢复由root；无手机手势解锁真机证据 |
| U01 字体映射 | PARTIAL，本路核原style.css与GameFont源，原ZCOOL用于开篇/片尾漫画；正文/普通控件仍依root源最终family，未全局换主题 | intro-game-font-import.json，source CSS SHA256 db0d7631...；intro-title-source.json | root全控件最终computed family/weight/size/line-height清单及平台fallback，不能以本路子集关闭全U01 |
| U02 字形来源 | PARTIAL，原TTF SHA256 54f0c0df...；219字原轮廓/advance子集130668bytes；50字原轮廓标题导出，8项标题原生通过；Track33张字图原GameFont推广，几何/布局不变 | intro-game-font-import.json、intro-title-glyph-import.json、intro-title-card-native.json、track-game-font-promotion.json | 全部中英数/符号/fallback在Web/原生同句对照与源同平台字重；不把219字当全部游戏字体完整 |
| U03 文本布局 | PARTIAL，原开篇合同/Comms/漫画边框布局已接；旧9100两端签约输入/签名各10项；contain边缘夹色修复后实际contact已查看 | intro-web-pc-*、intro-web-landscape-20-9-*；intro-image-warmup-contact.png | 新统一包PC/20:9全部长短台词/合同/极端代号同源截图/基线量测；完整平板和其余游戏页面由root |
| U04/U05 通讯质感 | PARTIAL，开篇原机甲外框、glint/信号/扫描/原表情图和GPU头像已接；旧截图已查，原14图预热66项 | intro-live-familiar.png、intro-web-*-comms.png、intro-image-warmup-native.json | 全4角色共同状态的0/80/160/320ms同源对照，RMS嘴型仍OPEN，普通任务卡不由开篇单页代验 |
| U09 局内HUD | PARTIAL，本路只补开篇真实试车教学HUD/红敌标/锁圈/准星/损毁工资戳与原GameFont，实际6d射击/毁车观察通过 | intro-sortie-fx-native.json、intro-sortie-fx-original-game-font-stamp.png、6d自然报告 | root/g3/g5全部竞技/剧情/无尽/打捞/死亡/维修/结算HUD各自真实状态+源同帧截图 |
| U10 横屏 | OPEN，旧9100 PC与20:9桌面Chromium10/10，不能代替当前全部页面或真机 | intro-web-pc.json、intro-web-landscape-20-9.json | 新包完整viewport矩阵、实际手机/平板和安全区/触点；不制作竖屏重新设计 |
| Q05/Q09 开篇优化 | PARTIAL，11e3自然释放边界已观察到，无lateOOM；postwarm冷日志6仅覆盖3PCMgap，连续性FAIL。明确Flush单次416ms/总15163ms，Bullet单次≤16ms，旁白更新≤1ms；最终hall2495batches/3600736primitives | 11e3完整natural分析；image66/montage21/effect14/retained20功能PASS | 精简/分帧实际破坏重建与gate→hall长任务，源画面/玩法保持；retained181.446ms及教程152-481ms尖峰保留，不把功能PASS当性能通过 |

## 下一批固定动作

1. 11e3自然测量及分析完成，本路无运行中测试；QA4299已交root短诊断，不再启动长实验。
2. root汇总当前独立审计，按实际ID分别记实现、功能、视觉1:1和性能，不从G0重开。
3. A04保留FAIL：CarUnit.Flush连通性/分裂/刚体重建已有明确热点；gate→hall长任务具体归因仍OPEN。不得再把旁白本身或所有shader当已证实根因。
4. 自然路线教程显示/播音、完整16步/18声音、重复进出仍待；已有2729跳过路线证据单独保留。
5. A03 DSP/RMS与U10/Q06真机证据继续明确OPEN；其他G4主线交g3/root，不能据本路结果勾整个G4。
