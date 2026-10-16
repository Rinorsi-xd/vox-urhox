# G4 漫画冲击文字窄修 · 2026-10-16

## 基线与范围

冻结原版：`2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`。源文件读取前逐项验证 `docs/migration/outgame-baseline.json` SHA。未更改已批准字幕、标题正文、标题牌主体动画、音频、战斗或其他 Promo 分镜。

本轮修改的是此前遗漏的两个冲击字分支和标题标签字体；不能据此宣称完整开篇、音频或接管战斗已验收。

## 已修复

| 项目 | 原先差异 | 本轮结果 |
|---|---|---|
| `NO!` | 共用 Big 两次普通字绘制，固定像素黑影、无文字描边，垂直位置与源 grid 不同 | 使用原 GameFont 轮廓；34vh、.02em 字距、.12em 白描边；五层 .04/.08/.12/.16/.20em 阴影；整页居中；240ms 原 cubic-bezier 和三段 scale/rotate/opacity |
| `砰——！` | 共用 Big，错误地将源 left/top 当文字中心，缺 .1em 描边和两层 em 阴影 | 原 GameFont 轮廓；13vh；源 left/top 定位，中心变换；200ms 原 cubic-bezier；红填色、黑描边、黑白双层阴影 |
| 文字层级 | 逐字画全部阴影时，后字阴影可能盖住前字 | 整行按最远阴影至最近阴影绘制，再整行绘制前景 |
| `01/02/03` 标签 | 使用派生等宽数字 `vox-tabular`，源 Barlow 是比例数字 | 四处测宽/绘制统一使用原 `vox-display`。1080 高度下 `01` 旧版多宽 5.96376px |
| ASCII `!` | 原轮廓导出集合缺少此字符，不能用全角 `！` 替代 | 现有离线确定性导出器仅扩入真实 ASCII `!`。原字体 advance 为 .196em，全角为 .765em；未添加每帧字体或纹理分配 |

`繁荣！`、`秩序！`、`带薪年假……*` 的正文、原字形和主体字号此前已对齐，本轮不改这些内容。现有小免责声明正文、原工业字体也保留。

## 证据与边界

运行：

```powershell
node tools/migration/source-intro-impact-style.mjs
& 'C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' tools/migration/verify-intro-impact-offline.py
```

`source-intro-impact-style.mjs` 在 Node VM 中执行实际冻结源 `actNo()` 和 `slam()`，收集真实 WAAPI keyframes、时刻、easing、CSS、文本和坐标。适配器仅替代 DOM/音频/计时外部环境。

`verify-intro-impact-offline.py` 实际执行 Lua `IntroComicText.No/Bang` 和 `IntroTitleCard.Draw`，加载真实轮廓 JSON、使用原字体 hmtx 测宽、记录实际变换和字形发射参数。视口为 1920×1080、2400×1080、1440×1080、1333×600，覆盖入场、超调、稳定帧。

结果：**3160 项 CPU 断言通过**；缺描边、固定像素阴影、错误 Bang 中心三个实际变异体被拒绝；旧 tabular 标签与旧 Big 接线静态约束被拒绝。完整证据：`docs/migration/evidence/intro-comic-impact-offline.json`。

这不等于 NanoVG GPU 栅格或自然完整播放验收；没有宣称像素相同、帧率合格或完整开篇通过。主线程负责统一构建和 GPU 检查，g1 负责所有受影响既有检查的实际重跑，不能仅更新旧证据 hash。

## 冻结产物

| 文件 | SHA256 |
|---|---|
| `scripts/ui/IntroComicText.lua` | `0ec88da8c99654b92a5fb514db47db108e32958d641bbfebb7c9436d9c2278e1` |
| `scripts/ui/IntroTitleCard.lua` | `501ea486340204ae13f0a71f755f2c4d0a4f9589fe664c296ffd8906e4221920` |
| `scripts/ui/IntroPromo.lua` | `d348aa2361b7d96ef254831853e91364d8eb59d88d0ee20139805de89bc48249` |
| `assets/Intro/Fonts/TitleGlyphs.json` | `76f181aa0c537883a24d074ce16250a02dc46b62681157602519d4030d51cc1a` |

本次增加/更新工具：`import-intro-title-glyphs.py`、`source-intro-impact-style.mjs`、`verify-intro-impact-offline.py`。派生轮廓 64 字符、303196 字节；导入证据 `docs/migration/evidence/intro-title-glyph-import.json` 已由导出器真实重写。

本轮未提交、未推送、未上传。

## 实际原生栅格窄验证

最终独立夹具证据：`docs/migration/evidence/comic-impact-native-2026-10-16T03-32-42-913Z/`。夹具复制最终冻结产物的六个 Lua 模块、两个轮廓 JSON 和字体，启动入口不导入游戏、场景、音频或着色器预热。

实际引擎断言 **60/60**；Lua 错误 **0**、资源错误 **0**。四个逻辑视口 × `NO!`/`砰——！` 共八张真实 PNG，CPU 像素后检 **8/8 PASS**，`pixels.json` 保留截图与裁剪 SHA。主线程已目视检查前一次同源产物中的两张 PNG。

**总体仍为 FAIL**：引擎记录八次 214.647–318.734ms 截图像素扫描超时尖峰，严格 100ms 门槛保留，不能写成性能通过。扫描发生在 QA `Image:GetPixel` 统计路径，不能据此断言实际漫画播放也有同等开销，也没有放宽阈值或反复运行挑选好结果。四种视口是在同一个物理窗口内拟合的逻辑宽高比，不是真实四种设备分辨率；这不是完整开篇、H5 像素相等或流畅播放验收。
