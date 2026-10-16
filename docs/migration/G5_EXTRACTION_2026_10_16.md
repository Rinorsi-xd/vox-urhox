# G5 撤离接应与死亡等待补齐

## 身份与生产范围

后续统一包046debe2已包含本批。无尽29项实际Web/运行错误0，证据`evidence/endless-banner-manifest-046debe2-2026-10-15T18-22-07-300Z`；实际图已看，源toast短暂遮横幅保留。未触发死亡等待或搜撤接应，不能代签这些自然入口；加载最长4103.165ms，性能FAIL。无提交上传。

沿 `CURRENT_EXECUTION.md` 的4227功能批继续，不重开G0。源冻结 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`，快照 `.tmp/outgame-source-2026-10-15T12-35-57-243Z`。本增量尚未收入4227，不用旧包网页结果代签。无GPU运行、完整构建、提交或上传。

| 生产文件 | 最终 SHA256 |
| --- | --- |
| scripts/app/EndlessSession.lua | 2661cbf0e34b0a51ac2f423ec49c1808e0df37840127efe552057d488ac8572e |
| scripts/salvage/RunRules.lua | 87a664d02eff7e3a66d06f0c0216fe91d513b290defdd6e1935df1c23b3e51a7 |
| scripts/salvage/Run.lua | 2dfd40ac5243e0b0df6d36e71f8db415b02fd63de8cec3b4bd8359deaa8eef24 |
| scripts/salvage/Cinematics.lua | 29036a2b351290ac13254c9b2b90252c0b25b3d4befc8e3f2f2588e5d3221b03 |
| scripts/ui/SalvageRunHud.lua | b30bf9fd1fb67297896d410203e4578824bdaec1f58676a0127bdbfc30aed98f |

## 已证实缺项与对应修改

本小批最初在Session `4ed4d32...13273ee`冻结并经 `G5_EXTRACTION_INDEPENDENT_AUDIT_2026_10_16.md`独审；随后同文件加入独立的出兵缓存优化，最终为上表2661。547源检查和222/497/22报告已在2661实际重跑。原独审仅签4ed4时的本小批语义，不自动代签后续缓存；缓存证据见 `G5_SPAWN_CACHE_2026_10_16.md`。

1. 源 `salvageRun.js:947–950` 中途离开撤离圈保留 `exLeft`，再次进入把剩余秒数传给运输机。迁移规则已保留倒计时，但动画固定使用原始 `exit.wait`，剩2秒时仍按6秒飞来。现在规则保存创建当刻、扣本步dt之前的 `approachWait`，发 `extractApproach`，实际 `Run.Events` 把此值传给 `Cinematics.Approach`。动画仍保持源3–6秒限制，未修改撤离所需秒数。
2. 同源入口的“撤离中 / 待在圈里 N 秒，运输机正在赶来”通知和绿色边条、信号塔首次呼叫3秒姓名卡此前缺失。现接原文及源一次性门禁，重进圈只重复接应通知，不重复信号塔警报/追兵。`Run.Feed` 保留源显式颜色和缺省 `#7ad8ff`，`SalvageRunHud`绘制所存颜色。
3. 源 `endlessSession.js:286–300` 复活等待期间，下一波/改装均先显示“战车被摧毁，请等待 N 秒后复原”。迁移此前下一波静默失败、改装给出错误战斗提示。现两入口首先调用 `WaitForRespawn`，按源 `ceil(max(0,respawnAt-time))`；包括到期尚未被规则步消费时仍显示0秒，不提前允许操作。未修改复活时长或三命规则。
4. 源 `endlessLoot.js:19` 金币通知1400ms，迁移漏传参数而默认2200ms；现只补1400ms，零件通知仍2200ms。源 `endlessHud.js`层级80、`style.css`顶部80px、`story.css:108`全局toast层级860，源本身也允许短暂遮挡横幅；未自行移动toast或横幅，未改层级。最终同包画面仍需核对。

## 可复跑证据

运行 `tools/migration/check-g5-extraction.py`，由Node执行未改写的冻结JS `SalvageRun.update`、`SalvageCine.approach/_approachStep`、`EndlessLoot.onEvent`、`EndlessSession.nextWave/enterEdit`，再与实际Lua规则/事件消费者/动画/提示队列对照。源文件均核登记SHA。

- **547/547 PASS**，`evidence/g5-extraction-offline.json`。
- 10场景70真实源更新帧：初始等待2.5/3/4.25/6/20秒，普通/信号塔，离圈、两次重入、最终撤离，比较剩余时间、实际通知/追兵顺序、原文与持续时间。
- 48接应机位：0/2/3/4.25/6/20秒输入，比较3–6秒限幅、运输机位置/旋转和到达扬尘门禁；实际Lua `Cinematics.Update` 的无事件兜底也读取保留剩余秒数。
- 28实际源死亡等待入口：未等待、pending=0、过期、恰好到期、0.001秒、1秒、4.7秒，rest/combat和两入口，验证提示先于改装位置/状态检查，等待中不调用下一波或改装规则。
- 实际Lua `EndlessSession.Events -> SourceToasts.Push` 对照金币/零件文字、种类、时长，0金币不提示。
- 最终生产SHA再次执行横幅222、保险库675、拾取92、结算29项，全部PASS；对应报告均刷新最终SHA。

测试开发初次失败为JS向量适配器漏 `copy`，追加入口夹具又出现括号/跨模块`PARK`重复声明与Lua伪三元误触第二入口，均只修测试适配器/模块作用域，未为通过检查修改冻结源或生产规则。最终结果以上述实际执行为准。

## 未关闭边界

向量、UI、FX、音频、物理均为适配器；没有自然成功撤离、自然无尽死亡复活、新包渲染/试听、真实账号、真机或性能验收。G5自然搜撤/900秒超时、完整战斗与G6性能继续OPEN。下一步root收入统一包并串行回归相应真实入口。
