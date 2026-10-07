# 烘焙阴影通道修正

2026-10-06。基地背后崖壁曾黑成一片，散布石块看似浮空。关闭地形剔除未恢复画面，换成反面剔除反而真正露出天空，排除了丢面。源 terrainMaterial/mapMaterials 将烘焙 G 通道作用于 directDiffuse/directSpecular；旧转换器将它乘在 ALBEDO 上，连间接环境光也压黑。这是迁移错误。

`DirectLight.shaderinc` 通过引擎支持的 SurfaceShader `light()` 分开直射与间接光。地形、远山和建筑共享原 Three.js r186 的 Lambert/GGX、Schlick Fresnel 和多次散射能量补偿。烘焙 G 只调制直射结果；R 保留原间接 AO 与少量直接遮蔽；远山 vSun 只调制直射。恢复近地形烘焙范围掩码和 uniform 烘焙尺寸/淡出距离。几何粗糙度使用原视空间法线导数。

`convert-crater-dfg.py` 从当前 Three.js 内置表提取 16×16 RG16F DFG 数据，以两组 16-bit 定点存 PNG RG/BA，不新增艺术素材。512 个数最大解码误差 `7.6141e-6`；保留原双线性采样。版权许可在 THREE_LICENSE.txt。生成器给相关材质绑定该表，资源清单含表和 shader include。

实际引擎的间接 SH/IBL、点光衰减和阴影仍由 UrhoX 提供，并不等价于 Three 的完整 BRDF/环境实现。自定义 light 使用原生 forward 路径；不能把本次 PC 结果推断成移动端性能或所有后端完成。

## 复测

- `verify-crater-parity.ps1 -Label directlight`：233/233，零错误，三处原机位截图；`compare-crater-parity.py --label directlight` 更新并排图。正式对照未同步所有动画时相，舰内呼吸灯差异仍须用同步序列判断。
- `verify-crater-direct-light.ps1 -Python <Python>`：真实生产地图四张图、4/4。关闭全部实时灯，只将地形烘焙 G 从 0 换到 1，全图最大差 1/255，超过 1/255 的像素为 0。打开太阳后，434,348 个像素变化超过 1/255，最大差 108/255。证明未压暗间接光且直射遮蔽仍有效。
- 新 shader 下护盾 50/50、地图入口/驾驶/九区域/相机/退出释放 58/58，天空 HDR/alpha 4/4。
- 隔离全部开发 shader 缓存，大厅 3/3、画质 45/45、地图 58/58，零新增编译、零运行错误。当前 PC 包 520 文件、3,983,276 字节；30 个已替代地图/天空/护盾程序退役。最大帧为 259.74 / 239.40 / 413.21 ms，含加载，不证明稳定帧率。

早期诊断遇到测试启动帧早于地图就绪、helper 内直接读 VIEW_MATRIX 不受支持；已分别改为等待实际场景、由 fragment 传入视空间法线。最终报告以以上成功复测为准，失败诊断留在 .tmp，不随游戏打包。
