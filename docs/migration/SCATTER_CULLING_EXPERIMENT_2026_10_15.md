# 静态散布分组剔除实验工具

## 状态

已按 root 分配的独占 native/GPU 槽完成实际配对实验，**直接 32/64 米方案均不合格，不改生产**。没有修改任何生产脚本、资源、metadata 或小地图烘焙输入。运行进程已退出并明确释放给 root，未启动浏览器。

### 实际结果（14:45 批）

- 基线为当前已同步私有 main 的开发代码；实验 scene SHA256 `12f03b201e5517813a8974979bba93449a6ee47119a338968c07d3ff7be504e9`，Crater.lua `b096a36db9a1ed4e5f916cb988bd8809bf1290079722cfa4cc264892f414f636`，实际工具 SHA 详见 request/native provenance，不把之后工具修正套入旧测量。
- 完整证据 `.tmp/scatter-culling-2026-10-15T14-45-52-925Z/`：28 张原截图、14 个实际配对像素比较、每 case 120 steady 帧、60 settle 帧、7 个四列 contact 图片（列顺序 original/32/64/original-repeat）。全部 28 张已通过 contact 图查看，额外打开距离差异全裁片和 4 个最近邻放大裁片。
- 实际配置 D3D11、1740×921、4xMSAA、vSync=false、阴影/动态实例化=true、活动/隐藏窗口均 maxFps=200；一个冻结 authored scene/default render path。不是当前 Web 六车战斗，也不是手机实测。

| 视角 | 原组 triangles | 32 米 triangles | 64 米 triangles | batches（均相同） | 原/32/64 median wall ms |
| --- | ---: | ---: | ---: | ---: | --- |
| south-yard | 3,378,167 | 2,666,743 | 2,783,223 | 419 | 10 / 10 / 9 |
| crater-road | 2,857,454 | 2,203,374 | 2,459,630 | 369 | 12 / 11 / 12 |
| wreck-edge | 2,887,722 | 2,244,394 | 2,244,394 | 415 | 8 / 7 / 8 |

普通视角三角形确实少约 0.40–0.71M，renderer batches 相同（引擎继续合批），画面 RGB 最大差 0–1，没有超过 2 的像素。帧时间有约 1ms 波动，而 south-yard 重复原组本身从 10ms 到 9ms；因此不能把全部 1ms 差归因于细分，更不能外推 Web 111/118ms 已解决。

**距离语义否决**：distance-outside 的两个细分方案均有相同 18 个变化像素，坐标 x1097–1190 / y321–364，最大 RGB 通道差 55。占画面约 0.00112%，虽小于通用 0.1% 数值阈值，但变化落在远处岩石表面/轮廓，不可冒称纯 AA。原/重复原零漂移，目标散布的 unlimited 诊断中原/32/64 则逐像素相同，说明变化与距离行为相关。

源组 393 含 317 实例、drawDistance=150：inside camera 到其 bounds center 148.12m，原组 inView=true；outside center 152.12m，原组 inView=false，而最近实例仍约 72.01m。细分 outside 仍有 19/6 组 inView。API 因而存在实际的组中心可见范围行为；不应仅将每个子组 drawDistance 设成原值就宣称保持可见距离。

严格分析器将两方案标记 `NOT_QUALIFIED_RANGE_CHANGE`；`distance-changed-pixels.json` 保留全部变化坐标和 RGB，`distance-diff-*.png` / `pixel-pair-*.png` 保留放大证据。普通图像无变化不覆盖这个边界差异。没有通过更少绘制签收优化，也未将原资源修改成细分组。

**验证边界**：stdout 在 frame5320 明确记录 `INFO__VALIDATE_TEST__:PASSED|5:5:0`，原生实例/变换/属性/恢复功能检查通过；但 V.finish 并不结束引擎配置的 20000 帧预算。全部 case 完成、scene 释放后，对专用 PID33040 发 CloseMainWindow 正常退出（session31441 exit0），**引擎未写出 validation.json，因此整体 validator 未验收**。stderr 仅见既有 DefaultDDS/themis，两者单列，不能宣称引擎零错误。

保留首跑 `.tmp/scatter-culling-2026-10-15T14-43-04-272Z`（工具错误路径 Lua 字符串误用 +，终止专用 PID52592）及第二跑 `14-44-28-158Z`（严格检查发现设置 instanceColor/customData 会自动开启 use 标志，0 steady 数据，终止专用 PID42360）。工具已改为值后恢复原 flags，离线 stub 补同一副作用并重验通过；第三跑才是上述有效数据。没有用失败跑的空截图作为性能成绩。

后续工具已缩小 validator 预算为 `28*(sample+settle)+2000`，并让独占进程的空白尾段保持 200fps 避免隐藏窗口 10fps 尾等待，启动器现在拒绝缺 validator 报告。这些收尾修正尚未再跑 native，不能冒挂本次证据。

### 下一候选，仅设计

可在下一次 QA 中增加“保守回退”：针对每个原组，只有父组与所有子组在原 drawDistance/shadowDistance 阈值的同侧时才启用细分；跨边界时继续画该原组。模型、实例、材质和所有原参数继续不变，分组切换应纳入 steady 帧成本；还须检验阴影、灯光选择及所有新距离裁片。该设计已告知 root，未实施生产，也尚未证明能使完整匹配变快。

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
- 采实际 renderer batches/triangles、graphics batches/triangles、引擎 timeStep、独立 wall frame interval，并保留逐帧 raw；固定活动/非活动最大 200 FPS，防止隐藏窗口默认限帧误归因。vSync、分辨率、API、阴影/实例化开关记入报告；专用进程结束前保持空白尾段 200fps，避免等候 validator 时降到隐藏窗口 10fps。没有修改编辑器进程的设置。
- 三个普通视角为南出击坪、陨坑道路、战舰边。另两组视角位于源最大散布组 bounds-center 的原 drawDistance 内/外 2 米附近，记录每组实际 camera inView、中心/最近/最远实例距离，检验改变分组是否改变可见距离。
- 距离两视角另跑将**目标散布** drawDistance 置 0 的诊断，结束即恢复。该诊断不作为优化成绩；若 limited 差异但 unlimited 一致，报告会提示组距离语义变化，候选不能以更少绘制通过。

## 判定

分析器对比原/候选 PNG；RGB 任一通道误差 >2 算差异像素，差异比例超过 0.1% 标为 DIFFERENT。原/重复原也要相同，否则标为 UNDETERMINED_BASELINE_DRIFT，不假签候选。额外记录变暗/变亮像素和原图颜色数，拒绝纯色或无画面参考。

独立距离规则比通用像素比例更严格：原重复图零漂移、limited 存在 >2 通道差像素而 unlimited 精确一致时，判 rangeBehaviorChanged，候选直接 NOT_QUALIFIED_RANGE_CHANGE，不因差异像素占比小而通过。

`candidateEligibility` 的像素 PASS 也仍需实际打开原/候选图审阅。观察到缺失可见物体、阴影或距离提前消失必须拒绝。不能通过减少 drawDistance、关阴影或漏实例换取低三角形。计数中的 `instancesInVisibleGroups` 仅为可见组内注册数，**不是已证明实际逐实例绘制数**。

最终结果 `MEASURED_REQUIRES_VISUAL_REVIEW` 只表示工具完成。必须同时看 validator、stderr、baseline 漂移、普通 limited 图、距离图和帧时间；native 直接默认管线的收益还需在实际 Web 同构建复测。没有 GPU timestamp，wall frame interval 也不能被写成纯 GPU 毫秒。

## 文件归属

本批仅新增 `tools/migration/scatter-culling-core.lua`、`scatter-culling-check.lua`、`scatter-culling-check.py`、`scatter-culling-runtime.lua`、`scatter-culling-analyze.cjs`、`scatter-culling.ps1`，以及本文和离线报告。没有把工具 require 到生产，故不会改变小地图输入图。
