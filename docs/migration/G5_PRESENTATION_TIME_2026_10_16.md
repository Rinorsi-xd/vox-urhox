# G5 打捞演出结算计时

- 基线：H5 `2026-10-15` / `b276064942ae09c0227ec28d4cfda1d5ff006455`，冻结快照 `.tmp/outgame-source-2026-10-15T12-35-57-243Z`。执行前校验 manifest 中的源文件 SHA；不读取移动分支作为 golden。
- 根因：Lua 在撤离倒计时完成 / 玩家死亡时将 `rules.finished` 置真，固定步停止推进 `rules.time`，但撤离 / 死亡演出仍在运行。H5 对应阶段仍累计时间，仅停止其他玩法更新，因此旧 Lua 结算漏记演出时间。
- 窄修复：`Cinematics.Update` 仅在已 finished、未产生 result 的 extract/death 演出开始帧捕获计时资格，帧末调用 `Run.AdvancePresentationTime`。只推进 elapsed，不推进热度、出兵、搜索或其他玩法时钟。未开始、未落地、已释放、其他演出和正常玩法不额外计时。
- 最终帧顺序：原 H5 `Run.update` → `Cine.update/_end` → `_extracted/_fail/_finish` 保存旧 `time` → 本帧 `time += dt`。Lua 同样先真实 `Finish/Commit` 保存结算时间，随后才推进本帧 elapsed。下一帧 result gate 阻止继续推进。

## 实际验证

- `check-salvage-presentation-time.py`：**2814 检查 / 12 场景 / 918 源帧 / 2 负控 PASS**。实际执行冻结 JS `Run.update`、`Cine.update/_end`、`Run._extracted/_fail/_finish`，比较实际 Lua `Cine.Update/Finish`、`Run.Finish/Commit`；适配仅限图形/UI/运动/SDK 边缘。
- 场景覆盖：extract/death，0.05 / 0.1 / 混合含 0 dt，input.controlling true/false，每帧 elapsed、result 出现帧、演出完成帧、最终帧快照顺序和结果后不再计时。退出演出被拒绝、结果后可返回；drop/elite/无演出、未开始/未落地/已释放/已有结果/正常玩法均无重复时钟。
- 真实旧码负控固定 `48ef15f2c9c95c400f91ee6e34309399d02b3733`，Run SHA `f925151ef6bf2cfb017ba694f6dc64a0f4ea0305064cab5bfe38262b4ab37a43`、Cinematics SHA `12a61acf7c1df17cbf0a82f151dac0f11bcd4e03d4ef6985e76e9b1c816f10b9`，在第一个实际 elapsed 比较拒绝。另将加时错误移至 Finish 前的变异在最终帧结果比较拒绝。
- 修改后实际重跑全部直接关联离线报告：云恢复 61 / 5 负控；编辑触控 92；撤离 547；结果 29；遭遇反馈 104；掉落反馈 476 / 8 负控；vault 675；退出契约 35 / 1 负控，全部 PASS。不是只更新哈希。
- 另一子 agent 只读交叉审了源最终帧顺序和 TrialSession finished gate，未发现本变更新增语义或数据风险；未修改共享 TrialSession。

## 冻结身份与边界

- Run SHA：`0f4deb3bb26ffdd4059a35e105a510158c72400f6585fb4c2c2c3b0b277c56ef`。
- Cinematics SHA：`4f3ade7a344aa0f6891a5c7749871ccd0ecbefe3795115769aa37bf62826584b`。
- 检查器 SHA：`7da32767b0d70693964fcc8b0d4ca41587052882c039d7e3d3ff769a65cf7f2e`。
- 证据：`evidence/salvage-presentation-time-offline.json`；源 Run SHA `6f49bacb3008f430607cbcb5d4fca5f4786490c0644d740908bfe2040d1ee41d`、源 Cine SHA `908c8b3c5c062cb303376d9cbbd5e09d03e4392e08a96df72928fffa53feb3ef`。
- Lua 既有视觉 dt 上限 0.1 秒未改变。新增统计保留调用方传入的原 dt，但长冻结时演出完成时长仍可能与 H5 不同；没有签长 dt 视觉时长 1:1。
- TrialSession 集成仅只读核对，未执行整个真实浏览器 session。没有 GPU、自然撤离 / 自然死亡、真实账号、可闻音效、视觉或性能签收，也没有提交、推送或启动服务。待 root 统一合包和真实验证。
