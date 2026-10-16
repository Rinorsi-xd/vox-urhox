# 受击闪光首次绘制预热

继续既有G0-G6；H5基线 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`。不提交或上传。

## 实际缺口

`manifest-e1fc12f8.json` 的公开射击报告 `evidence/destruction-web-2026-10-15T17-27-05-967Z` 完成19项功能检查，运行错误0，但射击窗有一帧100.090ms。该帧附近没有实际Flush重建样本。

console在01:28:23.716首次记录 `surface_unlit_C_vNqT6YVGvGZQ_lJg47NRmv_b7fef1c8_404C43E2.glsl`。该包manifest中 `Shaders/BLGL/RestoreFlash.shader` 的UUID为 `C-vNqT6YVGvGZQ-lJg47NRmv`、hash为 `b7fef1c8`，与运行生成shader对应。长帧结束约01:28:23.787。现有CombatWarmup没有实际绘制该材质，源受击效果迁回后首次绘制落在开火期间。

这证明首次载入发生在对局中，与长帧相邻；没有GPU编译细分计时，不能断言这解释全部100ms。

## 改动

- 新增 `render/FlashWarmup.lua`：加载页覆盖期间，借用当前玩家真实模型和RestoreFlash材质，依次实际呈现4个共享模型实例和1个实例；另外绘制带joined uniform的CustomGeometry分支。只有方块的车仍预热joined分支。
- 代理不含物理体、不产生战斗事件、不调用RNG、不修改源车型位置/缩放/材质uniform。joined材质单独clone；退出、取消和构造异常释放代理与clone，借用模型和材质仍由原会话持有。
- CombatWarmup在效果阶段后、地图点光阶段前增加两次实际呈现，加载页关闭门禁不变。
- 公开射击工具新增运行shader载入时机断言，要求其在加载阶段出现且在实际射击前完成。它不证明驱动内部所有variant已编译。

## 验证

`verify-flash-warmup.py` 实际执行FlashWarmup、CombatWarmup和LoadingFlow：41个预热/取消/异常/借用资源场景及7个加载生命周期场景通过。g4独立复跑通过，legacy独立只读检查无新增归属问题。原生绘图API使用替身，不能关闭GPU/性能验收。

## b6f 实际 Web

`manifest-b6f6882e.json` / `.tmp/outgame-cached-1792086326119` 的实际公开工坊→试车→鼠标瞄准射击完成21项检查，运行错误0、probeErrors0。证据 `evidence/destruction-web-2026-10-15T17-46-27-022Z/report.json`。

实际生成的 `surface_unlit_C_vNqT6YVGvGZQ_lJg47NRmv_b7fef1c8_404C43E2.glsl` 在 `trial-load` 首次记录，发生于实际开火之前；开火之后没有首次载入。实际白闪141次、盾蓝闪41次，root查看活跃受击与击杀截图；GT209→152件后击杀，原+300收集和kill_confirm/score_tick实际触发。

含截图与只读探针的射击窗1070个rAF，中位33.345ms/P95 50.015ms/max66.795ms，0帧>100ms；57次实际Flush最大20ms。仅本路线100ms门槛通过，平均仍约30帧；随机命中序列/后台负载不同，没有严格旧新A/B，不推算提升比例或签稳定60帧。此证据不关闭竞技严重性能、地图加载冻结、全部shader变体或真机持续表现。

当前生产哈希以 `evidence/flash-warmup-offline.json` 为准；下一功能包及同包覆盖边界见 `CURRENT_EXECUTION.md`。
