# G1 PC 驾驶视角假位移过滤

## 接续与基线

- 接续 `CURRENT_EXECUTION.md`、G1 相机账本与 G2 详情页账本；没有重新开始 G0。
- 原 H5：`2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`，读取 `outgame-baseline.json` 的冻结源。
- 实施前目标为已同步私有 `main` 的 `d6fcf0de`；没有提交 Git、修改原 H5 或引擎库。
- 独占生产范围：`controls/DrivePointer.lua`、新 `controls/MouseDeltaFilter.lua`。未修改 TrialSession、VehicleView、Crater、main、Body、Vehicle 或 Space。

## 已确认差异

冻结 `shared/controls/cameraRig.js` 的 `Input` 在鼠标锁定时对每个 `mousemove` 调 `_spike`，先排除单个伪大位移再累计当帧输入。阈值为长度大于 120px、且大于近期均值的 8 倍加 80px，并且前一个事件不是尖峰；连续快速甩动第二个事件起正常接收。只有正常事件更新均值，权重为 0.3，空帧不改变均值；锁定变化清空这段历史。

旧 `DrivePointer` 直接把整帧 `input.mouseMoveX/Y` 交给驾驶相机，没有这条过滤。源已经修复的偶发视角猛跳仍可能在迁移版出现。不能简单过滤帧总量：同一帧多个正常鼠标事件的总和可能很大，按帧丢弃会吞掉真实转头。

## 修复

- 使用现有私有 `LuaScriptObject` receiver 订阅 `MouseMove`。`DX/DY` 字段已核 `.emmylua/Events.d.lua` 的 `MouseMoveEventData`，没有猜测 API。
- `MouseDeltaFilter` 逐事件执行冻结源公式并累计；Poll 每帧只消费一次。只要本帧收到过事件，即使全部被过滤，也不会从未过滤的 raw 总量重新绕回。
- 若适配器完全没有发事件，保留 raw 总量回退并应用同一公式；此回退只有帧级信息，不冒称逐事件桥接已验证。没有 raw 变化的空帧不更新均值。
- 捕获、真实锁定完成、抑制、释放均清空过滤历史和待消费输入；未捕获/未就绪/对话中/失焦/锁定失效的事件不进队列。对话暂停仍由现有 host 的 Pause/Release 负责，没有新增对话流程。
- 右键事件、射击、滚轮、Sample-only 回放、触屏输入的原接口保持。触屏不创建 PC receiver。
- 没有改物理频率、车辆内容、镜头灵敏度、相机反馈、FOV 或帧率阈值。

## 离线验证

`source-mouse-delta-golden.cjs` 执行冻结源的真实 `Input` 构造器、document mousemove 与 pointerlockchange 回调，检查源 SHA，再生成事件黄金；没有重写预期过滤算法。

`verify-mouse-delta-offline.py` 通过 Lua 5.4 执行实际生产事件注册、Move、Poll 与过滤模块。

- 32 场景、2905 帧，**8757/8757 PASS**。
- 包含同帧多个小事件、单个假位移、连续真实快速甩动、负向/竖向、120px 边界、空帧、锁定重置、无事件回退、单次消费、对话阻止新事件、host 暂停释放、抑制/失焦/解锁、触屏与 receiver 所有权。
- 原右键/Chase/FOV 黄金以当前 10/15 源重新生成；`check-vehicle-checkpoints.py --scope-input` **5030/5030 PASS**，证据 `evidence/scope-input-2026-10-15T14-48-49-492698Z/report.json`。
- 本批事件证据：`evidence/mouse-delta-offline.json`；`node --check` 与 scoped `git diff --check` 退出 0。
- 首次夹具遗漏重新锁定前的真实 unlock 状态；第二次错误假设 Poll 自己打开对话暂停。已按现有 host 生命周期修正夹具后完整重跑，没有为夹具改生产暂停行为。

生产 SHA256：

- `DrivePointer.lua`：`c55c7fb419b74f00691ea548c7540060aaafb27708e07629cf11463ea5e28407`
- `MouseDeltaFilter.lua`：`5f22bea672b44887641a2a1a4be4239c1d7c334e7976e06b5e8c39acc4ce788a`

运行：

```powershell
node tools/migration/source-scope-input.cjs
node tools/migration/source-chase-camera.mjs
& 'C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' tools/migration/verify-mouse-delta-offline.py
& 'C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' tools/migration/check-vehicle-checkpoints.py --scope-input
```

## 实际同包待验

整理复核说明：下述“释放后不再接收”仅指不再接受输入入队，不证明底层回调绝未被调用。离线精选证据已收入 `verification/2026-10-15/mouse-delta-offline.json`；工具依赖的冻结H5源和本机Lupa仍需另行准备。

另备 `verify-mouse-delta-native.ps1` / `check-mouse-delta-native.lua`：使用实际 Node、LuaScriptObject、VariantMap 与 SendEvent 注入源黄金事件，并经生产 Poll 核对送达、逐事件历史、单次消费和释放后不再接收。保留真实 input；实际 OS 移动污染会使夹具失败。必须由 root 分配独占 native 窗口后传 `-ExclusiveNativeWindow` 才能运行。本批仅通过静态语法检查，**没有启动或运行该原生夹具**；即使后续通过，也仅签“注入事件的原生桥接”，不能签真实鼠标、Web 锁定、镜头像素或性能。

本批没有启动 native 或浏览器，GPU 留给当前性能专线。离线 receiver 为 stub，不能证明实际 runtime 的 MouseMove 送达、Web/native DPI、原生锁鼠标与可见镜头结果。

1. 公开入口进入驾驶，在 PC 锁鼠标下持续小幅转动、快速甩动和跨屏幕边界，检查不吞正常连贯转头、不出现孤立猛跳。
2. 同包重复右键短按/长按、开火、滚轮、Esc 退出再接管，以及弹窗/失焦恢复；保持前批实际验收行为。
3. 检查 MouseMove 实际回调与 Poll 聚合值，确认没有 raw 双消费；若 runtime 缺少该事件，只能签帧回退，不能签源逐事件一致。
4. 横屏触屏检查视角与射击未受影响。桌面模拟不等于真机，性能和整体 G1 手感仍未关闭。
