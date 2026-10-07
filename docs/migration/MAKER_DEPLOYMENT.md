# Maker 测试部署与基础横屏触控

日期：2026-10-07。工程：`D:/Rino_Project/maker/Vox/VoxelCraft`。
新建 Maker 项目：**方块战车**，ID `e2eadc8c-5177-4e03-8c08-d254c229816b`。
本次目标为 Maker 测试构建，不提交公开审核。原 H5 工程不改动。

## 输入与布局

- Android、iOS、HarmonyOS 与引擎触摸模拟使用触控布局；本地验收可用 `-touch`。PC 保留键鼠行为，不根据 DPR 猜测手机。
- 发布方向固定 landscape。NanoVG 继续由现有 UI 系统绘制，设计分辨率缩放同时作用于绘制和命中测试。
- 驾驶：左摇杆前进/倒车/转向；拖动画面看向；按住开火、刹车，适用车辆可升降；点按武器切换、瞄准、翻正、传送及相机远近。
- 多指分开拥有摇杆、视角和开火；松手、触控取消、失焦、离场均清理输入。
- 改装：点按放置/删除/涂装，拖动绕车；零件库、旋转、翻转、缩放均有触控入口。手机不恢复 PC 第一人称相机。
- 大厅参数滚动显示，工坊隐藏底部出战组以防遮挡；沿用已有界面设计和游戏资源。

## 验证记录

- `tools/migration/check-mobile-controls.lua`：原生引擎、1280×720 裁切视口，真实 UI 指针分发与多指输入，50/50 通过；零 Lua、资源、引擎运行错误。
- `tools/migration/verify-drive-hud.ps1`：PC 驾驶回归 127/127 通过；零运行错误。
- 已目视检查大厅、工坊、改装、零件库、驾驶截图，证据位于本地 `docs/migration/evidence/mobile-*.png`。
- 这些是 Windows Runtime 的触控注入与渲染验证，不证明 Android/iOS 实机帧率、温度或 WebGL shader 效果。移动设备浏览器须由宿主提供触摸平台标识/触摸模拟；高 DPI 不自动切为移动模式。

## 包与后续构建

发布源使用 `scripts/` 与 `assets/`。SDK 参考目录、`.cli`、本机存档、测试截图和生成的大型源端夹具不进入 Git。保留既有 DX11 shader 缓存以支持 PC 包；移动端/Web shader 仍须由目标引擎编译。
首次上传包含现有陨坑等地图资源，当前资源总量约 350 MiB，尚未验证弱网下的按需下载。基础移动适配不等于完成资源瘦身。
通过 Maker MCP 的 `maker_build_current_directory` 统一提交、推送和构建；不要另行用 PR 或通用 push 代替该流程。
