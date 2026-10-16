# a9f40cb6 统一包独立离线复核

快照 `.tmp/outgame-cached-1792079398645`，manifest `a9f40cb6`，复算指纹 `5a29de2f5e549c5c7e823084decf9e8ac747be68da6cca1ad1cbcf06e5cced10`。

**整体保留 FAIL：包中额外混入已经从当前源码删除的临时故障注入脚本 `_hudfail.lua`。** 当前生产475 Lua；快照、identity、manifest各476 Lua；manifest全部文件7463。当前475 Lua逐 SHA 均与包一致，上包遗漏的GarageHud初始化失败清理保护已进入。

额外脚本 SHA：`6d6fa842cf4c5a9dec00c323d7c37f9b9394074ce79ce44af11cfb2e1df320ce`。它重写require，在请求ui.HomePages时故意抛错，再执行main。manifest正常入口仍为main.lua，快照scripts及.project没有该临时脚本引用；正常入口不执行它，但不应把带额外故障代码的包签成完全匹配当前生产。

其余核对结果：

- 476个包内Lua逐SHA和identity一致，manifest脚本覆盖/唯一性/长度一致。
- 13份最新离线报告共63条production/资源SHA全部同时匹配当前和快照，0条陈旧。
- Outgame.json、SalvageRules.json与当前生产相同；manifest均含boot/default/#blocking。
- ResultVoices.json注册表当前/快照相同；12/12条OGG当前SHA=快照SHA=derivedSha256；对应原MP3的实际冻结源SHA=registry.sha256=基线清单SHA；12条OGG均有OggS文件头及唯一manifest条目，长度一致。
- MatchTarget模块已进入identity、snapshot、manifest；Controller.Pick→objectives.Goal→driver.Step实际接线全部存在。

复现：`node tools/migration/audit-unified-snapshot.cjs .tmp/outgame-cached-1792079398645`。详细证据：`evidence/unified-snapshot-manifest-a9f40cb6-audit.json`。

未编辑production或构建快照，未启动GPU/native/Web。上述文件与OGG内容核对不代表解码播放、音频连续性、画面、输入或性能通过。已回报root等待不含临时脚本的最终包身份。
