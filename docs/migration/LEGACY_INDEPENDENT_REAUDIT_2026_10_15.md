# 独立旧版残留复审（第二审查员）

冻结时间：2026-10-15 18:24 +08:00。范围为本轮只读静态复审，不是完整迁移完成报告。

## 结论

本轮新增确认两组仍可被实际入口使用的旧派生内容：**LB01：8 个竞技悬浮预制车；LB02：竞技播报池及 10 句实际音频/台词**。另有两个人名旧文案，列为低优先级 LB03。不是整个局内继续运行一份旧控制器：当前多个模式确实使用共用 TrialSession/CarUnit/WeaponSystem/EnemyDriver，五关任务数据的本轮结构化比较也全部相等。

LA01–LA15 属前一审查及其实施批，本报告不重复计数，不把旧描述当成现在仍未修复。动态头顶状态、聚焦框、恢复光效正在其他分支负责人当前工作区修改，本轮未据旧包对这些候选重新判错。

## 身份与证据边界

- 权威源分支 `2026-10-14`，提交 `2b169a9964645f5f346a7158bcb14447f040814a`。
- 实际源为 `.tmp/outgame-source-2026-10-14T10-09-50-505Z`，含冻结时未提交改动；未以 `git show` 取代快照。下列四个关键输入 SHA256 均实际重算并与 `outgame-baseline.json` 相等。
- 目标为当前共享工作区；未修改生产文件、未运行导入器、未运行浏览器/原生、未提交/上传。
- 已读 `CURRENT_EXECUTION.md`、`LEGACY_BASELINE_AUDIT.md`、`FULL_PARITY_PLAN_2026_10_14.md`、`outgame-baseline.json`。
- 当前已登记服务包为 `manifest-e1faa514.json`，目录 `.tmp/outgame-cached-1792058408682`，普通 4306 / QA 4307，脚本指纹 `11c223a54d66f2d77161e9134cd385494dc600c81926526a3aaa36dd0a270a15`。本轮从该不可变目录读取三份 Combat JSON，其 SHA 与当前工作区相等，故 LB01–03 不仅是未入包工作区问题。端口服务是否仍运行未另发请求重验。
- 本轮“确认可达”指已追清生产代码链；未进行自然游戏录像、同状态截图或听感验收，不能替代后续真实入口验收。

| 文件 | 本轮 SHA256 |
| --- | --- |
| 源 shared/build/enemyPrefabs.js | ddb2ab957bb28b2309939ff468924dbbd68fd76d5c221b7c61732cbea706138e |
| 源 three/src/battle/matchVoice.js | 52bda1d09bdabd95b2e967397815a1c8ffceec72f7b68fe89d827befa7f011c1 |
| 源 shared/assets/match/vo/bc/lines.json | a6d473d74ae0708c6391bb22e54598b04328660b186ec2aff669392c2472acf4 |
| 源 shared/battle/matchmaker.js | d9988355c8068a2c700be1b48d30ea1e22d2f2f6139cf009debc0f086163f509 |
| 目标 assets/Combat/Arena.json（与 e1faa514 相等） | 0cb2b2a994cea4e9028cf913179dfb35073c6b2dd52ea30692f82904ea429a03 |
| 目标 assets/Combat/Radio.json（与 e1faa514 相等） | 12ed64f74a7c19273fd80471811fa69acaa183c6f555e9941753e89f134de10d |
| 目标 assets/Combat/FlowSounds.json（与 e1faa514 相等） | 108e639cbd123d6833ffb4d6e85c90005c26c9f1e1cacb09413cbc44195bd7b0 |
| scripts/audio/MatchVoice.lua | bf8dceff0fe73e939a161a030dc8c3f479ecbed66dd0eb93f4f283b6688bd661 |
| scripts/combat/BattleController.lua | 9e2c809cd3ac87b673c2b004b84cdb6a6a04c0192b8f59030ac6a20c03053b56 |
| scripts/app/TrialSession.lua（含当前未入包恢复FX接线） | e3b19d4e23ee767191467294e3fca33fc24cb3db27f6687056381a0083c9a838 |

所有“源/”引用均相对上述冻结快照；目标相对项目根。压成单行的 JSON 引用精确到 `:1` 加 JSON 指针，不虚构不存在的分行。

## LB01 / P2：T3、T4 悬浮预制车保留旧装配

类型：**已确认旧派生数据**。对应 G1/G3，主项 Z03、R01、R07、B01；涉及的模式入口归 H06。状态 OPEN。

源 `shared/build/enemyPrefabs.js:255` 的 hover 构造，`:259` 使用悬浮器实际 extent 扩大中脊半长，`:260` 由 extent 确定横向机臂宽度，`:265–269` 按新位置装配四个悬浮器。执行冻结 `createEnemyBlueprint(role,tier,variant,{player})`，与目标 `assets/Combat/Arena.json:1` 的 `/prefabs` 深比较：80 项中 **72 项相等，8 项不等**。

受影响键为 `blue:3:hover:0`、`blue:3:hover:1`、`blue:4:hover:0`、`blue:4:hover:1`、`red:3:hover:0`、`red:3:hover:1`、`red:4:hover:0`、`red:4:hover:1`。不能扩大成全部悬浮器模型或全部预制车都旧。

| 固定样本 | 冻结源 | 当前目标 |
| --- | --- | --- |
| red:3:hover:0 零件数 | 168 | 114 |
| red:3:hover:0 零件锚点 Z 范围（格，非渲染包围盒） | [-8, 9] | [-6, 7] |
| red:3:hover:0 四个 hover3 锚点 | (±6,2,±4) | (±4,2,±4) |
| red:4:hover:0 零件数 | 197 | 148 |
| red:4:hover:0 零件锚点 Z 范围（格） | [-8, 9] | [-7, 8] |
| red:4:hover:0 四个 hover4 锚点 | (±6,2,±4) | (±4,2,±5) |

实际可达：`scripts/combat/Matchmaker.lua:21` 从 `/lineup` 取队形，`:25` 选 role，`:30–32` 生成实际队友/敌人；4 人队伍的 lineup 包含 hover（源 `shared/battle/matchmaker.js:19–22`）。`scripts/combat/BattleController.lua:39` 直接按队伍/阶位/角色/variant 读这些 JSON，`:41` 传入真实 CarUnit。因此以 T3/T4 车参加**站点争夺或推车**会实际生成旧尺寸/旧块数悬浮车；普通歼灭默认三人队形不包含 hover，不据此声称所有竞技模式都必然遇到。

`scripts/story/Mission.lua:102` 同样会从 Arena 取缺省敌人蓝图，但本轮没有证明所有五关都自然生成受影响阶位/角色，剧情影响列为条件可达，不冒称已自然复现。`scripts/combat/StoryBoss.lua:19,92` 也共用 Arena 蓝图，是否选中这 8 项需按实际阶位/角色后续验收。

玩家影响：敌我悬浮车轮廓、块数、宽度及承载布局不同，不能以现有悬浮器模型本身相同替代预制装配一致。实际质量/耐久/碰撞和AI驾驶影响须重算/实测，本轮未测得数值。

逐条验收：

1. 只读重新执行上述 80 个冻结构造并结构化比较，预期 80/80 相等，保留每项 name/parts 结果。
2. T3、T4 各进入站点争夺与推车，逐队确认 hover 的装配、锚点、零件数、有效性和下载依赖；当前自然路径只使用 variant0，variant1 作为派生数据回归。
3. 同 viewport/固定机位对照 H5 与 UrhoX 初始车体及受损重建，随后实际驾驶，不能只签 JSON 一致。
4. 不批量覆盖其他 72 项，不只改 Arena.source 标签；补各子数据来源哈希。

## LB02 / P2：竞技播报仍引用已弃用的 8 秒语音，并保留 10 句旧录音

类型：**已确认旧派生播报池 + 旧文本/旧 WAV**。对应 G3/G4，主项 A01、A02、Z03；关联无线电呈现/混音 A03 与局内文案 B06。状态 OPEN。与 LA03 的复活规则修正不同，本条针对声音/文案选择，不能因目前 respawn 已为15秒而关闭。

源 `three/src/battle/matchVoice.js:40` 最新 `deadRespawn` 只含 `['c09c']`；目标 `assets/Combat/Radio.json:1` `/calls/deadRespawn/ids` 仍为 `['c09c','c09d','c09e']`。两个旧条目的目标文本分别为“车没了，八秒后新车出库，先喝口水。”、“散架了，别灰心，八秒后再来一台。”。源资产目录本身也保留 c09d/e，**资产存在不是缺陷，仍被目标活动池引用才是缺陷**。

实际生产链：`scripts/combat/BattleController.lua:84` 调用 `voice:Kill` → `scripts/audio/MatchVoice.lua:65` 在争夺/推车玩家死亡时因 `cfg.respawn` 非空而 Say('deadRespawn') → `:22–25` 从当前 Data.calls 入队 → `:34–37` 随机选 ID，读取 line.path 播放并显示 line.text。因此两句“八秒”在当前实际15秒复活模式仍有被抽到的机会。这不是仅有历史死文件。

此外直接读取最新源 lines.json 与目标 `/lines`，共有 **10 个仍在源活动 LINES 中的 ID 同时存在 text 与 dur 差异**；逐个 WAV 实际 SHA256 亦全部不同，已经证明音频字节没有同步，不是只改了时长元数据。以下源/目标时长为各自 JSON dur，实际排队实现用 sound.length，因此不能把 dur 差异直接说成当前排队延迟。

| ID / 事件 | 最新冻结源文本 / dur(s) | 当前目标文本 / dur(s) |
| --- | --- | --- |
| c01 / firstBloodUs | 开张啦！第一台，漂亮！ / 2.42 | 第一滴血，开门红啊。 / 1.69 |
| c01c / firstBloodUs | 首单到手，开门红！ / 2.15 | 第一滴血，漂亮，开张了！ / 2.44 |
| c01b / firstBloodThem | 哎呀，被对面抢先了，没事，咱们找回来！ / 3.58 | 对面先拿了一血，别急，找回来！ / 2.66 |
| c04 / double | 一口气两台，可以啊你！ / 2.41 | 双杀，手艺不错嘛。 / 2.29 |
| c04b / double | 又一台！今天手感挺热啊！ / 2.75 | 双杀，今天手感挺热啊！ / 2.42 |
| c05b / triple | 三台了！对面已经开始慌了！ / 3.15 | 三连杀，对面已经开始慌了！ / 2.45 |
| c05 / streak | 停不下来了！这个月优秀员工非你莫属！ / 3.73 | 连杀，杀疯了，这月优秀员工归你了。 / 3.47 |
| c05c / streak | 还在拆！对面都快哭出来了！ / 2.83 | 连杀停不下来，对面都快哭了！ / 2.58 |
| c11 / respawned | 新车到了，油门踩到底，找他们算账去！ / 3.43 | 新车出库，油门踩死，回去报仇。 / 3.36 |
| e04 / last100 | 就差一百米！推上去，推到底！ / 2.91 | 最后一百米，油门踩死，推到底！ / 3.23 |

源 JSON 精确位置：`shared/assets/match/vo/bc/lines.json:114,118,122,154,158,162,166,170,226,390`；源活动池/真实事件选择为 `three/src/battle/matchVoice.js:30–44,186–206,218`。目标均为 `assets/Combat/Radio.json:1` 加 `/lines/<id>`，WAV 为 `assets/Sounds/BattleRadio/<id>.wav`。

首杀/连拆的真实触发为 `scripts/audio/MatchVoice.lua:61–70`，复活为 `scripts/combat/BattleController.lua:123`，末100米为 `scripts/audio/MatchVoice.lua:98`。不宣称所有台词每局必播；存在随机选句、优先级和过期条件。

音频指纹例（其余10句逐一实比均不等）：

```json
{
  "c01": {
    "source": "b8f2159d5120d03db9a788e75244d929a6e49a805d6cc5be9a74adbd99c38073",
    "target": "ff45063324b53bc25bf490b45877e4554d55cfe2bf0078c816ad75dcc1b38f66"
  },
  "c11": {
    "source": "590937382fc0a4cbcaca877f3e862e19ff9611459c8c1a3e4161a09929356aba",
    "target": "887812a4eab91100897852c11f45a4ca943b2520e7dcf848b1c62fced92c140e"
  },
  "c09c": {
    "sourceAndTarget": "c688608ac7a154c86c49e560e7ec7b6821f31da79dff3c1776ea877595dd9fcc"
  }
}
```

逐条验收：

1. 从冻结 matchVoice 实际导出 LINES/specOf，calls 全结构相等，deadRespawn 必须只有 c09c；不得为凑15秒另造句子。
2. 原活动 ID 全量比较文本/元数据，10 个改动 WAV 逐字节/SHA一致，已有相同音频不重新压缩。
3. 真实争夺和推车自然死亡/复活，各观察至少一轮，音声、字幕、实际15秒倒计时没有8秒误导；三竞技触发首拆、双拆、三拆、连续拆，推车末100米分别对照源事件。
4. 复验音量、队列冷却/过期/不连播重复、离场停止，PC/20:9通讯卡不残留。真机音频连续性仍由原性能项验，不以本条数据对齐代替。

## LB03 / P3：匹配随机名字池两处旧文案

类型：**已确认旧派生文案**。对应 G2/G3，主项 H06、B06、Z03。状态 OPEN，优先级低于 LB01/02，不阻塞其先实施。

源 `shared/battle/matchmaker.js:10–11` 为“慢一点会散架”、“修车靠基地”；目标 `assets/Combat/Arena.json:1` `/names/14`、`/names/25`（JSON数组0起始）仍为“慢一点会死”、“回血靠基地”。`scripts/combat/Matchmaker.lua:19,24` 会从该池生成实际阵容名，故不是死文案。固定 seed90862445 的示例 roster 恰好未抽到这两个名字而全等，不能据一次 roster 相等签整个名字池相等。

验收：全量名字池与冻结 NAMES 等序深比较；通过确定种子/自然多次匹配确认两项可出现，名片/头顶/结算同一名字且无旧文案。无需改匹配随机算法或玩家昵称。

## 本轮已确认相等与公共链

1. Arena 中 modes、CONQUEST、ESCORT、HULL、STRUCT、AI_TUNING、AI_COMBAT、LINEUP、固定seed90862445 roster、推车 payload 均与冻结源执行值深比较相等。此结论只覆盖派生字段，不声称所有 Lua 控制器状态机/物理手感相等；LA03–05已有规则修复和未关闭验收保留。
2. FlowSounds 的全部 cues（path/gain/gap/loop/pool）及 foundVoice 与冻结 BATTLE_FLOW_CUES/MATCH_FLOW_LIVE/MIX_TRIM 按现导出转换后深比较相等；不能把旧source标签扩大为内容也旧。本轮未逐个试听/全音频字节检查该组。
3. Level1–Level5 的 level 数据与冻结原模块相等：按现导出器声明翻译函数字段（L2 noEnemies、L3 shieldDamaged/dropCoupon），剔除生成端 setup/gradePolicy/resultPolicy 后全结构无差异。这只是任务数据，不证明 Mission/五关/Boss自然流程都已经验收。
4. `scripts/app/TrialSession.lua:30–40` 区分 endless/salvage/story/battle/practice 控制器，`:42–49` 再统一 combat/feedbackPlayer/WeaponSystem；后续共用 Camera、CombatView、DriveView、DriveHud。试车/自由已走 PracticeSession，不重复LA01旧结论。竞技控制器与剧情控制器均使用当前 CarUnit/EnemyDriver，不能把模式功能差异概括为“各自全是旧版”。
5. 当前 import-battle-source.mjs 已正确读冻结snapshot；根因在派生内容更新不完整，**仅运行正确来源工具或改source标签不等于现包内容已同步**。本轮没有运行会覆盖内容的导入命令。

## 未审完的范围

本轮没有穷尽138主项。局外全部状态/建造输入/存档账号恢复、所有物理公式与地图、完整五关自然流程、Boss/片尾、无尽/打捞经济、所有零件模型/骨架、全部预制车Catalog、字体实际渲染和移动真机持续性能均保留原OPEN；不据未审判旧。

已知但不新增ID：GT转角/COM和履带距离属于已有引擎映射/实测差异；开篇PCM卡顿、连续换图OOM、自然教程可见性、真实账号与编辑器证据为现总账本未关闭项。LA12–15及恢复FX候选尚未入e1faa514，不把旧包截图判成候选修复失败。停用CSS/历史文档/磁盘仍有旧音频，只有证实生产引用才列本报告确认项。

建议本批顺序：先定向同步LB01八份蓝图与LB02活动语音池/十个音频，再顺手修LB03；随后一份新不可变包按上述步骤验收。此报告截至上述指纹冻结，后续修复应另记构建/证据，不覆盖本次失败事实。
