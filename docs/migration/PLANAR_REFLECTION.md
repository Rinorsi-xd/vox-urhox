# 大厅平面反射裁剪

本项目当前只有一个平面反射面：世界坐标 Y=0 的大厅甲板。源为 `D:/Rino_Project/Vox/three/src/render/reflection.js`。本修正只处理反射几何范围，不改变原 UI、正常视图、相机取景、反射强度或过滤方式。

## 为什么不用 Camera.SetProjection

当前独立 Runtime 的实际版本为 `.cli/build.json` 中的 `20260923-1717-bf3316f`。安装器的 HTTP 304 表示安装包未修改，不是引擎版本号。

正式相机 `useClipping=true` 在已测 DX11 SurfaceShader 路径未裁掉地下标记。进一步诊断发现 `GetProjection()` 返回普通 0..1 深度投影，`GetGPUProjection()` 才使用反向深度；`SetProjection()` 接收自定义矩阵后不执行同样的转换。注入斜裁剪矩阵后 `IsProjectionValid()` 返回 false，渲染目标保留旧帧。数值投影结果正确、截图仍有内容均不足以证明可用。记录见 `evidence/planar-projection-diagnostic.txt`，试验没有进入正式相机代码。

## 正式材质规则

`assets/Shaders/BLGL/lib/PlanarClip.shaderinc` 是唯一规则来源。镜像视图的基矩阵行列式为负；本项目的普通左手相机为正。仅镜像颜色视图中，世界位置位于 `planar_clip_plane` 负半空间的片元被丢弃。参数默认 `(0,1,0,0)`；全零关闭裁剪，供正例验证使用。`IN_SHADOW_PASS` 显式跳过裁剪，不通过相机高度判断，不在每个视图遍历或修改材质。

车辆的普通漆面、清漆、发光、玻璃、武器和动态装饰，以及大厅几何、透明面、粒子贴片和建造覆盖层使用同一个 helper。甲板自身被反射相机的 viewMask 排除；ReflectionDownsample 只过滤纹理，不使用世界裁剪。试车专属 Track/Combat 材质没有平面反射消费者，不增加这段逻辑。

`Equipment/Volume.shaderinc` 使用单独的体积处理：顶点阶段将平面用模型矩阵的转置变换到实例局部空间；片元阶段求射线的平面交点，缩短体积积分区间。不能直接丢弃代理盒背面的片元，否则跨地板的盒子会连同地上火焰一起消失。斜穿、非均匀缩放、平行射线均须保留正确区间。

这些规则不分配纹理、节点或 Lua 事件，不改变反射 30Hz 的刷新预算。片元裁剪仍有 GPU 成本，不等于硬件近裁剪面的性能；当前未完成手机实测。未来新增水面或非 Y=0 镜面时，必须为其渲染材质显式配置对应平面，不能直接沿用大厅默认值。

## 复验

- `tools/migration/verify-reflection-refresh.ps1`：正式大厅反射的更新、地上正例、地下裁剪，以及同时关闭材质/相机裁剪的地下正例。
- `tools/migration/verify-planar-clip.ps1`：在正常视图和反射中绘制同一个对象，覆盖地下、地上、穿过地板、关闭/恢复裁剪；含不透明、实例色、清漆、透明、动态材质和两个体积效果。
- `tools/migration/verify-car-lift.ps1`：换车过程及原版动作曲线，输出实际场景截图。
- `tools/migration/verify-hangar-reflection.ps1`：反射投影、滤波、PC 比例、重载与资源释放。

验证截图使用实际 GPU 输出，数字阈值只用于检测特定测试标记，不作为整个大厅或 UI 的视觉相似度。Shader 改动后需重新生成 PC 原生缓存，并隔离开发缓存检查启动；首次编译耗时不应混入已缓存的帧率结论。

最终几何/体积检查 84/84、正式反射更新 5/5、直接纹理读回的过滤/投影/释放 17/17、换车 342/342，通过且无运行期 Lua/资源/引擎错误。旧过滤检查额外建立的 Probe Scene 已移除，常量颜色检查改为临时给现有三个过滤材质换绑同一常量纹理，验证后恢复；不再加入额外探针渲染场景。

完整换车截图底部可见的灰色四旋翼是巡航无人机，不是地下玩家车体。独立对照关闭反射、再隐藏玩家车体后它仍然可见并移动；诊断截图为 `pc-car-lift-diagnostic-no-reflection.png` / `pc-car-lift-diagnostic-no-car.png`。该物体不能用作反射失败证据。更新后的 `pc-car-lift.gif` 是受控时间采样，不代表实时帧率。
