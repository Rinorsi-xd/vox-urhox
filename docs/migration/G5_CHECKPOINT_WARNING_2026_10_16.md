# G5 无尽检查点写失败告警

冻结源为 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`。本批只补一个生产漏接：休整存档写入失败时，原 `endlessSession.js:321-324` 显示警告；迁移的 `Persist` 只返回失败，清波/补给/改装返回的调用者均忽略返回值，导致玩家不知道检查点未保存。

## 生产变化

`scripts/app/EndlessSession.lua:186-191` 在 `store:Write` 返回失败时，以原文 `本局进度未能写入浏览器存储` 调用既有 `SourceToasts` 的 `warn` 通道。成功不显示提示，保持 rest 守卫、原存档 key/数据/validator 和 `ok,err` 双返回；不增加重试、阻断、扣款回滚或波次变化。

生产已冻结 SHA256：`1f1f4d32ef79969b81a293b880bb327fa1e0b19a2d7a29bfb3302262bd3dfe88`。相对848f该文件仅上述方法变化；没有资源增量、GPU、构建、提交或上传。

## CPU 证据

运行 `verify-endless-checkpoint.py`，证据 `evidence/endless-checkpoint-offline.json`：

- 实际执行冻结 H5 `persist`，5种状态 × 成功/失败，共10场景；保存失败由实际原 `write` 捕获 `localStorage.setItem` 抛错。
- 实际执行 Lua `Run.CheckClear → Events → Persist`、`ChooseSupply → Events → Persist`、`ResumeEdit → Persist`；三条链分别覆盖成功和失败，检查提示、一次原参数写入、波次/信用点保持、补给正常领取及改装正常返回。
- 共50检查PASS。实际848f `EndlessSession.lua` 为负控，SHA `2661cbf0e34b0a51ac2f423ec49c1808e0df37840127efe552057d488ac8572e`；原文金标及三条失败链共4独立反例均拒绝。
- 首次源执行适配器缺少 `window.dispatchEvent/Event`，因此还未跑目标断言便失败；补齐浏览器事件适配器后重跑通过，没有修改生产来绕过。

统一审计 registry 全部直接关联该生产文件的4报告已真实重跑：`endless-banner` 222、`endless-spawn-lifetime` 22（另执行497 setup）、`g5-extraction` 547、`endless-spawn-cache` 1291，全部PASS；其生命周期setup前置 `endless-spawn` 497另重跑PASS。报告生产哈希均为最终冻结SHA，未只刷新哈希。独立子agent对生产/冻结源只读交叉审查，未发现本批回归。

## 验收边界

CPU使用受控存储及native/UI/音频/物理适配器，没有启动运行实例。尚未证明新包可见警告、自然完整波次、自然成功撤离、账号刷新恢复或性能。异步云队列后续失败不属于 `Write` 同步结果。现有自然打捞工具已能搜箱、判定成功撤离、精确结算并回厅，但最新路线只完成搜箱/放弃；不能以本次存档反馈修复代签成功撤离。
