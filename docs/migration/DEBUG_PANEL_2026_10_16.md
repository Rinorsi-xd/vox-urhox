# H5 Debug 面板恢复记录

## 基线与根因

对照分支 `2026-10-15`、提交 `b276064942ae09c0227ec28d4cfda1d5ff006455`。
冻结 `three/src/debug/debugPanel.js` 的 SHA256 为 `e5aadc381b3710e3c600392abc7d273a82a0757f85ce72eb70601a3239826fbf`。检查工具先与 manifest 比对，然后执行源安装和清记录命令。

原版在本地或 debug URL 参数下安装屏幕 Debug 按钮与 F8。迁移版原先只有 QA probe 和 F1–F5，没有用户 Debug 面板，不能解释成单纯隐藏。本批恢复真实可操作入口，但不代表 H5 Debug 全部迁完。

## 本批交付

| 范围 | 已接通入口 |
| --- | --- |
| 生命周期 | main 在 App.Start 后安装，Update 先处理 Debug 输入，Stop 显式注销渲染、overlay、指针与 widget |
| 面板 | 70×44 按钮、F8、PC 右上/横屏触摸左侧、330px 面板、滚动、6px 拖动阈值、归一化位置保存、pointerup 后 click 去重 |
| 开场教学 | 从头/签约/闸门、教学开始/结束/清记录、全部真实 Tutorial.json 步骤跳转 |
| 剧情 | 跳步、目标传送、完成当前步、跳通讯、击杀敌人、自爆、任务完成、真实结算、运输车/坚守护盾操作 |
| 驾驶地图 | 地图传送、无敌、补血恢复零件、自爆、退出、结构清空/10% 受伤 |
| 对战 | 歼灭回合胜负平、推车半场终点/超时、整局胜负平、直接结算、结束 MVP；真正 Dispose MVP，不是只跳一个镜头 |
| 主页打捞 | 剧情/对战/地图/编辑/大厅入口，已有库存每种+20、信用点+10000、清库存、出发 |
| 存档 | 真实命名空间 intro-profile/story-progress/stash 删除墓碑；打捞清记录刷新生效，当前内存库存保留，与 H5 一致 |

所有可见按钮接真实模块/宿主接口，不放空按钮。剧情结算按源时间/死亡/失败计算 S/A/B，并保留运输车/护盾上限。操作不适用或存储失败会显示错误并重新打开面板。

## 边界与未迁移项

- Native 参数建议 `-vox-debug`、`-vox-debug=1` 或 `-dev`；本地 Web preview 自动补 `-vox-debug=1`。不是全部发布默认开启。Lua 保留旧 `-debug` 别名，但 Web 不应传该引擎保留参数，见下文复测。
- QA 的 F8 继续归 snapshot probe 使用；可点屏幕 Debug，不替换 QA 快捷键。
- 面板打开时宿主暂停 gameplay update。H5 主要释放 pointer lock，这一暂停策略不声明逐帧等价。
- 开场重播走现有清理/重启宿主，不是 H5 整页刷新。
- 位置写现有本地键 debug-position，不承诺该键云同步。
- **尚未迁移**：H5 testPages/testPreview 页内测试、加载页预览、完整 HUD checks（击杀/拆武器/受击方向/锁定/导弹/狙击）、HUD 音效 A/B、combat tuning 滑块/重置、URL fastmatch/autopilot/nointro/novo 开关、无尽专用 F9 面板整合。未显示不能工作的占位按钮。
- 文字颜色调用 SourceDraw 既有源字体；原版切角、阴影、hover 的 GPU 观感尚未验收。

## 验证

`tools/migration/check-debug-panel.py`：**231 项、33 个实际冻结源场景通过**。新增实际最终 HangarApp 参数循环验证：无参数默认关、独有参数开、显式 `-vox-debug=0` 关、`-dev` 开。
实际执行 H5 installDebug/清记录与 storyMission._result，对照 Lua DebugActions、TutorialRules/MissionRules、widget 输入/布局/释放、真实 main 生命周期。
覆盖 1920×1080、2560×1080、1280×576、1024×768、800×360 边界，启动无 trial、实际教学数据、Web/桌面滚轮单位、QA F8 不消费、拖动和 click 去重。

引擎/绘制/存储/场景宿主使用 CPU adapter。**不以此认定浏览器真实按钮、Native 输入、GPU 字体/遮挡、性能通过**；统一构建后的浏览器验收由主线执行。
证据 `docs/migration/evidence/debug-panel-offline.json` 含源/生产/工具/资源 SHA256。本批无提交/上传。

## Web 启动参数冲突复测

主线浏览器实测发现，把通用 `-debug=1` 默认传入 WASM 会在引擎 bootstrap 阶段报 `memory access out of bounds`，此时用户 Lua 尚未载入；重复两轮且 `-debug=0` 也复现。换成应用专用 `-vox-debug=1` 后，同一旧生产包 manifest-bccb4d66 已启动超过 10 秒。这是主线的串行 GPU 观察，不由本报告的 CPU 检查代替。

子任务只读核对了两轮旧包证据：

- `docs/migration/evidence/lobby-loading-manifest-bccb4d66-2026-10-16T08-24-27-697Z/result.json`
- `docs/migration/evidence/lobby-loading-manifest-bccb4d66-2026-10-16T08-24-49-411Z/result.json`

最终 preview 自动参数和 HangarApp 参数识别均由主线改成/加入专用名称；保留原始查询串，避免重编码 game_url。该子任务未运行浏览器/GPU，也不把旧包“启动超过 10 秒”扩大成新包游戏流程已通过。最终新包的真实 Debug 点击及完整进入局内另行验收。

最终 Host 关联 14 份 CPU 报告已实际逐项重新执行且通过，随后 freshness 为 FRESH/0 drift；没有手刷生产 hash。
