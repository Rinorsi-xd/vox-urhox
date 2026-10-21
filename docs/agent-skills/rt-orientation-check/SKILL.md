---
name: rt-orientation-check
description: |
  渲染目标（RT）上下翻转（UV / Y flip）的 GPU 现场检测与自动翻正工作流。覆盖四条路径：相机 RT 经 NanoVG 显示、相机 RT 被 shader 采样、NanoVG RT 被 shader 采样、相机 RT 快照拷贝后经 NanoVG 显示。全程不做 CPU 读回（WebGPU 可用），不写死平台/API 判断，runtime 更新改变翻转行为后仍自动正确。
  Use when: (1) 某设备/平台上 RT、立绘、快照、离屏画面、NanoVG 画布贴图上下颠倒, (2) 新增任何 nvgCreateVideo 显示相机 RT、shader 采样 RT、NanoVG 渲染到纹理再贴到材质的功能, (3) runtime / 引擎升级后需要回归检查画面方向, (4) 把这套检测迁移到其他项目。
  触发关键词：上下颠倒、画面倒了、翻转、翻正、UV 反了、Y flip、flipY、方向检测、方向图、哨兵、PortraitCheck、OrientedCopy、orient_map、sentinel、nvgCreateVideo 倒置、RT 倒置、WebGPU 倒置、手机端颠倒。
  SKIP when: 普通图片资源（PNG 文件加载的 Texture2D）显示颠倒——那是资源/UV 问题，不是 RT 方向问题；模型 UV 展开错误。
---

# RT 方向检测与翻正工作流

## 核心原则（先读，决定一切写法）

1. **只测量，不假设**。禁止 `if platform=='Web'`、`if graphics.apiName=='WebGPU'`、"该平台 Y 轴相反所以翻一下" 这类写死的补偿。设备、驱动、runtime 版本都会改变翻转行为，写死的补偿迟早变成"双重翻转"（项目历史 260ac06 就是删掉这种补偿）。
2. **在 GPU 上测量，在 GPU 上纠正**。不做截屏/`GetImage` 读回（WebGPU 无同步读回，且读回本身也可能被翻）。检测结果写进一张小纹理，消费方 shader 直接采样它决定翻不翻。
3. **测量走与内容完全相同的管线**。标记必须经过和真实内容同样的 相机/渲染路径/纹理格式/`nvgCreateVideo`/`nvgImagePattern` 链路，否则测出来的是别的东西。
4. **四种怪癖互相独立，分开测量**，需要时用异或组合（见下表）。
5. **测不出来就不翻**。所有判定都带 alpha 有效性门槛：方向图未绘制、哨兵未就绪、资源创建失败 → 判定值为 0 → 原样显示。
6. **采样点避开抗锯齿边缘**：用块中心（8×8 图的 1.5/8、6.5/8 处），过滤模式 `FILTER_NEAREST`。

## 第 1 步：判断属于哪条路径

| 路径 | 典型代码特征 | 需要的判定位 | 纠正位置 |
|------|------------|------------|---------|
| **A. 相机 RT → NanoVG 显示**（实时） | `nvgCreateVideo(vg, rtTexture)` + RT 内容由自己的 shader 画 | `shown`：方向图左右两列是否不同 | RT 内容的 shader 里翻 UV（方向图 + 角标记） |
| **B. 相机 RT → shader 采样** | 后处理/降分辨率/FilterGraph 把 RT 当 `sampler2D` | `sampled`：哨兵 v=0.25 处是蓝色 | 采样方 shader 翻 UV（哨兵） |
| **C. NanoVG RT → shader 采样** | `nvgSetRenderTarget(vg, tex)` 后 `material:SetSurfaceTexture(..., tex)` | `nvgSampled`：方向图左列 (0.1875,0.1875) 是蓝色 | 采样方 shader 翻 UV（方向图左列，或 RT 内自带角标记） |
| **D. 相机 RT 快照 → NanoVG 显示**（静态） | 场景截图、漫画格、结算实景格，内容 shader 不可控 | `sampled XOR shown` | 一次性 GPU 拷贝（OrientedCopy），之后静态 |

先用这条命令列出所有可疑点，逐个归类：

```bash
grep -rn "nvgCreateVideo\|nvgSetRenderTarget\|TEXTURE_RENDERTARGET\|GetRenderSurface" scripts
```

> 从 PNG 加载的 `Texture2D` 不受影响；`nvgCreateImage` 加载的文件图片也不受影响。只有 **渲染目标** 需要处理。

## 第 2 步：落地

- **本项目**：参考实现已存在，直接复用，不要另起一套：
  - 方向图 + 哨兵：`scripts/render/PortraitCheck.lua`、`assets/Shaders/BLGL/UI/OrientSentinel.shader`
  - 路径 A：`scripts/ui/CommsPortrait.lua` + `CommsPortrait.shader`（`marker_size` / `orient_map`）
  - 路径 B：`scripts/render/MobileSceneScale.lua` + `SceneUpscale.shader`
  - 路径 C：`scripts/render/MvpBanner.lua` + `Mvp/Banner.shader`（方向图左列）；`scripts/scene/HangarPanels.lua` + `Hangar/Canvas.shaderinc`（RT 自带角标记）
  - 路径 D：`scripts/render/OrientedCopy.lua` + `OrientedCopy.shader`（`IntroSceneCapture`、`BossSceneCapture` 在用）
- **其他项目**：复制 `project-files/` 下的通用版（`project-files/scripts/...` → `scripts/...`，`project-files/assets/...` → `assets/...`），按 `references/patterns.md` 接入。

每条路径的接入代码、shader 片段、注意事项见 **`references/patterns.md`**。

## 第 3 步：验证（每次新增路径 + 每次 runtime 升级都要做）

1. LSP 诊断无 Error，构建。
2. 运行自检场景 `project-files/scripts/render/OrientationSelfTest.lua`（复制进项目后 `require('render.OrientationSelfTest').Start()`）。
3. 在 **所有目标平台** 上看一屏：**所有 FIXED 格必须是「红上蓝下、绿点在左上」**。RAW 格显示该设备当前有哪些怪癖，仅供记录。
4. 关注日志：`[OrientationMap] unavailable` / `sentinel unavailable` / `[OrientedCopy] orientation map never painted` 表示走了"不翻"兜底，需要排查。

详细清单与"runtime 升级回归"流程见 **`references/verification.md`**。

## 禁止事项

- ❌ 按平台、图形 API、UA、`graphics.apiName` 写死翻转。`graphics.apiName` 只能打日志。
- ❌ 用 CPU 读回像素判定方向（WebGPU 不可用，且曾导致启动探针反复失败重试）。
- ❌ 只信文档说"`nvgCreateVideo` 已处理方向"——这在部分手机 WebGL / WebGPU 上不成立，且会随 runtime 变化；以现场测量为准。
- ❌ 标记画在与内容不同的 RT、不同格式或不同渲染路径上。
- ❌ 在同一条显示链上叠加两次纠正（例如 RT 内容 shader 已按 `shown` 翻过，显示端再翻一次）。
- ❌ 采样标记边缘像素（AA 晕边会给出混合色）。

## 参考文档

- `references/principles.md`：判定原理、方向图布局、为什么这样能扛住 runtime 变化、项目踩坑史
- `references/patterns.md`：四条路径的接入步骤与代码
- `references/verification.md`：自检场景、平台矩阵、回归清单、日志排障
