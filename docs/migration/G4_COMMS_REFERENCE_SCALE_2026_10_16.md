# 剧情与片尾通讯框参考缩放

2026-10-16。当前 H5 实核基线仍为 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`。

用户截图实际来自第五关片尾 Epilogue 的“雇佣合同 / 董事长批准”漫画；不是开篇 IntroPage 的登记终端。代码和截图文字、双格构图均吻合。真正 IntroPage 和 MatchIntro 已有1920×1080参考缩放，本次不改它们。

## 根因与改动

H5 `shared/ui/uiScale.js` 将 storyHud 包入 homeViewport 的1920×1080参考画布；紧凑触屏以600参考高度再乘0.62。原 Lua MissionHud 的通讯卡固定646×196，未使用参考画布。Epilogue 更显式 `min(1,...)`，高分辨率永远不能放大，导致2880宽时通讯框只有约22.4%屏宽。

新增纯布局 `ui/CommsLayout.lua`，MissionHud、Epilogue 使用同一比例。UI已经拥有DPR转换，因此仅计算调用者当前逻辑单位，不重复乘DPR。头像、字体、网点、框线、动画、对白时钟完全沿用生产CommsCard；没有重新设计视觉。

2880×1800的短句卡预期宽646→969物理像素，正文19→28.5物理像素。1920×1080保持源646宽和19字号。20:9横屏拓展两边空间，卡片保持等比，不拉伸。

片尾H5自身fx-epi挂在body且没有被uiScale包裹，因此其固定像素也是旧源行为。本次根据用户明确要求让片尾与剧情通讯共享参考比例；不能描述为该片尾点源原先已自动缩放。

## 验证

`tools/migration/verify-comms-reference-layout.py` 实际导入原H5 homeScale.js计算参考，再执行完整生产MissionHud.Render与Epilogue.Render，使用明确的NanoVG仿射/UI/文本高度适配器。

529项PASS，11组分辨率/DPR/UI密度组合，覆盖1920、2880×1800、4K、20:9、4:3、手机和大平板，196/360高文本及电影条。DPR1/2同物理分辨率得到同最终尺寸；所有测试卡在屏内。恢复旧固定比例的负控在2880×1800明确产生646宽而非969宽。证据 `evidence/comms-reference-layout-offline.json` 绑定源及3份生产Lua哈希。

## 真实Native截图

运行 beta40 Native 的独立UI夹具，实际生产CommsCard、SourceDraw、字体及董事长PNG完成渲染，48帧退出，ExitCode0。请求2880×1800但该Runtime实际窗口限制为**1632×864**，因此截图明确以实际尺寸标注，不能冒称2880真机图。已查看 `evidence/comms-reference-layout-native/native-current.png`：左下卡片、头像、中文对白、页签和底部状态条均实际可见，宽度约517px符合646×0.8；实际正文也按比例渲染。

初次夹具未指定生产UI默认字体，产生NotoSansSC缺失；修正仅夹具UI.Init字体映射后第二次无字体或Lua错误。最终仍有启动阶段默认 `Cube/Day/DaySpecularHDR.dds` 资源错误，不能称整轮零资源错误。原始日志在同证据目录。没有加载地图、车辆或战斗，没有帧率性能结论。

2880×1800原生最终合成、全剧情背景遮挡、手机真实文字可读性仍待统一包验收。没有改TrialSession/GameSettings冻结内容，没有git操作。
