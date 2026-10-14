# 零件库质感与键盘操作

## 来源与构建

仍以冻结 H5 分支 `2026-10-13`、提交 `90862445074e7e146da900037979ad97899ecf6c` 为来源。读取 `.tmp/outgame-source-2026-10-12T21-18-23-463Z`，没有读取正在修改的原仓库。样式来自 `shared/css/new-ui-inventory.css` 及原页面最终 computed style。

普通 4206 与 QA 4204 使用 `outgame-cached-1791935864951 / manifest-f555b3bf.json`。目标分支为 `codex/h5-2026-10-13`。素材复用原版，没有新图标、新主题、竖屏页面或光照调整；未上传、提审或发布 Maker。

## 实际补充

| 项目 | 实际行为 |
| --- | --- |
| 背景模糊 | 打开零件库后，原场景视口渲染到临时纹理，水平、垂直两次 Gaussian 模糊恢复源 `blur(4px)`；前景 UI 保持清晰 |
| 卡片入场 | 280ms、每项错开 12ms，第 24 项后不再增加延迟；使用源 `cubic-bezier(.16,1,.3,1)` |
| 悬停与按压 | 180ms 浮起 (-2,-4)、按压 (2,2)；图片 220ms 上移 2px、旋转 -3 度、放大到 1.06；预算标签 150ms 显现 |
| 详情图 | 240ms ease-out 从右侧 7px 进入；仅图片参与动画 |
| 原版样式纠错 | 移除误加的悬停外框，保留键盘卡片焦点框；免费零件标签恢复“免费” |
| 键盘 | Tab/Shift Tab 在搜索、关闭、分类、材质、逻辑目录、参数、快捷栏和说明之间切换；屏幕外零件先滚动并实例化，再获得焦点 |
| 激活与分配 | Enter/Space 激活聚焦控件，聚焦零件按数字分配对应格；Delete/Backspace 只清空聚焦的快捷格；搜索输入不触发选件 |
| 滚动与生命周期 | 回到材质按钮时滚回可见位置；后生成的虚拟卡片继承整页时间，不闪空或重播已结束的入场；关闭时清除焦点并恢复原视口 |
| 图片阴影 | 由原 PNG alpha 离线派生卡片 `2px 6px 3px #091423`、快捷格 `0 2px 3px #09142366`、详情 `0 3px 6px #07111e66`；运行时不读回显卡或逐帧模糊 |
| 控件反馈 | 卡片默认/悬停/按压阴影；关闭 160ms、材质 150ms ease；参数箭头 180ms；快捷格悬停上移 3px、选中上移 5px，180ms 颜色/位移过渡；说明弹层原阴影 |
| 键盘外观 | 保留原分类/参数/说明焦点框；关闭、材质、快捷格使用最终 controls.css 的提亮面和底边，移除误加外围框 |
| PC 真实拖放 | 从零件卡用左键拖入十个快捷格，只高亮一个实际落点；右键不分配，释放分配，取消不分配；其他指针不能移动、完成或取消原拖拽；拖拽后仍可用 Enter 选件 |

背景模糊针对 3D 场景，不是包含任意底层 UI 的通用 CSS backdrop 截屏。Gaussian 采样和 NanoVG 栅格仍与 Chromium 不同，不能称逐像素一致。卡片阴影用三个预计算核交叉渐变；紧凑图片缩放时阴影半径/偏移一起缩放；焦点提亮近似 CSS brightness，图片本体尚未同样提亮。减少动态效果偏好、原卡片快捷编号垂直位置和完整视觉一致性仍待补；此次不是所有 UI 特效完成。

## 资源边界

复用原场景视口，每帧只向这条模糊链提交一次场景；没有另建一份大厅。滤镜只在菜单打开时存在，不创建额外 NanoVG 上下文或字体。颜色目标尺寸按 UI 逻辑像素计算，并限制在 1920x1080；水平模糊使用半宽、半高纹理。

PC 1920x1080 的两张 RGBA16F 颜色目标合计 20,736,000 字节；20:9 网页模拟的 1920x864 目标合计 16,588,800 字节。这个数字不包含引擎深度、阴影、内部池或调整尺寸期间的临时退休资源，不能当作整个游戏的显存预算。原生 10 次开关后待退休目标为 0；不等同于真机长期无泄漏验证。

936 张阴影遮罩（311 个原零件 x 三个角色，加三个公共卡片核）按访问下载，HTTP 检查遍历 preload 传递依赖确认没有加入 boot 或 blocking。图片负载约 6.07 MB，测试搜索状态驻留 40 张原缩略图、43 张遮罩，遮罩解码字节 2,313,796；原缩略图上限仍为 80，独立遮罩上限为可见卡片数 +14、4 MiB。关闭后遮罩缓存归零。生成脚本 `import-inventory-shadows.cjs`，本地来源/哈希报告为 `evidence/inventory-shadow-import.json`。

真实网页拖放曾失败，证据 `evidence/inventory-drag-missing-target.json`：拖到第十格时 dragPoint 仍停在起点。缓存引擎 UI 1.0.47 的 InputAdapter 先发送全局 Input，再调用 UI；Gesture 记录 PointerDown 时 target 为空，后续失去起始卡片。零件库现在注册自己的优先级 100 PointerDown listener，在 Gesture 观察前确定命中控件，并注册 PointerCancel 清除拖拽；关闭时移除两个 listener，没有修改引擎库。实测落点证据为 `inventory-drag-web.json`。

## 验证

| 检查 | 结果与范围 |
| --- | --- |
| 原生库存回归 | 26/26 PASS；含原缩略图/遮罩分开预算及关闭释放；测试窗口错误 0 |
| 原生动效与操作 | 611/611 PASS；对照真实冻结 H5 的 26 张卡片与四阶段 CSS 采样，验证控件/快捷格过渡、键盘、实际 InputAdapter 派发顺序、拖拽取消、右键/其他指针隔离与关闭；错误 0 |
| 原生模糊 | 78/78 PASS；验证当前帧输入、上下方向、边缘软化、黑白不泛白、缩放 1/2、尺寸稳定、开关释放及外部视口切换；错误 0 |
| 普通入口 HTTP | 24/24 PASS；入口、manifest、脚本、shader、遮罩字节与最终工作区一致，936 张遮罩不进入启动依赖，普通 main 不含 QA probe |
| 最终网页三端 | 最终 `manifest-f555b3bf.json` 的 PC 1920x1080、20:9 840x378 DPR3、4:3 1024x768 DPR2 均 PASS，捕获的运行错误 0；PC 含真实鼠标拖放与右键不分配；手机/平板含触屏入口与控件操作 |
| 来源完整性 | 冻结快照的 195 个来源文件、971 个产物、316 个装配定义、695 个模型引用、311 张缩略图、13 首音乐及 27 张贴纸全部 PASS |

上一批 `manifest-eb17202b.json` 的三端回归不包含后续阴影、控件反馈与实际拖放修复。报告分别为 `evidence/outgame-web-{pc,phone-landscape,tablet}.json`；原生报告为 `inventory-effects.json`、`scene-backdrop.json`、`backdrop-pixels.json`，HTTP 报告为 `inventory-preview-http.json`。模糊 shader 未在后续批修改，78/78 为原模糊构建的独立证据。

最终三端零件库与 PC 拖拽/键盘/说明截图已实际查看，前景清晰、背景模糊，未见面板/文字相互覆盖。PC 记录一条被引擎截断的 QA JSON，重新取到完整状态后完成断言；手机和平板 probeIssues 为空。未过滤游戏错误。PC 额外验证悬停、动画后的点击、左键拖放、右键不分配、正反向 Tab、精确屏幕外目录焦点、数字分配、Delete 和 Space；手机与平板验证原触屏入口、参数/说明和关闭。取消与其他指针隔离另由原生实际 Input 派发及手势检查覆盖。此次未开启地图/打捞扩展检查，不冒充这些模块或全部 UI 的最新构建验收。

原版取证脚本 `node tools/migration/measure-inventory-effects.cjs` 只服务冻结快照。提交的 `tools/migration/source-inventory-effects.json` 保存原 CSS 采样及基线，原生检查可独立使用这份夹具。模糊测试 shader 位于 `tools/migration/probes/`，不会进入游戏发布资源。

可复跑 `verify-inventory.ps1`、`verify-inventory-effects.ps1`、`verify-scene-backdrop.ps1`；网页使用 `VOX_QA_CACHED_SOURCES=1`、`VOX_QA_BROWSER_CACHE=1`、`VOX_QA_CASE=pc,phone-landscape,tablet` 后运行 `check-outgame-web.cjs`。

本地四条 aggregate archive HTTP 404 后备加载及原生启动的 DDS/themis DLL 错误仍单独记录。真实手机、M1 持续帧率、发热、内存和冷网络没有验收。整体迁移仍缺云存档、钻头、翼面/新版机甲、完整触屏流程和部分战斗/转场演出，继续按功能清单收尾。
