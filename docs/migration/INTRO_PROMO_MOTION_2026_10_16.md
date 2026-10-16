# 开场宣言揭示与打捞退场

## 基线与范围

- 原版冻结分支 `2026-10-15`，提交 `b276064942ae09c0227ec28d4cfda1d5ff006455`，来自 `outgame-baseline.json` 指定的原始快照。
- `three/src/intro/intro.js` SHA256：`8674acaea7cfa5df986a233010a11b7c8f9cf3e9a64acd32a4d21b6ed314877f`。
- `three/src/intro/introStory.js` SHA256：`9c3694eab1fbb74a08ff44541b0a24b7e22735e28c4f5e88b01801222e8408ff`。
- 只改 `scripts/ui/IntroPromo.lua`，新增独立时钟模块 `scripts/ui/IntroPromoMotion.lua`；复用 g2 的 `ui.IntroOpacity` 合成整体淡出。保留现有画面位置、字号、字体、图像及底部字幕。
- 此增量不属于 `manifest-5f39f096.json`，不能套用该包的 Web 结果。

## 已补

1. 宣言卡片内容 400ms 淡入，使用原 `_in` 的 `cubic-bezier(.16,1,.3,1)`。
2. 两句宣言各 900ms，从左往右裁剪揭示，使用原 `cubic-bezier(.6,0,.3,1)`。
3. 第二句在 `IntroAudio:Duration('vo_n16') * .48` 后开始；时长为零时回退 8 秒。无音频对象的编辑预览用导入时长。
4. 免责声明阶段沿用日志中的 `motto` 起点，不因该阶段的 age 清零而重播动画。卡片脚注随卡片存在，保留原文字样式。
5. 打捞立绘入场保留 280ms，改为原 `_in` 贝塞尔曲线；切到招募后继续 200ms 退场，使用原 `_out` 的 `ease-in`，位移终点为 `+45vw,+20vh`。
6. 退场立绘仍绘在招募大字下方；跳过到 `tvcut` 不残留立绘。
7. Promo 的局部透明度使用 `IntroOpacity.Set`，宣言整组使用 `Push/Pop`，图片内部重设透明度也保留整体淡出乘子。

## 验证

- `tools/migration/source-intro-promo-motion.mjs` 校验冻结源 SHA，实际执行原宣言、打捞动画片段以及 `_in/_out`，采集原动画帧、时长、曲线与第二句启动时刻。
- `tools/migration/verify-intro-promo-motion.py`：**5942 项 / 316 个实际 Promo.Draw 场景 PASS**。Lua 5.4 下执行真实 Promo、Motion、Opacity，原生绘图、文字、图片及非目标演出层使用适配器。
- 覆盖 1920×1080、2400×1080、1440×1080；实际音频时长 8.87 秒、4 秒及零时长回退；关键边界前后、免责声明连续性、透明度嵌套、画布状态恢复、原文字位置/字号/字体、退场层级。
- 与独立高精度贝塞尔参考比较，坐标误差门槛为 0.001 个逻辑像素，覆盖 Lua 22 次二分求根的浮点误差；这不是像素截图相似度。
- `tools/migration/verify-intro-promo-offline.py`：**874 项 / 153 场景 PASS**，保留 8581 包 `global s=nil` 历史失败复现，覆盖真实 Promo 调用驾驶 UI、特效、Film 和字幕分支。
- 证据：`evidence/intro-promo-motion-offline.json`、`evidence/intro-promo-offline.json`，均包含当前生产文件 SHA。

## 尚未验收

没有启动 GPU、构建、上传或提交。本批尚未进入统一 Web 包，需主线程统一打包后观察真实完整播放；本报告不签画面全面 1:1、自然输入、音频连续性、真机性能或 G4 全部完成。
