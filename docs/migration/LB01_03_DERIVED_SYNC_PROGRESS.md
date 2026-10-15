# LB01-LB03 派生内容定向同步

## 当前状态

2026-10-15：本批生产文件已冻结。LB01 八份悬浮车装配、LB02 活动播报池及十句原音、LB03 两处随机名字已修复。离线独立检查 **701/701 PASS**；真实控制器数据读取只签静态兼容检查，未签自然游戏、新包画面/听感或真机性能。无提交、上传、提审或引擎升级。

## 权威输入与所有权

权威分支 `2026-10-14`，commit `2b169a9964645f5f346a7158bcb14447f040814a`。实际执行 `.tmp/outgame-source-2026-10-14T10-09-50-505Z` 内的函数，包含冻结时 dirty 内容，不以 `git show` 代替。实际载入的 52 个模块/JSON SHA256 逐个与 `outgame-baseline.json` 相符；116 个活动原音也逐个验证冻结清单指纹。

生产所有权仅 `assets/Combat/Arena.json`、`assets/Combat/Radio.json` 和十个 `assets/Sounds/BattleRadio/*.wav`。未运行全量 `import-battle-source.mjs`，未写 avatars/FlowSounds/控制器/UI/地图文件。素材为原始 WAV 字节复制，无录音、AI 生成或音频重压缩。

Arena/Radio 的旧 `source` 标签描述此前整文件生成批次，本批故意保留该无关字段；本次更新的各派生字段来源、实际输入和输出 SHA 单独登记在下列证据。不能根据标签假称整文件已全量重新生成。

## 已完成内容

| ID | 实际变更 | 已检查 |
| --- | --- | --- |
| LB01 | `blue/red × T3/T4 × hover × variant0/1` 八份蓝图由冻结 `createEnemyBlueprint(...).toJSON()` 生成；T3 为168件、T4为197件 | 80/80 所有 name/parts 全结构相等，每份均有旧值/新值/生成值 SHA；另外72份与修改前完全相等 |
| LB02 | `calls.deadRespawn.ids` 仅保留 `c09c`；移除不再活动的 `lines.c09d/e` 元数据，因此当前 MatchVoice 也不再预载它们；磁盘历史原音不删 | 67个 calls、116个活动lines 全结构相等；116个活动音频源/目标 SHA 全相等 |
| LB02 | 原字幕、dur、WAV同步十句：`c01,c01c,c01b,c04,c04b,c05b,c05,c05c,c11,e04` | 十个音频共939122字节，全部为原始16kHz/单声道/16bit PCM；不拿 JSON dur 代替实际声长队列验证 |
| LB03 | 名字池第15/26项改为“慢一点会散架”“修车靠基地” | 完整等序名字池与冻结 NAMES 相等，其他名字/随机算法未动 |

修改前指纹保存在导入证据，并与不可变 `manifest-e1faa514` 对应目录 `.tmp/outgame-cached-1792058408682` 的 Arena/Radio 实际文件 SHA 重合。独立检查从该档案再深比较所有未授权修改字段，确认其他 Arena/Radio 字段与72份预制车未变。Combat、BattleRadio、Avatars 三目录逐文件比较表明恰好只有上述12份生产资产变化；未重复复制其他相同资源。

## 工具与证据

- 定向一次性修复：`node tools/migration/import-lb01-03-derived.mjs`。要求修改前恰好是审查确认的8份蓝图/10句元数据/1池/2名字差异，否则拒绝操作。已修完后再次运行会因前置断言失败，不用于日常重新导出。
- 只读生产复验：`node tools/migration/check-lb01-03-derived.mjs`。独立执行冻结源，读取生产数据，输出检查证据，不写生产资产。
- 共享只读源执行辅助：`tools/migration/lb01-03-source.mjs`。只为导出冻结函数内的 NAMES/LINES/specOf 添加内存模块钩子；Radio 依赖用空类替身以避免浏览器构造，不修改磁盘源。
- 导入证据：`docs/migration/evidence/lb01-03-derived-import.json`。含52项源输入、修改前后三目录完整文件指纹、精确差异清单。
- 最终检查：`docs/migration/evidence/lb01-03-derived-check.json`。701/701 PASS，含80份逐件指纹、完整活动calls、116句原字幕/时长/路径/音频SHA、实际控制器SHA及每项断言。

生产输出 SHA256：

| 文件 | SHA256 |
| --- | --- |
| `assets/Combat/Arena.json` | `6d50caf9cdc76ec495079f100d4409f96ab1b623df74a9cef7df6a8a63bd4153` |
| `assets/Combat/Radio.json` | `8bfd947836c93ccfd2e9af197019fbdcba861454de03f2e5f9765d1d4dc4369b` |

## 读取兼容与待验收

已静态核对当前 `BattleController.Dependencies` 与实际生成时均按 team/tier/role/variant 读取 `Data.prefabs`；Matchmaker 从全量 `Data.names` 取名；MatchVoice 从 `Data.calls` 取 ids，按 `Data.lines` 路径预载/播放并显示原字幕，队列仍按实际 `sound.length` 加 `.35s` 排下一句。未修改这些控制器或随机选择/冷却/音量实现。静态检查不等于实际加载、播放或驾驶测试。

以下继续 **OPEN**，交给同一新不可变构建验收，不把数据一致冒充自然路线已通过：

1. T3/T4各在站点争夺与推车自然匹配，确认敌我hover初始/受损装配、资源下载、有效性、碰撞与实际驾驶；variant1另作派生回归。
2. 争夺/推车各自然死亡与15秒复活，确认不再抽到“8秒”播报；三竞技首拆/双拆/三拆/连续拆及推车末100米逐事件看字幕听原音。
3. 播报音量、冷却/过期/不连续重复、离场停止与PC/20:9通讯卡无残留、音频持续性与真机帧时。
4. 确定种子或多次自然匹配让两个新名字出现，名片/头顶/结算保持同名；不以固定seed未抽到旧名字当验收。
