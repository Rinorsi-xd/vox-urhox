# PC 坠舰陨坑后处理迁移（2026-10-06）

项目独立运行时，坠舰陨坑使用 `CraterPostProcess`：原场景 HDR → 太阳光束 + 高光钳制 → 五级 Bloom → 五级 mist 柔焦扩散 → 源 Grade + Three ACES → sRGB → 镜头暗角/色散/颗粒。光束和高光钳制共用一个处理步骤；主场景只绘制一次，后续均为小场景的全屏四边形；NanoVG UI 在最终画面之上绘制。

代码在 `scripts/render/FilterGraph.lua`、`CraterPostProcess.lua`，材质在 `assets/Shaders/BLGL/CraterPost/`。只使用公开的 SurfaceShader、Material 和 RenderSurface API，没有硬编码生成 shader 名，也没有手写底层 GLSL/Technique。地图入口资源清单已包含新增 shader；编译器重跑会保留这些依赖。

## 原网页算法

本机 H5 的 UnrealBloomPass 使用半分辨率亮区提取，阈值 1.3、过渡宽度 0.01，五级核半径为 **6/10/14/18/22**，每级横向/纵向分离高斯卷积，邻接采样合并为双线性采样。合成倍率为 3，五级权重 1/.8/.6/.4/.2，Bloom 半径 .6、强度 .18。mist 是第二套相同滤镜，半径 1、阈值 0、强度 .04；它读取已加入 Bloom 的 HDR 画面。

`bake-crater-bloom.py` 从原文件核列表生成五份 SurfaceShader，并记录源码哈希和系数。初步笔记中的 3/5/7/9/11 不是当前网页的核半径，不能据此实现。

PC 游戏路径现在直接在 shader 中计算 Grade/ACES。曝光修改立即更新 uniform，不需要每次构建 49³ LUT。原 `.cube` 与 `CraterTonemap` 仍用于独立场景/编辑器色彩回退，不能把编辑器中的原生 Zone Bloom 当成运行时完整后处理预览。

## 生命周期与开销

当前 Runtime `20260923-1717-bf3316f` 按反向登记顺序绘制手动排队的离屏纹理。`FilterGraph` 先验证输入只能指向前面的节点，再反向分配整套纹理。窗口尺寸变化或启停滤镜时，重建完整顺序，并释放旧场景和材质，纹理由 RenderTargetLifetime 等待借用表面回收后释放。升级 Runtime 时必须重跑时序测试；这不是所有引擎版本均有保证的通用排序接口。

默认共 29 个视图：1 个场景捕获和 28 个四边形处理/输出。2040×1080 下，本模块拥有的 FP16 颜色纹理合计 **111,609,760 字节，约 106.44 MiB**。不包含引擎的深度、阴影、临时目标和驱动开销；重建期间新旧缓冲会短暂共存。数据见 `evidence/crater-post-allocation.json`。

与 H5 相同，强度 ≤ .001 时关闭对应滤镜。Bloom 和 mist 均关闭时，视图数降至 4，两套金字塔及其缓冲被释放；重新开启会重建，普通强度/曝光/暗角修改只更新参数。启停变化合并到下一次 Update，每帧至多一次分配事务；不会在同一帧每次 slider/set 调用时重新分配整套目标。地图退出释放整套后处理。

此链目前用于 PC 独立运行。已迁移原网页的动态分辨率策略：每 1.5 秒统计一次，低于 50 FPS 降 10%，高于 58.5 FPS 升 5%，范围 70%–100%。高画质基础 DPR 上限 1.5，其余为 1；GUI 仍以窗口原分辨率绘制。与网页相比，额外跳过失焦、最小化和超过 .25 秒的恢复长帧，避免后台限帧误降画质。场景捕获及所有离屏滤镜一起调整，最终输出占满窗口，不改相机操作坐标。设置启停与分辨率变化仍合并为每帧至多一次重建。

2040×1080、DPR 1 下，70% 为 1428×756；拥有的颜色缓冲从 111,609,760 降至 **54,695,360 字节，约 52.16 MiB**，减少约 51%。实际地图缩放/恢复、旧目标释放及全尺寸 UI 检查通过；见 `evidence/crater-adaptive-allocation.json`。固定画面验证锁定原分辨率，避免机器帧速影响参考图。尚未测量独立 GPU pass 时间，不得将缓冲减少或流程通过当作骁龙 845 性能达标。

## 验证

- `verify-filter-graph.ps1`：35/35。通过生产 `FilterGraph` 运行 28 级滤镜，每帧交替 HDR 输入，检查最终值属于同一帧，避免每级延迟一帧；检查值大于 1 的亮度可以穿过捕获链。
- `reference-crater-post.py`：独立 CPU 实现双线性采样、FP16 目标量化和原后处理公式，生成含冷/暖高光及渐变底色的参考。
- `verify-crater-post.ps1`：7/7。比较默认、曝光变化、关闭 mist、关闭 Bloom、奇数尺寸重建及恢复，CPU 参考抽样通道最大误差 **1/255**；清理检查通过。见 `evidence/crater-post-probe.json`。
- 新增实际网页验证：转换服务的 `/three/crater-post-probe.html` 直接调用只读 H5 的 `Pipeline`，不重写其算法。`compare-crater-h5-post.py` 对七组 PNG 全部 RGB 像素比较，最大通道误差均为 **1/255**，平均误差 0.027–0.042/255。完整输入、哈希和比较记录在 `evidence/crater-h5-native-post-comparison.json`。此证据覆盖后处理测试图，仍不能替代整幅地图的材质/阴影验收。
- `verify-crater-parity.ps1 -Label postfx`：233/233，原动画/材质检查和三个正式机位出图通过；零运行期错误。
- `verify-crater-game.ps1`：最新 **58/58**，包含真实地图入口、驾驶与视角输入回放、连续设置合并、启停后处理时移除缓冲、动态分辨率策略与实际缩放/恢复/释放、返回释放与原试车场入口。
- `verify-graphics.ps1`：45/45，原大厅/试车场的 PC 画质界面与设置回归通过。

后续冷缓存复测发现原生 RenderSurface 在父纹理销毁后析构的异常；单纯合并重建或延后 GC 不足以解决。加入借用对象生命周期管理后，两次连续隔离复测通过，详见 `RENDER_TARGET_LIFETIME.md`。该结果不等于编辑器历史崩溃已全部解决。

最新固定机位帧为 `evidence/crater-native-shafts-{fort,ship,interior}.png`，并排图为 `evidence/crater-formal-comparison.png`。**整体仍未完全一致**：材质反射、阴影及朝阳天空输入仍有差异。太阳光束已接入，并修复 Skybox 重复跟随相机导致天空未正确绘制的问题；同机位开关图、天空 alpha/HDR 读回与七组实际 H5 后处理对照见 `CRATER_SUN_SHAFTS.md`。

舰内蓝色光晕差异已用同步亮度复核：原反应堆呼吸系数 .6–1，亮度跨过 Bloom 阈值 1.3。旧 H5 图与原生图的随机相位/时刻不同。新的 `?map=1` 网页探针及 `verify-crater-breath.ps1`（4/4，零运行错误）固定同机位和时间，分别保持原有亮度上下限；实际图 `evidence/crater-breath-comparison.png` 显示两端的灯带扩散基本一致。没有因此改变原动画或降低 Bloom。仍有其余随机粒子、PBR、阴影差异，不能宣称全图像素一致。首次探针在异步加载完成前断言失败；已改为场景就绪后再计时截屏，失败截图已被通过后的结果替换。
