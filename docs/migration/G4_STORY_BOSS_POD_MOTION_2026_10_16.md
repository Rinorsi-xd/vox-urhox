# S5 狐狸头逃生舱飞行动画

## 恢复的原版行为

固定基线为 H5 `2026-10-15 / b276064942ae09c0227ec28d4cfda1d5ff006455`，`three/src/battle/storyBoss.js` SHA256 `6bc7a822b0eba9112d505ef69bf22be955e7ff6007d9d16824d55db46991b4cb`。

原结局 `BOSS_KIND.update` 在逃生舱飞行时设置 XYZ 欧拉角：`sin(t*5)*.4`、`pi+sin(t*1.7)*.5`、`sin(t*3.3)*.5`，并把尾焰绝对尺寸每帧设为 `3+random()*2.5` 米。原弹出首帧仍保持模型默认旋转和 4 米尾焰。旧迁移版改成朝速度方向转 yaw，尾焰一直为 4 米，丢失了歪斜摇摆和喷焰变化。

仅修改 `scripts/render/BossView.lua`：恢复原 XYZ 顺序的三轴四元数乘积，经项目逻辑坐标 X 镜像映射；保留弹出首帧；按原 3–5.5 米绝对尺寸缩放导出的尾焰子节点；共享 `Glows` 从子节点世界缩放取尺寸，正确叠加父级缩放。运动路径、镜头、对白和小运接替时间不变，没有增加资源或渲染批次。

## CPU 对照与负控

`story-boss-pod-motion-source.mjs` 执行完整冻结 `BOSS_KIND.update`，使用真实 Three.js 的原 `podMesh`、Euler/Quaternion、Sprite 和世界变换。Python/Lupa 执行完整实际 `BossView.New/Update/Glows`；引擎 Node/Quaternion/Material/EffectBatch 用 CPU 数学适配承接。

- 5 个完整序列、1938 帧、**11684 检查 PASS**：弹出、持续飞行、不同随机值/步长、三轴四元数、尾焰世界位置与绝对尺寸、小运出现后不再提交尾焰。
- 18 个共享 glow 控制：原轰炸机和逃生舱，父级缩放和子级缩放组合均与真实 Three.js 世界变换相符，轰炸机原 1.6 倍父缩放保留。
- 真实 6a 旧生产文件 `.tmp/outgame-cached-1792123715225/scripts/render/BossView.lua`，SHA256 `3a7ee634941773c1596c414727edde1989ddb2d82b90baf1a483d385033037a8`，5 序列共 1934 帧存在预期差异。
- 唯一关联 `story-boss-recovery-offline.json` 已实际重跑，90 检查及 6 类负控 PASS，输入记录已更新到本次 BossView SHA。

运行命令：

```powershell
C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe tools/migration/verify-story-boss-pod-motion.py
C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe tools/migration/verify-story-boss-recovery.py
```

证据：`docs/migration/evidence/story-boss-pod-motion-offline.json`。

| 输入 | SHA256 |
| --- | --- |
| `scripts/render/BossView.lua` | `53bcc01922b828cf789055736c95a93c3569bbe66bd379822f02916afecbffd5` |
| `tools/migration/story-boss-pod-motion-source.mjs` | `71714283da3b94974617decd43760b7f5aea89f5b85c5d25b23aadfc29c4947d` |
| `tools/migration/verify-story-boss-pod-motion.py` | `43c0c00ddc73561bb7127eb6134ba669726f4693f6263520692faef166ec1e28` |

## 未签收内容

本轮未启动 GPU、浏览器或构建。CPU 证明姿态和提交尺寸对应源行为，不等于原生实际绘制、自然第五关胜利、完整片尾、可闻音频、视觉 1:1 或流畅性能通过。最终合包和可见验收由主任务串行执行。
