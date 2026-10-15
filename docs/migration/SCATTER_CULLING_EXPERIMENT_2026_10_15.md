# 静态散布分组剔除实验工具

## 状态

工具已写完，**尚未启动 native/GPU/Web**，由 root 在分支合并结束后统一串行运行。本轮没有修改任何生产脚本、资源、metadata 或小地图烘焙输入。

实际 XML + Lua 5.4 stub 一致性检查 **11215/11215 PASS**：`mesh-293.bin` 4160 个实例、36 原组；按源组分别细分得到 32 米 345 组、64 米 100 组。检查负坐标/格边界、实例身份和全部 12 个仿射矩阵分量、注册覆盖、模型/逐槽材质引用、原 drawable 参数、显式切换、恢复和清理；故意变换/减少距离/换实例会拒绝。报告 `evidence/scatter-culling-offline.json`。这些不是渲染、距离语义或性能结果。

## 运行

```powershell
& 'C:/Users/XD/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' tools/migration/scatter-culling-check.py
powershell -ExecutionPolicy Bypass -File tools/migration/scatter-culling.ps1
```

可调 `-SampleFrames 120 -SettleFrames 60 -TimeoutSeconds 240`。启动器仅启动一个隐藏 native，等待退出后分析，不启动浏览器。运行输出位于唯一 `.tmp/scatter-culling-<timestamp>/`：request、native/partial、validator、stdout/stderr、28 张截图和 analysis。

脚本复用已有 `_minimap_check.lua` 空入口，加载实际 `Scenes/Crater.xml`，调用生产 `scene.Crater` 绑定真实材质、太阳和环境，固定随机种子 1337，并将环境只更新到时间 1 后冻结。比较的是同一个场景、同一个 camera、同一渲染路径，使用 native 默认渲染链；**不是六车战斗，也不是 Web 自建后处理链或手机性能**。原输入 files SHA 记录在 request，运行期间变化则拒绝分析。

## 保留与测量

- 原 Instance Node 直接注册到候选组，不复制、不改名字/ID、不重新设 transform、不 reparent。候选组为原组节点的 identity 子节点，完整继承原仿射变换。
- 模型和每几何槽的材质继续共享原对象；逐项复制 drawDistance、shadowDistance、LOD、全部 masks、shadow、occluder/occludee、instanceColor/customData 等原属性。原组仅与候选组交替启用。
- 每个视角顺序为 original → 32 → 64 → original-repeat。先排除 setup/settle 帧，再采 steady 帧；屏幕读回、截图、实例校验和切换全部在采样结束后。
- 采实际 renderer batches/triangles、graphics batches/triangles、引擎 timeStep、独立 wall frame interval，并保留逐帧 raw；固定活动/非活动最大 200 FPS，防止隐藏窗口默认限帧误归因。vSync、分辨率、API、阴影/实例化开关记入报告，结束恢复 FPS 设置。
- 三个普通视角为南出击坪、陨坑道路、战舰边。另两组视角位于源最大散布组 bounds-center 的原 drawDistance 内/外 2 米附近，记录每组实际 camera inView、中心/最近/最远实例距离，检验改变分组是否改变可见距离。
- 距离两视角另跑将**目标散布** drawDistance 置 0 的诊断，结束即恢复。该诊断不作为优化成绩；若 limited 差异但 unlimited 一致，报告会提示组距离语义变化，候选不能以更少绘制通过。

## 判定

分析器对比原/候选 PNG；RGB 任一通道误差 >2 算差异像素，差异比例超过 0.1% 标为 DIFFERENT。原/重复原也要相同，否则标为 UNDETERMINED_BASELINE_DRIFT，不假签候选。额外记录变暗/变亮像素和原图颜色数，拒绝纯色或无画面参考。

`candidateEligibility` 的像素 PASS 也仍需实际打开原/候选图审阅。观察到缺失可见物体、阴影或距离提前消失必须拒绝。不能通过减少 drawDistance、关阴影或漏实例换取低三角形。计数中的 `instancesInVisibleGroups` 仅为可见组内注册数，**不是已证明实际逐实例绘制数**。

最终结果 `MEASURED_REQUIRES_VISUAL_REVIEW` 只表示工具完成。必须同时看 validator、stderr、baseline 漂移、普通 limited 图、距离图和帧时间；native 直接默认管线的收益还需在实际 Web 同构建复测。没有 GPU timestamp，wall frame interval 也不能被写成纯 GPU 毫秒。

## 文件归属

本批仅新增 `tools/migration/scatter-culling-core.lua`、`scatter-culling-check.lua`、`scatter-culling-check.py`、`scatter-culling-runtime.lua`、`scatter-culling-analyze.cjs`、`scatter-culling.ps1`，以及本文和离线报告。没有把工具 require 到生产，故不会改变小地图输入图。
