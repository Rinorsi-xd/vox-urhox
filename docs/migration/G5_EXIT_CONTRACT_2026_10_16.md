# G5 撤离截止与目标指引源核对

2026-10-16，H5 基线 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`。本批唯一生产变更：`scripts/salvage/RunRules.lua` 的 900 秒截止原因改为原文 **“超时 · 撤离窗口关闭”**，经过现有 `Run.Events → Finish` 进入结算。未更改时间限制、撤离条件、票据、伤害或关卡参数。

生产 SHA256：`bd43cdef0cc33f2b18583ed68e6c78eceb4ee7a6fc0415a7942b425a19136f53`。本批不属于 root 正在运行的旧 `manifest-188b` GPU 包。

## 实际验证

`tools/migration/check-salvage-exit-contract.py` SHA256 `f5614ff0f9a385222a92286f29dacbd8ac23e8bb24c66953830ce2862a95edca`，实际 **35 检查 / 28 源场景 PASS**，证据 `evidence/salvage-exit-contract-offline.json`。

- 从冻结文件读取并验证哈希，执行完整原 JS 类的 `_objective` 与 `update`，不手写目标或截止算法作为金标。
- 24 个目标场景核对早晚时点、0/15/20 格容量、核心件是否已搜；生产原目标算法保持不变，与源一致。
- 4 个截止边界核对原 `update` 的触发时点及原始失败原因，并执行真实 Lua `RunRules.Step → Run.Events → Run.Finish` 的结果标题、清舱与提交。
- 真正旧输入固定为 `48ef15f2c9c95c400f91ee6e34309399d02b3733:scripts/salvage/RunRules.lua`，SHA256 `31f704dcb780fc343f84c96ee6b2e8545a5f15cd566a7db5aeb330d0030e1a00`；该旧代码在准确结算标题检查失败，没有依赖移动的 HEAD。

直接关联的既有报告已按最终生产真实重跑：改装/触控 92、撤离 547、结算 29、掉落反馈 476（含 8 负控）、保险库 675，全部 PASS。没有直接改证据哈希冒充重跑。

## 撤回误判

首次基于未同时绑定 SHA 的 `Get-Content / Select-Object` 截段误判 `_objective()` 已禁用。执行基线登记文件、校验完整源 SHA `6f49bacb3008f430607cbcb5d4fca5f4786490c0644d740908bfe2040d1ee41d` 后，真实 JS 调用立即否定该判断。已撤回该候选，恢复原生产目标算法与原 `check-salvage-director.lua` 期望；最终 git diff 只有截止原因一行。没有证据证明冻结文件或分支被外部修改，不能如此归因。

本批不宣称迁完自然撤离。source `_objective` 的真实执行作为防止误改的正向回归保留。旧 Director 原生测试的 CPU 前段尝试遇到既有夹具缺 `run.fx`，未将其算 PASS、未改变生产来迁就夹具，也未运行 GPU 后半；新专项独立执行实际目标函数覆盖本批边界。

## 仍开放

H5 的结算用时包含撤离/死亡演出，当前 Lua 在 `rules.finished` 后停止计时，因此少计相应演出时间；涉及 TrialSession 与 Cinematics 的共同生命周期，本批只记录，未作未经联合验证的时钟更改。L04/L06 自然成功撤离、自然死亡完整演出与返厅、真实账号、实际画面和性能仍 OPEN。

本报告的 SDK/绘图/声音/存储消费者是适配器，不是平台或自然游玩证据。无构建、GPU、提交、推送；共享 CURRENT、LEDGER 和统一注册未修改。
