# G3 第三关加载预热时间线

日期：2026-10-16。只读分析冻结包5b8cf21c、H5基线2026-10-15 / `b276064942ae09c0227ec28d4cfda1d5ff006455`。本报告不代表已优化。

证据：`evidence/story-presentation-manifest-5b8cf21c-2026-10-16T01-14-34-240Z/pc.log` 与 `pc.json`。该路线15项功能检查通过、运行错误0，但第三关进场仍慢。

## 实际分布

加载页记录download34.938s、resources1.478s、scene6.223s、prepare7.071s、activate36.687s。最后一项由LoadingFlow在SceneLoader安装后继续计时，包含渲染预热；不能解释成36.687s同步装车。

| 阶段 | 墙钟时间 | 耗时 | 日志中的工作 |
| --- | --- | ---: | --- |
| SceneWarmup批次 | 09:16:12.484–09:16:29.887 | 17.403s | 1948个drawable、244批；视锥外1384个不进批；156个新shader |
| 完整世界阴影帧/交接 | 09:16:29.887–09:16:31.252 | 1.365s | 18个新shader；CombatWarmup构造约28ms |
| CombatWarmup | 09:16:31.252–09:16:49.127 | 17.875s | 429组、256帧；157个新shader |

上述窗口编译日志331条，完整路径331个唯一值。没有发现同一路径重复编译，不能以去重编译作为既定根因。

## 确切长帧证据

- pc.log第1902行：引擎帧2294开始记录于09:16:29.926。
- 第1938行：同帧第18个shader编译完成于09:16:31.220。
- 第1940行：CombatWarmup.lua才在09:16:31.224载入。
- 第1942行：构造完成于09:16:31.252。同一引擎帧日志跨度1326ms，已能证明长帧下界，主要区间在构造之前。
- 下一帧2295日志跨度1132ms；SceneWarmup期间帧2057日志跨度955ms。

这不是完整RAF采样或P95/P99，也不能将36.687s总等待当成一次冻结。pc.json中的pageFrames1282和warmFrames99不证明加载全程流畅。

## 必须保留的覆盖

`SceneWarmup.lua`原注释明确：`the full restored frame still warms shadows`。`Rendered()`最后一次调用Restore恢复全部原始viewMask；LoadingFlow同一事件返回，下一次Rendered才建立CombatWarmup并Hide世界。2294的18个新变体恰好发生在这个完整世界帧。

因此不能直接删LoadingFlow中的return，把该帧消失当成优化：现有CombatWarmup主要预热点光/体积光的instanced与single组合，尚未证明完整方向光阴影组合也会全部覆盖。候选分组world-shadow阶段必须在同构建实际Web上确认18个具体shader变体仍在遮罩揭开前完成、最终无新首编长帧，同时验证取消/失败恢复原mask。当前仅是后续候选，没有实施收益结论。
