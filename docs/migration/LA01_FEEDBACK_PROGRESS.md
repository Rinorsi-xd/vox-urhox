# LA01 玩家部件反馈接续

## 当前状态

2026-10-15：恢复零件青色光壳/弹动、武器槽丢失闪烁与图标滤镜已冻结。最新专项 44/44 功能断言通过，Lua/资源错误为 0，三张实际截图已检查；初始化有两条超 100ms 尖峰，整体性能仍 FAIL。尚未签同包 Web 与真机验收；未提交、上传或升级引擎。共享 TrialSession/PlayerViewSync/HangarApp 的调用与下载依赖由 root 接入。

## 基线与审查纠正

源分支 `2026-10-14`，commit `2b169a9964645f5f346a7158bcb14447f040814a`，快照 `.tmp/outgame-source-2026-10-14T10-09-50-505Z`。

- `three/src/drive/testDrive.js:902–965`：先消费玩家恢复事件，批量重建最终视图后给每个仍存在的恢复件 `paintFlash(part,0x3fe6ff)`。
- **审查中“缺少武器/移动丢失文字提示”的判断有误**：`testDrive.js:936` 虽调用 `feedback.partLost(...)`，但 `shared/ui/combatFeedback.js:184–187` 明确废弃旧提示条，`partLost() {}` 为空。不能把历史注释误当当前界面或补旧文字。
- 实际武器反馈位于 `shared/ui/reticle.js:158–159,440–499`：火力/数量下降后1.4秒琥珀色，`.35s steps(2)`闪4次，原武器图标走`sepia(1) saturate(5) hue-rotate(-14deg) brightness(1.1)`。恢复后1.2秒青边与4px发光。当前`ReticleState`已有输出检测，保持原逻辑；只补`ReticleWeapons`缺失的表现。
- 原版没有移动零件损失专用文字或速度条闪烁；`reticle.js:389–394`只更新实际速度、占极速比例及超过极速102%的boost颜色，不能发明掉轮提示。
- `three/src/build/vehicleView.js:39–72,946–985,1136–1163,1317–1353`：原几何加色光壳，青色`#3fe6ff`，`.34s`、放大14%的三次ease-out、`1.1*(1-t)^1.5`褪色；非joined部件`.2s`正弦弹7%，joined精确形状仅光壳；光壳是创建时snapshot，不逐帧追炮塔。排除beamCyan/beamOrange/beamPaint/holoPaint。

## 接入契约

`render.RestoreFlash.New(scene)`，在玩家最终视图同步后、CombatView清空共享events前调用 `Consume(player,session.view.view,world.viewEvents)`；所有rig更新后渲染帧调用 `Update(dt)`。相机最终隐藏车体后须 `NodeVisibility.Set(fx.root,view.root.enabled,true)`，子节点同样隐藏。`Clear()`取消临时光壳并恢复仍有效的pop scale；`Dispose()`须先于view/world销毁。源暂停没有清paintFlash，因此不擅自在Pause中取消自然动画。

依赖：`Shaders/BLGL/RestoreFlash.shader`先经过现有地图ResourceGate；`UI/WeaponIcons/Hurt/*.png`共16张与原图标同步预热。图标不是重画素材，是用离线Chromium Canvas逐张执行原版CSS滤镜，生成脚本 `tools/migration/import-restore-feedback.cjs`；原版关键帧实测及输入/输出哈希在 `source-restore-feedback.json`。

## 验证与未关闭项

专项 `verify-restore-feedback.ps1` 已运行：真实CarUnit/车辆装配/Bullet失件和恢复批次、独立最终视图重绑、青壳与pop分段、joined精确形状、scope隐藏、取消/重复Dispose、原浏览器CSS关键帧取样和实际截图。

- 最新证据：`evidence/restore-feedback-2026-10-15T10-19-05-064Z/`。44/44 功能断言 PASS，Lua/资源错误为 0；frame2 为 261.779ms、frame3 为 970.869ms，超过原 100ms 阈值，运行总结果 FAIL，未放宽阈值。
- 已打开检查 `restored-parts-hurt-bright.png`、`weapon-lost-hurt-dim.png`、`restored-weapon-fix-and-joined-shell.png`：恢复壳与实际模型对齐、琥珀滤镜明暗切换、失件后无残留壳、修复槽青光、joined 精确形状均可见。原生实际截图为 1740×921，不冒充 16:9 或 20:9 实测。
- 保留失败样本 `evidence/restore-feedback-2026-10-15T10-16-20-164Z/` 与 `evidence/restore-feedback-2026-10-15T10-18-30-854Z/`。先前 41/41 断言仍漏掉了壳的实际比例错误；截图发现光壳过大偏移，日志证明 `node.transform = matrix` 未应用缩放。已改显式 `SetTransform(...)`，新增实际根缩放与零件原点对齐断言后再获得上述 44/44；不能拿先前样本签视觉通过。
- 修复槽的 CSS 4px 模糊由多层青色描边近似，尚非像素级 1:1 签收；保留此差异，不称完全一致。
- 此专项是实际生产模块的独立原生夹具，不替代共享调用链、真实同包 Web 操作、自然战斗恢复或真机持续性能。后四项仍 OPEN，由统一构建继续验收；原生进程已退出，临时入口已清除。
