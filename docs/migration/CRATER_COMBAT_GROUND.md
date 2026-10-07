# 陨坑战斗碎片与火花落地

修复 CombatEffects 仍以 Y=0 为地面的迁移遗漏。现在 TrialSession 向显示层传入当前世界的 GroundAt 查询；陨坑使用原 H5 1 米画面地形，试车场返回 0。显示层不引用物理引擎、不执行逐粒子射线、不回写战斗状态。

## 数据与归属

`tools/migration/crater_height.py` 从已经导入的 100 块近景地形读取全部顶点，反转坐标转换后恢复 641×641 高度网格。边界重复顶点要求完全一致，缺点或异常模型格式会中止生成。输出 `assets/Crater/VisualHeight.bin` 为 20 字节头及 410,881 个 float32，1,643,544 字节；无量化损失。`compile-crater.py` 已接入生成和 Resources.json 列表，单独运行提取脚本只生成二进制，不重写其他地图资源。

`scripts/core/HeightField.lua` 通过 ResourceCache 打开已就绪的资源，一次读入 native VectorBuffer 后关闭文件；查询只读四个格点，按原 near.userData.sample 双线性插值，范围外钳制到边界。数据与 world 同寿命，取消准备和退出都显式 Clear，清空后不能继续查询。效果退出清除回调，避免保留旧 world。未选择地图时不加载这个缓冲，不复制为庞大 Lua 数字表，不新增 GPU 纹理。

碎片保持原版尺寸一半的落地偏移、0.3 竖直反弹及 0.6 水平/旋转衰减。原网页只有 Chips 接入地形，普通重力火花也写死了 0.02；迁移端一并修正为地形高度+0.02。无重力烟雾和光点不采样、不强制贴地。该项是对原火花平地局限的修正，不能描述为所有粒子轨迹与原版相同。

## 验证

- `source-crater-ground.mjs` 执行原 terrainMesh/gridHeight/outpostHeight/groundAO，读取原地面烘焙图。**410,881 个顶点与二进制数据误差均为 0**；代码和烘焙图 SHA256 记入源样本。这里只用 Canvas 数据读取替身，原地形及碎片公式不改写。
- `verify-crater-ground.ps1`：真实游戏载入陨坑，比较 1,042 个采样位置（含负高度、高地、斜坡、四边和越界）以及 6 条原 Chips 轨迹的 540 个状态。检查真实火花落地、无重力烟雾、内存释放及返回原试车场，共 **1595/1595**，验证期零错误。
- `verify-resource-loading.ps1`：**29/29**，额外检查取消已部分准备的地图会立即清空高度缓冲。
- `verify-combat.ps1 -Quality desktop`：**94/94**，原试车场武器、输入、压力预算和效果寿命回归通过。
- 已查看 `evidence/crater-ground-correct.png`、`crater-ground-legacy-zero.png` 和局部对照 `crater-ground-comparison.png`。使用同一真实地图、同一 break 事件/随机序列，仅在诊断中切换旧落地查询；旧分支不进入游戏实现。原生截图不代表整场景 H5 像素一致。

一次桌面 CPU 查询测量：20,840 次查询约 **25 ms**，原生缓冲 **1,643,524 字节（约 1.57 MiB）**，见 `evidence/crater-ground-cost.json`。这是单次本机数据，不是手机性能承诺。当前加载回归仍记录约 94 ms 的最大准备片段，虽设 3 ms 合作式预算，个别原子操作仍会超出；没有将其描述成加载卡顿已解决。

后续布局读取和分帧修正已降低准备峰值，本段 94 ms 属于当时记录；最新 22 ms 观测及其边界见 `CRATER_LOADING_SLICES.md`。

## 边界

这里查询地形，不包含舰内多层楼板、建筑顶部和洞穴碰撞；与原碎片 GroundAt 的范围相同。刚体残骸仍走实际物理系统。天空/雾/后处理、地形显示网格和车辆碰撞高度场没有因这次修复重建或改形。其他地表效果及材质内部的近似高度采样仍需继续核对。远端弱网下载、地理分区流式加载、骁龙 845 持续负载均未验收。
