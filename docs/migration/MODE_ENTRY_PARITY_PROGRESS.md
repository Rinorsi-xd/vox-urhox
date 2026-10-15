# 模式入口增量对照

本批继续 CURRENT_EXECUTION.md 的既有工作，不重开 G0。

基线：2026-10-14 / 2b169a9964645f5f346a7158bcb14447f040814a，连同 outgame-baseline.json 指向的冻结工作区内容。

## 已实施

- HomeBattle 的模式标签恢复最终 brand-hi #dbeeff。
- ModeAction 开始按钮正文 #f3f9ff、键帽 #dbeeff、换车文字 #dbeeff 与原字距。
- 剧情入口保留其专属 #46c8ff、#04121f、#f4f5f7、#9aa0aa，不套用全局浅青色。
- 剧情入口采用原 VoxNum + VoxTitle 混排，章节角标按原文字宽度及字距计算；补原 22px 全息网格及边框。
- 开场介绍规则文案恢复 AUTO REPAIR / 自动维修、FINAL MINUTE。
- HangarApp 当前玩家与 OpeningHost 演出装配的武器图标及 Hurt 图标加入真实下载门禁。

源证据：shared/css/style.css、story.css、new-ui-home-pages.css；shared/ui/matchIntro.js。
实际源 PC / 20:9 截图：evidence/match-source-2026-10-15T10-30-35-402Z。

## 验收边界

离线图标资源检查 10/10 PASS；派生竞技/语音检查 701/701 PASS。图标专项 native 43/43 功能 PASS，但三次超过 100ms，整体性能 FAIL，且无 viewport，不作视觉证据。

当前浏览器 manifest-e1faa514 不含本批修改。需统一新包后实际点击模式入口、匹配、局内设置并查看 PC / 20:9 截图。全息内发光与字体着墨尚未签像素一致，不能据代码检查宣布 1:1 完成。
