# 坠舰陨坑护盾表现

2026-10-06。原文件 `D:/Rino_Project/Vox/three/src/battle/shieldFx.js` SHA256：`25a5c53d21ad272470a9b36f0f28bebcb34b67d7b89d6b7d7ac2c70f74dbd15d`。

原接口 `hit(point)`、`setHP(k)`、`down(dur=1.6)`、`raise(dur=2.2)`、`update(t)` 由 `scripts/render/CraterShield.lua` 对应承接。坐标是 H5 世界米制数组 `{x,y,z}`，shader 内统一镜像 X。CraterEffects 管理两个实例并按地图时间更新、退出释放。不是独立演示护盾。

恢复编译器之前删除的八槽 `uHits` 循环，包括命中闪光、26 m/s 扩散波、1.6 m 环宽、1.6 秒存活、低血量裂纹/闪烁、溶解和重建。颜色按源 sRGB 转线性再乘 0.9。固定 VectorBuffer 只在命中/重置时上传，不逐帧增长命中表。

原网页仅实现表现接口，没有基地护盾血池、阵营穿透、碰撞拦截或调用 hit 的实际战斗逻辑。因此本迁移不擅自添加伤害规则。地图中会显示和更新护盾，但车辆射击尚不会自动触发它；这项需要后续实际玩法定义。

`crater-shield-reference.cjs` 直接执行只读原实现生成 37 步参考，覆盖命中槽循环、11 次连击、默认/指定时长和动画中断。`verify-crater-shield.ps1` 在真实生产场景中校验状态、实际材质缓冲、颜色、复位及独立性，并截图九种状态：**50/50，零运行错误**。

H5 使用原 buildCraterWorld、shieldFx 和 Pipeline，冻结环境 t=10；原生同机位同护盾时刻。`evidence/crater-shield-comparison.png` 左 H5、右 UrhoX。`compare-crater-shield.py` 重建对照及九宫格。`crater-shield-visible.json` 衡量各自相对完整护盾的可见变化，不能当成跨引擎像素相等证明。光照、阴影及噪声采样仍有视觉差异。

当前程序为 `Generated_Surface_surface_unlit_Shield_EC44924C`；CBA61D6D 和 D7F7B4F3 已从 PC 打包清单退役。
