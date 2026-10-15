# 字体与页面结构专线

## 接续位置

- 2026-10-15 用户要求新增并行字体对照；从现有 G0–G6 账本接续，不重启 G0。
- 冻结 H5：2026-10-14 / 2b169a9964645f5f346a7158bcb14447f040814a。
- 实际对照入口：http://localhost:5173/three/（127.0.0.1 主机名返回 400）；26 张实载 CSS 与冻结源一致。
- 目标基包 manifest-d6764c9c.json，普通 4289 / QA 4290。新改动须进入下一统一包后才能签 Web 结果。
- 范围：工业字体/数字字体/正文/剧情独立字体、字重字号、基线断行与局部布局。原 H5 不修改；不替换美术或新增设计。

## 当前状态

- 已读 CURRENT_EXECUTION、总计划、Lua 指南及三个 NanoVG 示例；使用 Game Playtest 工作流实际页面采样。
- 已采集主页、音乐盒与自然进入试车的 PC/20:9 截图、computedStyle 与字体加载状态；root 另外采集 help/settings/workshop。
- 已检查 SourceFonts / SourceTextLayout / SourceDraw，当前已存在原工业字体和显示字体，不能把所有差异笼统归因于默认字体。
- 第一批已进入 manifest-2729bc84，普通 4293 / QA 4294；第二批 HUD 字体/描边与音乐盒行高已冻结待 root 统一下一包。源浏览器只做功能/字体采样，不作音频或性能量测。

## 已修复

- `scripts/ui/MusicDraw.lua` 不再按 Windows 环境主动选择 Segoe UI。冻结源音乐盒 CSS 首选 `VoxIndustrial`；目标现在复用 `SourceDraw` 的 `vox-body` 原工业字和精确 advance/基线度量，避免同一页面的英文及中英混排静默变成系统字体。
- `MusicBoxVisual` 的 LIVE SIGNAL 宽度改用同一个实际字体，测量与绘制一致；保留 root 刚更新的原图标路径复用。
- 实际 5173 主入口为 `http://localhost:5173/three/`；127.0.0.1 主机名返回 HTTP 400。全部 26 张实际 CSS 归一换行后与冻结源相同，没有切换源基线。
- 已采集主页与音乐盒源图：`evidence/fonts-live5173-home-pc.png`、`evidence/fonts-live5173-music-pc.png`；computedStyle 明确品牌、曲目组、英文副标题和曲目列表均以 `VoxIndustrial` 为首选。
- 修复尚未进入下一统一包；需要包后 PC/20:9 实际入口及目标截图复核，不能套用旧包结果。

## 验收边界

- 驾驶页已按最终 `new-ui-drive.css` 接回底部摘要、I 详情切换、双栏详情、完整键位说明及 3.6 秒进场标题；原左上详情浮窗和整条旧键位条保持隐藏。`TrialSession:Zoom` 在详情打开时滚动，触控 `ZoomPixels` 仍只缩放镜头。
- PC 滚轮由 TrialSession 单一消费，避免 UI fallback 与实际输入循环同时滚动两次。
- 冻结 H5 `_details` 读取未定义 `motion.boostSpeed`，目标保留已有 `thrusterSpeed` 参考值，避免主动引入 NaN；此差异单独记录，不能算成原版字段已完整迁移。
- 源 `reticle.js` 实际隐藏旧速度/条形表、覆盖左列宽 460px；目标同样隐藏重复速度，只保留列内宽度以避免文本跨入右列，此边界修正显式记录。
- 实际后置 `new-ui-reticle.css:24-25` 让快捷键在 10 秒后经 .8 秒 ease 淡出，详情打开后恢复；目标保留该行为与源隐形点击语义。源 `touch-controls.css:144` 在触屏隐藏 PC 快捷键/详情按钮；目标同样隐藏。
- 源自然触屏 840×378、DPR3 的 driveHud 逻辑视口为 1568.627×705.882、scale .5355，目标公式一致，紧凑容器断点不触发（不是按物理屏幕高 378 误触发）。

## 本批验证与证据

- `music-box-pc-sandbox.json`：35/35，完整 PASS，0 Lua/资源/引擎错误。最初 34/35 失败的断言假设了字体注册时机，现改查真实 UI 上下文 `nvgFindFont`；首次失败 report 已另存，未删除。
- `drive-readouts-2026-10-15T08-28-06-167Z/result.json`：88/88 功能断言通过，含实际冻结 JS 执行得到的 72 组摘要，以及限幅、滚轮单消费、多指 owner、真实 TrialSession Zoom 分支与 pinch 分离。0 Lua/资源错误；总结果 FAIL，因为100ms阈值记录224.477ms初始化准备尖峰。未提高阈值，未签性能通过；首次231.593ms结果同样保留。
- `fonts-live5173-driving-natural-pc.png/.json`：通过原 H5 `__vox.drive.enter(__vox.bp,'test')` 自然入口取样；不同于早期的 production component 挂载实验。
- `fonts-live5173-driving-natural-20x9.png/.json`：自然触屏入口，840×378 DPR3；桌面模拟不等于真机。
- 已查看实际源音乐、自然驾驶和目标 native 详情/音乐截图。目标音乐 native 截图弹窗背景透出明显，尚未签视觉一致；需新包检查实际 alpha/最终合成，避免把字体逻辑 PASS 当成页面视觉 PASS。
- root 独立源页面样式矩阵：`evidence/source-font-pages-2026-10-15T08-28-33-064Z/`（help/settings/workshop），computed family 不能单独证明最终 glyph fallback。

## 2729 第一批 Web 与第二批字体修复

- `fonts-2729bc84-readouts/pc.json`：5 项 PASS、0 runtime errors；`20x9-touch.json`：4 项 PASS、0 runtime errors。实际进入试车、I 开关、详情滚轮不缩镜头、关闭恢复缩放、返回清理 HUD。触屏 I 检查使用外接键盘，不能声称源已隐藏的触屏详情按钮存在。
- 音乐盒首次两端超时已保留 `fonts-2729bc84-music/`：测试在加载遮罩退出前点中了入口，未打开弹窗；未归咎音频解码。
- 修复测试等待实际 `sceneVisible && !loadingFlow.active`、PC down/up 70ms，独立重跑 `fonts-2729bc84-music-ready-retry/`：PC 29/29 PASS、0 errors、仅 1 首音频下载；20:9 29/29 PASS、0 errors、仅 2 首音频下载。实际截图显示最终 Web 音乐弹窗不透明正常，先前 native 透出未在真实入口复现。
- 真实对比发现 HUD 中文“就绪”等仍走默认回退、缺源 3px 黑描边。第二批 `SourceDraw` 将 HUD 中英按 run 显式选择 Industrial/Chakra；`ReticleDraw` 使用源最终 Chakra Bold/Medium + Industrial 字体对，剧情 reticle 同样应用；原生无文字描边 API，按引擎 Label 的八方向偏移方法近似 3px 中心描边。默认 1px tracking、HP/EN 3px、状态大字 4px、小字 2px；尺寸随原 reticle scale，宽度计算同步。
- 第二批 `MusicBoxVisual` 修复品牌 9/12.6、曲目组 9/14.4（紧凑 8/12.8）行高与标题纵向位置，来源冻结 music-box.css。
- `reticle-fonts-2026-10-15T08-43-37-154Z/result.json`：10/10 PASS、0 Lua/资源/引擎错误、100ms 阈值无失败；真实 NanoVG 调用验证 CJK/Latin/medium/story 字形路由、八边描边、中心半径、测量 tracking。`reticle-fonts-native.png` 已查看。仍须在下一统一 Web 包与自然驾驶场景看最终构图，不能据此签全部 UI 1:1。

## 11e3 第二批 Web 与仍存差异

- manifest-11e3cbe9.json / QA4296：`fonts-11e3cbe9-readouts` PC 5/5、20:9 4/4 PASS，errors0；`fonts-11e3cbe9-music` PC 29/29、20:9 29/29 PASS，errors0。已查看 PC 实际自然驾驶截图，Industrial 中文、Chakra 数字、源描边/字距生效；音乐盒行高改动已进入同包，弹窗保持不透明。移动为桌面触屏仿真，不等于真机。
- `source-settings-actual-glyph-fonts.json`：Chrome CDP `CSS.getPlatformFontsForNode` 证明原 5173“继续/回到机库/操作说明/让诺诺从头再带一遍”实际字形全是 AlimamaShuHeiTi-Bold（自定义字体），含 CSS weight400 的小字；全部 `font-synthesis:none`，因此不能把原版显粗归因于浏览器伪粗。
- 工业字冻结 10/14 WOFF2 SHA256=fa4a258d17bfe83ebb61774b0730548a5e35de74dc5e9bf7c295a6869ae0847b，与先前导入源相同；当前 OTF=36e1d72ffc8cfd7b800e6bd2272d5ba6f84acaaefc70a57964a60d32f6f7875b，原 CFF/cmap/hmtx/hhea/GPOS 保留，不替换字体资源。
- `font-ink-settings.json` 对已采集 PC 5173/2729 设置页同位置裁片量测：22px“继续”亮部649→489像素、亮部bounds44×20→43×20，目标下移2px；12.5px“回到机库”363→254、49×11→50×11，顶边一致。5倍最近邻裁片已看，字体轮廓一致但小字号着墨/提示差异仍存在。channel coverage spread本采样两端均0，不能断言是LCD次像素造成；CFF raster/hint差异仍未关闭。未全局加粗伪造一致。
- 剩余验收不能由“字体已注册”代替：建造工具/目录与悬浮提示、涂装/工坊详情/车辆管理、竞技与无尽/打捞 HUD、结算、教程对话和开篇分别需要实际入口的文字/断行/动效截图；剧情专属字体由g4内容专线共验。本专线已修页不代表全UI签1:1。

- PC 和 20:9 横屏分别记录；桌面模拟不等于手机真机。
- 冻结源与用户当前 5173 若有不同，分别记录，不私自切换源基线。
- 目标生产字体与实际字形须在统一构建中确认；编译、CSS 采集或逻辑测试不能代替视觉验收。

## 字体专线交接：独立旧版审查让槽

- 2026-10-15 用户新增独立旧版审查，root暂停g1_fonts扩审，槽位交legacy_audit；不删除字体改动，也不重新开始G0。
- 已改尚未进11e3/dbd包：SourceButton暂停标题显式22px行盒，native11/11 PASS、错误0、100ms阈值无失败；首次夹具坐标假设错误FAIL保留。
- 涂装三处按冻结CSS补tracking：LiveryVisual中文标题1px、英文标题2.5px；LiveryWidgets英文分组1.5px。check-reticle-fonts.lua新增实际Render参数断言，尚待音频独占结束后运行；不能写成已验。
- 源建造/涂装文字矩阵49/100项与11e3真实入口截图已采集（CAPTURED、错误0），不代表所有文字视觉一致。贴纸角色缩略图噪点另列资源问题，不用字体改动掩盖。
- InventoryDetail/HomeBay/工坊详情/ModeCard/结算的扩展字体检查未完成；独立旧版审查优先，保留后续任务。
