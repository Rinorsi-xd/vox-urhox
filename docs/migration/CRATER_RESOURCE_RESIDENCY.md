# 地图环境生命周期与烘焙图驻留（2026-10-06）

## 天空释放

旧行为：离开坠舰陨坑，Scene、模型和纹理数组已释放，`Crater/Sky.hdr` 仍在 ResourceCache。独立验证确认持有者是全局环境烘焙缓存：调用其 ClearCache 后普通 `ReleaseAllResources(false)` 即可释放旧天空。

当前 Runtime 有 `environmentBakeCache:ClearCache()` 和 `RequestBake(texture)`，没有文档中的 InvalidateSource。现在只在场景切换稳定三帧后清理可复用烘焙缓存，再执行已有非强制资源回收。取消/失败也走同一延迟释放路径。当前 Zone 保留自己已应用的 SH/IBL，不强制 Dispose 仍在使用的纹理。

清缓存前后，实际场景固定机位截图 **全图最大差 0/255**，见 `environment-cache-pixels.json`。三轮真实大厅→地图→大厅检查均释放非活动场景的天空，未通过关闭 GC 或保留旧地图规避问题。

代价是下次访问可能重新异步烘焙。因此 SceneLoader 新增 environment 阶段：保持旧场景活动，等候候选 Zone 的原生 RequestBake 返回就绪，再绑定结果并提交场景。等待中仍可取消；失败保留旧场景。没有把“正在烘焙”当作可见场景就绪。

本修复不是引擎全局缓存的 LRU 实现，也不声称清掉了所有 GPU/驱动分配。编辑器交互稳定性仍需独立验收。

## 五张建筑烘焙图

H5 `three/src/battle/mapModules.js` 明确关闭建筑烘焙图 mipmap，避免 UV 岛串色；shader 只使用 R/G 两个通道。原迁移 PNG 在 GPU 中展开为 RGBA 并分配完整 mip 链，尽管建筑 shader 只采样线性基础层。

现在使用 **KTX1 / RG8_UNORM / 单 mip / 线性数据**，保留每个 R/G 字节，不量化、不缩小尺寸、不改变模型 UV。地形的 ground bake 仍保持原来的 mipmap；六层 albedo/NRA 数组不在此修改范围。

| 五张建筑图合计 | 修改前 | 修改后 |
|---|---:|---:|
| GPU 纹理有效载荷（按实际格式/层级计算） | 162,179,748 B | 60,817,408 B |
| GPU 纹理有效载荷 MiB | 154.67 | 58.00 |
| 未打包文件 | 40,165,202 B（PNG） | 60,817,748 B（KTX） |

减少约 **96.67 MiB 纹理有效载荷**，不等于测得总显存减少相同数值：当前引擎 Texture2D.memoryUse 返回 0，驱动额外分配未计入。未打包文件增加约 **19.70 MiB**；远端传输压缩和下载耗时未经验证，不能称为下载包瘦身。

`pack-crater-bakes.py` 默认生成临时候选；`--apply` 安装 KTX，把原 PNG 移到 `tools/migration/crater-source/bakes/` 作为离线再生成输入，移除旧 PNG 的运行资源。编译器和运行时 Materials/Resources 清单均引用 KTX；源码导出清单仍记录原 PNG。原 H5 仓库未修改。

当前引擎 `Graphics:GetLuminanceAlphaFormat()` 返回实际 RG8 格式；`GetFormat('rg8')` 不识别并退回 RGB，不能用于验证。KTX 文件头明确指定 GL_RG8，不使用会被扩成 RGBA 的 LA PNG。

## 验证入口

- `verify-crater-bakes.ps1 -Python <python>`：从原 PNG 再生成临时候选，检查 36 个真实材质绑定和 6 张截图，共 43 项；基地、舰体外部、舰内各两张全分辨率图逐像素一致。
- `verify-crater-memory.ps1 -Label packed-bakes`：24/24，真实应用三轮往返，检查原地图模型/纹理全部离场、非活动大厅天空释放，以及 KTX 实际 GPU 格式/层级。默认无测试侧额外清缓存。
- `verify-resource-loading.ps1`：28 项，涵盖原生下载回调回放、取消/失败/重试、分帧碰撞，以及光照等待取消、实际烘焙就绪后才提交。
- `verify-crater-game.ps1`：58 项，真实 UI 路由、镜头、驾驶和退出。
- `verify-environment-cache.ps1 -Python <python>`：4 项及清理前后像素检查。

这些验证在 Windows DX11 独立 Runtime 中执行，没有操作用户编辑器或用户正在运行的进程。RG8 是常规 GPU 数据格式，但尚未在实际 Android/845 设备验证该加载路径。

正式资源接入后：地图回归 58/58，加载 28/28，驻留 24/24，正式机位 233/233（标签 `packed-bakes`），烘焙图 43/43；零 Lua、资源、引擎错误。三轮返回的地图模型/纹理资源数均为 0；五张 KTX 均实测为原分辨率、RG8、单 mip。`crater-formal-comparison.png` 已更新，三个固定机位的 H5/UrhoX 整体差异仍存在。

## 压缩调查及剩余工作

微软 DirectXTex may2026 的签名版 texconv 曾用于独立候选转换。来源：`https://github.com/microsoft/DirectXTex/releases/tag/may2026`；下载工具 SHA256 `DCFDEC10244E02CF5037FBA089C55FB7E1326B1C8181742D77D15FA5CB5EEF06`。临时工具、失败格式候选及 A/B 测试的重复素材已逐文件清理，不进游戏包；诊断摘要保存在 `evidence/crater-texture-format-probes.json`。正式打包器只依赖 Python/Pillow，验证时自动再生成 A/B 临时输入。

实际能力边界：BC7 DDS 普通 Texture2D 可加载，但 Texture2DArray 的 Image 解码路径报 `Unrecognized DDS DXGI image format`，数组尺寸为 0；RG8 DDS 也未加载成功。RG8 KTX 的加载、真实采样和逐像素对照通过后才接入正式资源。没有把生成了压缩文件或 sidecar 的 BC7/ASTC 声明当成压缩生效。

两组地形数组仍以未压缩 RGBA 驻留，合计 256 MiB；需要兼容当前数组加载器的发布压缩路径。远端弱网/续传、地理分区流式加载和骁龙 845 持续帧率/温度仍未验收。地图材质光照及 GUI/玩法整体迁移仍按原目标继续，不以这次驻留修复宣称整体完成。
