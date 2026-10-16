# G3 目标特效原生视锥检查

日期：2026-10-16。H5 基线：2026-10-15 / `b276064942ae09c0227ec28d4cfda1d5ff006455`。

## 已执行结果

- 最终证据：`evidence/objective-culling-native-2026-10-16T01-10-45-366Z/`。
- Windows 原生真实 `Camera.frustum`、`BoundingBox`、`CustomGeometry`，16/16 断言通过，失败0，运行错误0，进程退出码0，包装脚本退出码0。
- `stdout.txt` 同时包含 `[ObjectiveCullingNative] started` 和 `completed 16 checks;`；`manifest.json` 显示未超时，检查期间输入哈希未变化。
- 被测 `scripts/render/ObjectiveView.lua` SHA256：`217d83110ea1e0f17dc8ce2caed2a3e43c9a0bf125f30908d5b91070464f8c88`，对应冻结包 f56e5c62 的生产内容。

覆盖：背向时不创建目标几何；转入视野立即提交；离屏停止重建并隐藏旧 drawable；重入及时反映最新占点/反应堆状态；90米光柱顶部可见时不因地面环离屏而消失；移动载荷光环离屏隐藏与重入恢复；缺少相机时保守绘制全部目标。

## 保留失败证据

1. `evidence/objective-culling-native-2026-10-16T01-05-42-701Z/`：报告写 PASS，但断言数0，不能验收。测试在 Validate 首个逻辑帧已过去后注册 `V.atFrame(1)`，未执行回调。工具改用成功原生窄测采用的第2帧，并增加开始/完成日志。原测试实际15个断言，补缺相机保守绘制为第16个。
2. `evidence/objective-culling-native-2026-10-16T01-09-45-863Z/`：真实检查已执行16/16、运行错误0，但包装脚本获取 `Process.ExitCode` 为 null，因此整体拒绝签收。保留为工具失败；未修改报告冒充通过。包装随后在等待前固定进程 Handle，并完成无参 `WaitForExit()` 后读取退出码。

离线工具门禁另通过1个正控、7个负控，以及实际退出码0和7的两个 PowerShell 子进程检查；空断言、缺完成日志、非零退出状态仍会拒绝。

## 复验命令与边界

由 root 分配独占 GPU 窗口后执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/migration/verify-objective-culling-native.ps1 -ExclusiveNativeWindow
```

本次只验原生 API 和几何行为，不代替完整对局画面、墙体遮挡、Web 实际帧时间、移动真机或整体1:1验收。不把测试窗口的帧时间记成游戏提速。
