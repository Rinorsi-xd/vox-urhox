# Match UI parity progress

基线固定为 H5 `2026-10-14 / 2b169a9964645f5f346a7158bcb14447f040814a`，源快照为 `.tmp/outgame-source-2026-10-14T10-09-50-505Z`。本文件只记录匹配入口、排队/阵容、开局名牌和竞技顶部 HUD，不重开 G0。

## 本批完成

- `scripts/ui/MatchLobby.lua`
  - 按最终 CSS 恢复匹配专用冰蓝品牌色、深蓝背景、蓝/红队卡片、玩家 halftone 卡片和 `YOU` 标识。
  - 取消按钮改为源 relief 材质；找到对局闪屏、危险条纹、徽章和地图横幅改为源色值。
  - 阵容卡改用源切角几何，不再使用统一平面卡。
- `scripts/ui/MatchIntro.lua`
  - 对话名牌改为源蓝色渐变底板与左侧队伍色边线。
  - 品牌色改为源 ice-blue；队伍蓝/红和玩家强调色保持语义区分。
- `scripts/ui/MatchTop.lua`
  - 新增冻结 `matchHud.js` 10 月 13 日顶部比分条结构：980x118 细线梯形面罩、蓝/红进度轨、切角头像、血线/死亡斜线、护盾状态、A/C/B 站点环、推车路线和 Chakra 数字。
- `scripts/ui/MatchHud.lua`
  - 替换旧的两块大色比分面板，接入 `MatchTop`；其余局内目标、通讯、横幅、计分板保持既有调用链。
- `tools/migration/import-match-emblem.mjs` 与 `assets/UI/Match/`
  - 重导匹配徽章层；普通态采用源最终 ice-blue，找到对局态额外生成 `emblem-core-found.png`、`emblem-ring-s-found.png` 白色层。
- `tools/migration/capture-match-parity.cjs`
  - 新增真实源入口截图/计算样式采集脚本。

## 证据

- 源页面真实入口（1920x1080、840x378）：`docs/migration/evidence/match-source-2026-10-15T10-30-35-402Z/`。
- 新模块加载级 UrhoX 验证：`docs/migration/evidence/match-ui-load-2026-10-15T10-42-28-501Z/`，3 帧加载/初始化/运行均 PASS，Lua 加载错误 0。运行器仍报告项目既有 `Cube/Day/DaySpecularHDR.dds` 与 `themis_x64.dll` 环境错误，未归因给本批。

## 未签收

- 需要统一包实际进入真实匹配流程后，分别在 1920x1080 与 840x378 截图核对顶部 HUD、排队/找到对局转场和输入命中。
- 需要真实战斗三模式（歼灭/占点/推车）逐项核对源动态状态，不以加载级验证替代功能验收。
- `app/MatchIntro.lua` 的 AUTO REPAIR / FINAL MINUTE 文案由 root 负责，避免跨所有权编辑。
