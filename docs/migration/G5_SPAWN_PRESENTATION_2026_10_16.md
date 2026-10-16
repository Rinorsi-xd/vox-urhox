# 无尽出生呈现补齐

- 继续既有 G5，不重开 G0。源固定 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`，实际执行冻结 `three/src/battle/endlessView.js`，SHA `ed56ef6d6eb7417a63d3b682d7d5ede89fcc454ab6af0ef187e45a57f8315c73`。
- 本增量不属于正在实测的不可变 `b932b9cd`。未启动 native/Web/GPU，没有上传、提交或发布；由 root 纳入下一统一包。

## 已补行为

1. 初次出生、五秒复活完成、局内改装返回，均重新开始源 `.6s` 升起动画。
2. 视觉下降量为 `max(0,riseUntil-now)/.6 * max(3,height+2)` 米，采用实际玩家 bounds。没有移动物理刚体或改变碰撞。
3. 原有保护期内按世界绝对时间每 `.12s` 闪烁，保护结束恢复可见；复用原模型和材质，没有创建新材质或几何。
4. `TrialSession.Update/PostUpdate` 开始恢复上一帧视觉位移，末尾在相机、开镜遮罩和环境更新完成后施加新位移；同一时刻重复 PostUpdate 不累计，也不把相机拉入地下。
5. 开镜、死亡和改装继续隐藏车体；使用既有 `NodeVisibility` 保留原先禁用的子节点。损坏重建经实际 `PlayerViewSync` 后仍服从保护闪烁。
6. `RestoreFlash` 是独立 scene root：有恢复光壳时同步最终车体 world transform，并同步显隐，避免光壳悬在升起车辆上方。

## 离线验证

运行：`python tools/migration/check-endless-spawn.py`（本机实际使用 bundled Python 与 `.tmp/nav-python-deps/lupa.lua54`）。工具先执行 unchanged frozen JS，再执行生产 Lua。

- 源黄金：228 组，包含四种高度、三种世界开始时间、`.12/.24/.6/3s` 两侧边界和重新触发。
- 实际 Lua 5.4：497/497 PASS。执行生产 SpawnPresentation、NodeVisibility、EndlessSession 初始/复活/改装/呈现/释放、PlayerViewSync 重建、TrialSession Update/PostUpdate。native 向量、节点、渲染和无关资源/战斗子系统为替身；不是实际网页、画面或性能通过。
- 首次工具缺 audio.Event 替身而失败，补齐测试边界后重跑；未改生产规则规避错误。
- 证据：`evidence/endless-spawn-offline.json`，含每条检查和生产 SHA。

| 生产文件 | 冻结 SHA256 |
| --- | --- |
| scripts/endless/SpawnPresentation.lua | 7932dc02769bdc727034bb29342b03fbb473f539ad7d55368fae5d861245c411 |
| scripts/app/EndlessSession.lua | 3a4badaab25634bfb7a0e80f759eb2a780495b042e53a51313ab51c531bc4323 |
| scripts/app/TrialSession.lua | 9dbac6bc4ad3cb6b493d0604acf124f8aa53691fb213f463f9fe571186c0692c |

## 下一验收

同一下一包实际无尽入口观察初始出生、死亡复活、改装返回，保护期内开镜/退出开镜、损坏修复闪光；确认相机无下拉、车体无残留位移。真实账号恢复、自然完整波次、八敌车同屏真机性能沿既有账本继续 OPEN。

独立发现的 `tierUp` 横幅未消费仅记录为后续缺口，本批没有扩展它。当前 Web 取消恢复、三次陨坑进入及 OOM/严重性能结果由 root 的同包实测记录，不能用本离线结果覆盖。

## 41e4025e 测试期间的冻结复查

生产保持上述 SHA 未改。在 root 实测统一 `41e4025e` 的同时，只新增离线工具复查生命周期：

- `check-endless-spawn-lifetime.py` 新增 **22/22 PASS**，并执行既有497项黄金/入口检查作为加载前置。使用严格 native 节点替身，`Dispose` 后任何属性读写立即报错；实际 `TrialSession.Dispose`、`EndlessSession.Dispose`、`Edit.Leave` 与 `DialogHost.Dispose` 按现有顺序执行，无退役 root 访问。首轮缺旧 DialogHost stub 的 Dispose，修为真实函数后重跑，未改生产。
- 直接从上一帧升起的视觉位移进入死亡 `PostUpdate`，先还原原22m高度再计算观战相机；独立恢复闪光隐藏，pending位移引用清空。
- 实际编辑 `Leave` 在车体仍活着时恢复UI与原viewport；随后车体、闪光、controller释放。重复Dispose以及晚到Update/PostUpdate均无操作。
- 静态核对 `VehicleView.Rebuild` 只清子模型，不销毁presentation所持root；正常死亡由Tick发生，之前Update已撤回上一帧offset。`RestoreFlash.Update` 正常先对齐未偏移车体，最终Present再复制升起后的world transform。
- 原 `check-g5-edit-touch.py` **92/92 PASS** 已重跑，六份生产输入SHA未漂移。
- 没有发现确证的新生产bug。证据 `evidence/endless-spawn-lifetime-offline.json` 与 `evidence/g5-edit-touch-offline.json`。以上仍是Lua/替身验证，不能替代41e4025e实际渲染、网页取消恢复、OOM或性能结果。
