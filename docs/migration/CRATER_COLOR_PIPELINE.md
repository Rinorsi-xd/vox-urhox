# 坠舰陨坑色彩管线（2026-10-06）

后续更新：PC 游戏现在由 `CraterPostProcess` 直接执行源 Grade/ACES，曝光无需 LUT 重建。本文保留编辑器/无自定义后处理视口的 LUT 回退实现与验证记录。当前游戏路径见 `CRATER_POST_PROCESS.md`。

## 本轮接入

PC 陨坑场景使用源 `pipeline.js` 的 GradeShader（对比度 1.08、饱和度 1.05、暗部冷色、亮部暖色）和 Three.js 的 ACES 输入/输出矩阵及拟合曲线。原生 ACES 使用另一条曲线，同名设置不能保证颜色一致。

`bake-crater-tonemap.py` 生成 `assets/Crater/Tonemap.cube`：49³ 样本，使用引擎 UE Log2 输入编码，含默认曝光 1.1。约 3.48 MiB 文本，已列入地图 `Resources.json`；通过场景 XML 的 **ColorLUT** 引用参与异步资源加载。不是生成美术素材，也没有修改 H5 源文件。

运行时由 `GraphicsSettings` 管理 `CraterTonemap`。默认 LUT 直接加载；改变曝光时分帧重建，因为网页曝光位于 Grade 之后，直接在 LUT 输入端乘亮度不完全等价。构建期间先以倍率补偿即时反馈，完毕后一次上传完整 LUT，并恢复曝光倍率 1。重复修改会取消旧任务；返回大厅或关闭游戏会释放任务、Image 和资源引用。

动态重建复用一个 Color 对象，不为每个样本创建引擎对象。Image 用 sRGB 编码的 RGBA8 保存样本，Texture3D 启用硬件 sRGB 解码，使暗部保留精度并在线性空间插值。没有每帧整表重建、临时 LUT 文件或后台磁盘写入。资源热重载后识别替换的 Texture3D，并恢复当前曝光。

## 验证

`verify-color-pipeline.ps1`：185/185，零运行期 Lua/资源/引擎错误。运行真实 DX11 渲染，读取截图色块中心；参考由独立 Python 实现根据已核对的 H5 公式计算，记录原源码哈希。

- 六组灰阶和两组彩色；默认曝光的最大通道误差为 1/255。
- 曝光 0.6 → 1.4 → 1.0 → 1.4 → 1.1，包含恢复打包 LUT 的热重载，最大误差分别为 1、1、3、1、1 个 8-bit 色阶。
- 验证中断旧重建、场景退出取消未完任务并释放引用。
- 固定曝光 1.0 与关闭自动曝光时的原生 ACES 输出一致。未根据直方图 shader 中的 0.18 常数盲目修改生产曝光。

原始数据 `evidence/color-pipeline.json`，运行报告 `evidence/color-pipeline-validation.json`。本次五轮重建约 137–204 帧，最大 Lua 计算片段约 2 ms；上传时间小于本机计时精度，记录为 0 ms，**不表示无 GPU 成本**。这是协作式预算和一次 PC 测量，非帧时硬保证；曝光调节完成前仍处于近似过渡。

正式三机位与动画验证 233/233，PC 画质 45/45，地图流程 35/35。地图流程新增调节曝光后返回大厅、取消地图色彩任务的检查。

## 引擎接口与范围

当前 Runtime 的 `.cube` 必须作为 `ColorLUT` 资源加载：`cache:GetResource('ColorLUT', path):GetTexture3D()`。`Texture3D` 直接读 `.cube` 会失败。Zone 属性使用 `Variant(VAR_RESOURCEREF, 'ColorLUT;' .. path)`。不再保留失败的 XML 包装/临时文件方案。

当前仅 PC desktop 图形路径使用此 LUT。引擎移动/GLES 路径不支持此 tonemap LUT，运行脚本仍使用原 ACES 回退；移动端色彩一致与骁龙 845 性能尚未完成。

这里只补齐 Grade + ACES，不等于完整 H5 Pipeline。光束、泛光阈值/卷积、mist、HDR clamp、镜头色散、暗角算法与 PBR/阴影响应仍有差异。色块测试不能证明全色域或整幅场景逐像素一致。
