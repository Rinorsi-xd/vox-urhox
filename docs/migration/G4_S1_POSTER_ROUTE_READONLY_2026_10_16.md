# 首关 poster 卡住：只读定位

本次只读调查，不改生产、工具、物理或任务数据，没有启动 GPU、浏览器或构建。对照冻结 H5 `2026-10-15` / `b276064942ae09c0227ec28d4cfda1d5ff006455`。原失败证据为 `evidence/story-natural-s1-manifest-5b8cf21c-2026-10-16T01-18-07-151Z/result.json`，保留 FAIL / Aborted(OOM)。

## 实际确认

使用 Node 直接 import 冻结源 `shared/battle/outpost.js` 并调用实际 `buildOutpostLayout()`，与目标 `assets/Crater/Layout.json` 和 dataParts 逐项比较：

- 103041 个物理地形高度逐值完全相同。
- 导航仅两个数值有约 1e-16 序列化浮差，分别为 `rS0.y`、`gN0.y`。首关路线中的 `hiS0/hiS1/h1/h2/hBr` 完全相同。
- 1910 个 blocks 描述仅六个数值有约 1e-16 浮差，其他字段相同。这是数据等价证据，不等于 Bullet/Rapier 的实际碰撞响应等价。
- 实际 import 冻结 `shared/story/level1.js`：出生、poster 情报 `[198,20,0]`、九个任务的 id/kind/位置/半径与迁移 JSON 一致。
- 源 `storyMission.js:124` 的 near 与目标 `MissionRules.lua:46` 都以水平 `r + max(0,w-2)` 及车体 below/above + up 检测；拾取均 r=6、up=6，没有发现 poster 任务触发半径或坐标改错。

## 失败轨迹

5b8cf 自动路线在 30.344 秒上南坡，38.463 秒消耗 hiS1，44.401 秒进入 h1→h2。高地已被实际驶上，不能说整条上坡碰撞不可用。

| 时间 | 玩家逻辑位置 | 转向误差 | 工具新发命令 |
| --- | --- | --- | --- |
| 49.521 秒 | `[204.64,19.02,-53.32]` | 0.556 rad | `Space` |
| 49.822 秒 | `[201.33,18.92,-47.62]` | 0.716 rad | `Space` |
| 50.191 秒 | `[199.81,18.84,-44.07]` | 0.844 rad | `Space` |
| 50.488 秒 | `[197.94,18.51,-39.66]` | 1.035 rad | `Space` |
| 51.866 秒 | `[185.32,4.03,-34.18]` | 1.600 rad | `w+a` |

`check-story-natural-web.cjs` 已计算 `turning`，但当 speed>desired 时，三元分支把命令替换成仅 `['Space']`，遗漏转向键。上述连续样本在需要校正方向时仍只制动，车辆向崖边滑出。原地形在 `[201.33,-47.62]` 高度约 20，到 `[195.02,-37.44]` 为约 14.22，再到最终位置约 4.49，方向和下坠轨迹吻合；冻结源连续高度也同样下降，不能据此认定迁移地形漏碰撞。

随后位置长时间停在约 `[184.916,4.513,-34.817]`，仍追逐高层 `h2=[205,20.0598,-20]`；与路段高度差约 -15.56 米，contact 多数为 0。410.9 秒样本后发生 OOM。测试没有接近 poster 的实际拾取区域，所以这次没有验证或否定真实 poster 拾取功能。

## 一个最小候选

仅修改自动测试驾驶工具：减速时保留已计算的转向键，例如 `['Space', turning]`；不改生产物理、任务范围、原始路点、自动验收条件或时限，不使用传送或强行跳过任务。先用上述原记录重放验证“偏角存在时制动命令仍包含转向”，再由 root 同包自然驾驶确认是否能留在高地上并实际拾取。离线命令修正不保证车辆结果，仍可能存在其他驾驶/碰撞问题。

OOM 归因仍开放：本轮 JSON 84,467,804 字节、runtime.log 60,562,174 字节；1233 个样本重复携带各 180 帧 presentation 观测环，构成明显测试侧负担，但这不足以解释 WASM 堆中的具体分配失败，不把它当作已证实 OOM 根因。

## 后续获准的工具修正（无生产修改）

root 随后授权仅修测试驾驶工具，现已将按键选择提取为 `navigationCommand`，减速与敌人近距制动都保留转向；倒车仍反转转向符号，速度仍按绝对值判断。现有任务成功条件、时限、6/8 米严格路点门限、键鼠实际输入方式和原失败证据未改。

实际执行 `node tools/migration/check-story-route-controls.cjs`：23 组边界场景、四条真实跌崖前记录的反事实按键，共 35 项检查通过；7 组负控全部拒绝，覆盖丢弃制动转向、倒车符号/速度、速度等值、敌人 25 米等值、偏角 0.12 等值与接近限速。报告为 `evidence/story-route-controls-offline.json`。实际复跑原 `check-story-navigation.cjs`，59 项和 5 组负控仍通过；旧导航报告另存 `evidence/history/boss-before-recovery-2026-10-16/story-navigation-before-brake-steering.json`。

冻结工具 SHA256：`check-story-natural-web.cjs` = `1ad696ac690f6896cd1b98e52583909fb2a443f9555706d35ec352801bf5b05b`；新 CPU 检查 = `b560b0b69fccb8b49c1672439dd94ee09a7f2ad5ba670c83ff537dc3d00fe746`。旧 5b8cf OOM 报告 SHA256 仍为 `04454da17b34e3450c7b6e131c47fddd876e0062d10c4d2a630c451bc97428aa`，检查脚本读前读后核对一致。

自然验证运行方式仍是 `VOX_QA_BASE` + `VOX_EXPECT_MANIFEST` + `VOX_STORY_LEVEL=1` + `VOX_STORY_LOG_ONLY=1` 后运行 `node tools/migration/check-story-natural-web.cjs`；原默认 360 秒不变。root 若使用非当前生产快照，通过既有 `VOX_STORY_REFERENCE` 指定快照 scripts 路径。只有实际拾取、安装、三次击杀、日志出现并拾取才可能通过；离线报告没有关闭玩法、物理或 OOM。
