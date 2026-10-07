# 坠舰陨坑太阳、天空遮挡与光束

源代码为只读 H5 的 `three/src/render/pipeline.js`（ShaftShader）与 `three/src/terrain/atmosphere.js`。本轮接入同样的屏幕空间光束，不是新增美术效果。

## 天空修复

原生场景使用 Skybox，旧 `Crater.Update` 又把其节点移动到相机位置。引擎已经处理 Skybox 跟随，重复平移导致多个机位只显示 Zone 的背景色，而不是原天空。修复为保持节点原点，仅更新时间 uniform。`SkyCapture.shader` 写出原网页的 `ALPHA=0`；不透明物体仍写 1，供光束识别天空。

`verify-crater-sky-alpha.ps1` 读取真实地图 HDR 捕获目标：将相机移至高空并朝向太阳，检查天空 alpha 为 0、日盘亮度高于 42.5；再在相机前放一个不透明盒子，检查 alpha 变为 1。4/4 通过，无替换天空材质，零运行错误。像素读回在 `evidence/crater-sky-alpha.json`。早期只检查 shader 是否加载成功的诊断已替换，不能以加载成功证明其实际输出正确。

## 光束与成本

原 36 次径向采样、.92 步长、.965 权重衰减、亮度阈值 .9、指数空间衰减、暖色 `(1,.8,.55)` 和强度 .3 全部保留。保留源底部起点 UV 的随机偏移，转换后再读取原生顶部起点纹理。源光束之后紧接高光钳制，因此把两者合并进 `CraterPost/Clamp.shader`，没有增加整屏目标或场景绘制。

`CraterPostProcess:PostUpdate` 在第三人称相机完成更新后投影太阳，按原规则淡出：背向太阳关闭；facing 从 .05 到 .45 淡入；太阳屏幕范围从 1.2 到 2.2 淡出。低画质关闭，默认 PC 高画质开启。未改变 GUI 设计或输入坐标。36 次采样仍有 GPU 成本，整合步骤只减少额外带宽/目标，不代表该效果没有开销。

## 证据与限制

- `verify-crater-post.ps1`：原 7 项检查通过；新增两份有光/完全遮挡的诊断图，与实际 H5 Pipeline 的 PNG 全像素 RGB 比较，最大误差均 **1/255**。七种测试图的最大误差均为 1/255；有光与遮挡输出的最大可见差为 5/255，排除“两边都没画效果”的假通过。见 `crater-h5-native-post-comparison.json`。
- `verify-crater-shafts.ps1`：8/8；实际地图同机位开启/关闭出图、太阳投影中心、背向关闭、低画质关闭均通过。
- `crater-shafts-comparison.png`：左 H5，右 UrhoX，上开启、下关闭。朝向太阳时的光束确实进入游戏渲染链；两引擎仍有云层、天空输入、材质/阴影和随机浮尘差异。原生开启前的暖色扩散强于 H5，光束开启造成的增量也不同；不能把诊断图算法吻合扩大为整张地图逐像素一致。
- `verify-crater-parity.ps1 -Label shafts`：233/233，原动画/材质与三正式机位通过。并排图更新为该标签。旧未同步呼吸动画图仍不用于判定反应堆光晕强弱。

复现网页参考：运行 `crater-export-server.cjs` 后访问 `/three/crater-post-probe.html`（七组滤镜测试）和 `?map=1&sun=1`（原地图开启/关闭）；再运行 `compare-crater-h5-post.py`、`compare-crater-shafts.py`。所有源文件保持只读，输出只写当前工程证据目录。
