# 装配轮胎宽度核查（2026-10-07）

用户反馈装到车上后轮胎宽度与 H5 观感不同。本次以当前 `D:/Rino_Project/Vox` 为只读基准，检查 UrhoX 活动工程；没有调整生产模型、缩放、蓝图或相机参数。

## 用户原 H5 截图后的纠正

用户明确指出 `codex-clipboard-09f5d381-1716-436a-9ad0-9974288ecfac.png` 来自原 H5。此前回复所展示的是赤焰 GT 的 T3；不能以 T3 对照图代替这张具体轮胎的核查，更不能据此宣称用户现场画面已一致。

该截图的长条胎纹、轮毂和黄色外沿与 T5 外观相符；仅凭截图不区分动力轮与转向轮。当前原 H5 实际入口 `http://localhost:5173/three/?review=part-sizes` 的「格尺 drive5」已实际打开并截图，使用原游戏现成的临时车辆核查入口，不读写玩家存档，未修改 H5 文件。

T5 动力轮的橡胶轴向厚度约 **2.715254 m**、直径约 **4.478479 m**；厚径比约 **0.606**。这与 T3 的约 0.339 明显不同，不能把 T3 的宽厚比例概括到所有轮胎。既有逐顶点装配报告中的 T5 动力轮 24 个朝向均通过，最大坐标差为 3.5763e-7 m。

补充原生截图运行真正的 `main.lua`、使用 `app.car` 的实际 `VehicleView`、rig、材质与机库灯光；仅在独立验证进程中切换单个 T5 和正交检查相机，以 view mask 隐藏遮挡胎面的机库物件。相机与 H5 格尺采用相同位置关系及每米像素比例。T5 胎面截图的厚度及花纹位置一致；此处没有调整、压窄或拉伸几何。

![左原 H5 T5，右 UrhoX T5，竖向为轮轴厚度](evidence/wheel-t5-width-comparison.png)

两端保留各自材质，灯光环境不同，因此**不是材质、光照或用户当时具体运行实例的完整视觉验收**。目前未复现额外拉宽 T5 的迁移问题，不能将“当前受控对照一致”扩大为“用户报告的问题已修复”。

- 原 H5 全图：[wheel-t5-h5-ruler.jpg](evidence/wheel-t5-h5-ruler.jpg)。
- 原生捕获脚本：`tools/migration/capture-wheel-t5.lua`；以本文件末尾原生截图命令替换 test/output 文件名执行。
- 原生报告：[wheel-t5-capture.json](evidence/wheel-t5-capture.json)，5 项断言通过，无 Lua/资源/引擎错误。断言只检查装配与截图写出，截图还经过人工查看，黑图不能以断言通过作为成功。
- 合成脚本：`tools/migration/compose-wheel-t5.py`，原尺寸裁取 H5 左侧视口并并排排版，不缩放或变形任一轮胎图像。

## 实测结论

10 种动力轮/转向轮 × 24 安装朝向，加上当前赤焰 GT 四个实际挂点，共 244 项通过。比较内容包括整个装配、滚动部分、橡胶胎面的世界空间顶点边界以及轮心世界位置。最大坐标误差 **3.5763e-7 m**。

赤焰 GT 的 T3 动力轮和转向轮，两端滚动部分轴向宽度均为 **0.856522 m**，直径约 **2.499422 m**；橡胶胎面宽度约 **0.847826 m**。安装位置和轮心也一致。这里宽度指沿轮轴的厚度，直径是垂直轮轴的尺寸。

原 H5 `VehicleView` 与原生 `VehicleView` 装配同一赤焰 GT，在正面、俯视和斜前方使用相同正交机位、1280×800 视口，并临时改用平涂材质比较轮廓。三个角度的整车轮廓交并比均为 **1.0**，可见范围与像素边界一致。俯视图尾部贴近底边，该图不证明画外部分；尺寸检查仍包含完整几何。平涂颜色和背景不同，不用于材质/光照一致性验收。

![左 H5，右 UrhoX，正面轮胎宽度](evidence/wheel-width-front-comparison.png)

这排除了已测基线的转换缩放、装配厚度和安装朝向错误，但没有复现用户当时的具体机位、车型、运行实例和 H5 浏览器状态。不能据此声称用户观察错误，也不能把视觉差异直接归因为相机或缓存。若继续出现，应保留同一型号、角度的两端画面进一步定位。

## 工具与证据

- `tools/migration/source-wheel-size.mjs` 执行原 H5 车轮加载与装配代码，导出 244 个预期值及源哈希。
- `tools/migration/check-wheel-size.lua` 读取真实原生模型顶点并应用实际节点世界变换；不从目标 Catalog 的尺寸字段生成预期值。
- `./tools/migration/verify-wheel-size.ps1` 生成预期并启动独立 Runtime，使用测试实例，不写玩家存档。
- [运行报告](evidence/wheel-size.json)：244/244，无 Lua/资源/引擎错误。
- [逐项测量](evidence/wheel-size-measurements.json)、[轮廓像素结果](evidence/wheel-size-pixel-comparison.json)、[多角度对照](evidence/wheel-size-comparison.png)。
- H5 画面生成：`node tools/migration/wheel-size-reference.mjs` 后打开 `http://127.0.0.1:43189/` 点击生成。服务器只读提供源资源，只能写三个命名的证据 PNG。
- 原生画面：以 `main.lua -tool_mode -quality=desktop -validate -validate-frames=90 -validate-timeout=60 -validate-spike-threshold=30000 -validate-test=<工程>/tools/migration/capture-wheel-size.lua -validate-output=<工程>/docs/migration/evidence/wheel-size-capture.json -tapcode_dir=<工程>` 启动独立 Runtime。测试中明确固定视口并裁取 1280×800，不依赖禁用的窗口分辨率设置。

另做了原模型转换器的只读重新导出：现有 198 类型的模型与 rig 没有变化，源只新增三个尚未迁移的转轴及其模型。本次仅对轮胎做了逐顶点运行时尺寸核查，不将结果扩大为所有武器、履带、动态姿态或全部画面已验收。
