# 涂装背景触摸手势增量

实际Web已完成：最终 `manifest-d966b4f2.json`，公开PC与Android UA 20:9横屏输入专项19项PASS、错误0。证据 `evidence/livery-gestures-manifest-d966b4f2-2026-10-15T16-43-59-243Z`。实际浏览器双contact pinch和平行pan改变相机，取消后单指继续旋转；PC滚轮/拖动、贴纸数据与history不变、完成返回大厅通过。root查看PC与横屏pan截图；不替代完整视觉/真机性能验收。

固定基线仍是 H5 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`。沿用既有 G0-G6，不重开阶段。

## 已确认的缺失

冻结 H5 `shared/controls/touchControls.js` 在 `LiveryStudio._down` 未接管贴纸时进入公共 home 手势：单指按屏幕短边和设置灵敏度旋转；双指用距离比缩放，并将位移一半累加为平移。实际 CameraRig 在一帧汇总后更新，以该帧最终缩放距离计算平移。

迁移版原 `LiveryControls.Down` 只允许一个 drag，第二根手指被忽略；Move 立即变相机，不走源触摸灵敏度与每帧汇总。已先执行冻结实际 JS 生成黄金，再运行旧实际 Lua，保留 `evidence/livery-touch-before.json` 的 FAIL。

## 实现与冻结

唯一生产改动 `scripts/controls/LiveryControls.lua`，SHA256 `4d0114c4a25d7e37f67190383286601784c0940b468199cc41f22bd3972b5847`。

- 背景触摸按 contact 独立持有、保留顺序；双指距离比缩放，阈值与最远/最近距离均沿源。
- 位移统一转 CSS 像素，支持设计坐标缩放与 DPR；单指读取既有触屏灵敏度。
- 同帧位移汇总，平移用本帧最终距离；抬指恢复单指，取消/失焦/最小化清理所有持有状态与积累量。
- 贴纸点选、放置和缩放/旋转手柄优先于相机；外来手指不移动贴纸、不提交贴纸历史。
- PC 左键旋转、Shift 平移及滚轮保留原路径，共用相机位移数学，未改 UI 结构、资源、场景与战斗。

本增量不属于不可变 `manifest-41e4025e.json` 的 Web 证据。完整视觉、真机手感与性能不以本次离线检查签收。

## 离线实际验收

运行 `check-livery-touch.py`：**8195/8195 PASS**。冻结 H5 完整 TouchControls / CameraRig / shared math 与原样提取的 LiveryStudio._down，生成 27 组 675 个事件；逐事件核对实际 Lua 的距离、yaw、pitch、三轴目标点。包括 PC/20:9/16:9 逻辑视口、三种灵敏度、三种初始距离、DPR1/3、UI缩放1/1.8、同帧两指运动、8px阈值、抬指/未知指针。另核贴纸、放置、miss、Space优先级，gizmo，外指与重复释放，取消/失焦/最小化以及PC拖动/Shift/滚轮回归。

边界：实际游戏 Lua 输入模块；命中、节点旋转/Vector、UI和存档 session 为替身。没有 GPU、浏览器或实际画面签收。

## 已备的真实 Web 专项

复用既有测试入口，添加独立 `--gestures`，原完整涂装用例不变：

```powershell
$env:VOX_QA_PORT='<最终QA端口>'
$env:VOX_EXPECT_MANIFEST='manifest-d966b4f2.json'
node tools/migration/check-livery-web.cjs --gestures
```

可用 `VOX_QA_CASE=pc` 或 `20x9` 单独运行。启动前检查包内冻结 LiveryControls SHA，拒绝拿旧41e验证新增功能。

真实输入验收步骤：公开涂装按钮进入；确认未拿/选贴纸；PC真实滚轮双向/左键拖动；20:9 Android UA 经CDP发送双指外扩、平行移动和取消后单指；确认相机 desiredDist/target/yaw 变化、贴纸列表和历史不变；截图及像素标准差检查非空；公开完成按钮回机库。QA只读取已有状态，不修改游戏状态。工具仅语法检查通过，尚未由本agent启动GPU运行；交由root在同一最终包串行执行。

证据：`evidence/livery-touch-offline.json`、`evidence/livery-touch-before.json`。新真实Web结果须独立归档，不覆盖旧包结果。
