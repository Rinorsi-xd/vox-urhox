# 四条路径的接入方式

前置：已放置 `scripts/render/OrientationMap.lua`、`scripts/render/OrientedCopy.lua`、`assets/Shaders/Orientation/*`，并在 shader 里 `#include "Orientation.shaderinc"`（相对 include 从当前文件目录解析；放在其他目录时写 `res://Shaders/Orientation/Orientation.shaderinc`）。

通用准备：

```lua
local OrientationMap=require 'render.OrientationMap'
```

`OrientationMap.Bind(material, needSentinel)` 会绑定 `orient_map`、`orient_sentinel`（缺失时绑 1×1 全透明兜底）并设置 `orient_enabled`。返回 false 表示输入不全，此时 shader 判定恒为 0（不翻）。

---

## 路径 A：相机 RT → NanoVG 显示（实时内容）

RT 内容由自己的 shader 渲染，shader 可控。检测结果在**内容 shader** 里使用（不是显示端）。

1. **在内容 RT 上画角标记**（2×2 texel，只画在真实 texel 上）：

```lua
-- 每帧画完内容后，重置变换再画标记
nvgSave(vg);nvgResetTransform(vg);nvgGlobalCompositeOperation(vg,NVG_COPY)
nvgBeginPath(vg);nvgRect(vg,0,0,2,2);nvgFillColor(vg,nvgRGBA(255,0,0,255));nvgFill(vg)          -- 左上＝红
nvgBeginPath(vg);nvgRect(vg,0,th-2,2,2);nvgFillColor(vg,nvgRGBA(0,0,255,255));nvgFill(vg)       -- 左下＝蓝
nvgRestore(vg)
material:SetShaderParameter('marker_size',Variant(Vector2(2/tw,2/th)))
```

2. **内容 shader** 在 `fragment()` 开头按 `shown` 翻 UV，并用 `marker_size` 把标记涂掉：

```glsl
#include "Orientation.shaderinc"
uniform vec2 marker_size = vec2(0.0);
void fragment() {
    vec2 vp=UV;
    if (orient_enabled > 0.5) {
        vec4 l=texture(orient_map,vec2(0.1875,0.1875)), r=texture(orient_map,vec2(0.8125,0.1875));
        float shown=step(0.5,l.a)*step(0.5,r.a)*step(0.5,abs(l.r-r.r));
        vp.y=mix(vp.y,1.0-vp.y,shown);
    }
    // ... vp 用于后续所有采样 ...
    if (vp.x < marker_size.x) {
        if (vp.y > 1.0-marker_size.y) { ALBEDO=vec3(1.0,0.0,0.0); ALPHA=1.0; }
        else if (vp.y < marker_size.y) { ALBEDO=vec3(0.0,0.0,1.0); ALPHA=1.0; }
    }
}
```

3. **Lua 侧**：`M.New` 中绑定方向图；每次准备显示时 `OrientationMap.Use(self)`，并实现 `DrawCorner`：

```lua
local orientation=OrientationMap.Texture()
if orientation then
    material:SetSurfaceTexture('orient_map',orientation)
    material:SetShaderParameter('orient_enabled',Variant(1.0))
end

-- handle = nvgCreateVideo(vg, self.texture)，按 vg 缓存
function self:DrawCorner(vg,x,y,size,bottom)
    local k=size/2                       -- 2 texel -> size 像素
    local h=self.texture:GetHeight()*k
    local top=bottom and y+size-h or y
    nvgBeginPath(vg);nvgRect(vg,x,y,size,size)
    nvgFillPaint(vg,nvgImagePattern(vg,x,top,self.texture:GetWidth()*k,h,0,handle,1));nvgFill(vg)
end
```

4. **显示时裁掉标记区**：`nvgIntersectScissor(vg, r.x + r.w*2/tw, r.y, r.w - r.w*2/tw, r.h)`。

⚠️ 不要同时用 `OrientedCopy`——内容 shader 已经按 `shown` 翻过了。

---

## 路径 B：相机 RT → shader 采样

典型：降分辨率场景、后处理、`render.FilterGraph`、离屏再到屏幕。

```lua
local sentinel=OrientationMap.Request()   -- Texture2D|nil
material:SetSurfaceTexture('sentinel_map',sentinel or OrientationMap.Fallback())
```

shader：

```glsl
#include "Orientation.shaderinc"
uniform sampler2D source_map : filter_linear, repeat_disable;
void fragment() {
    ALBEDO=texture(source_map,orient_apply(UV,orient_rt_sampled_flip())).rgb;
}
```

- 通过 `OrientationMap.Bind(material,true)` 一次绑好更省事。
- 兜底纹理 alpha=0，所以 `sentinel` 未就绪时判定为 0，不翻。
- 若同时还要显示这个结果，注意路径 D 的"sampled XOR shown"——`SceneUpscale` 这类最终直接上屏的拷贝只需 `sampled`。

---

## 路径 C：NanoVG RT → shader 采样

典型：NanoVG 画布/文字贴到 3D 材质（结算锦旗、HUD 面板、招牌）。

**方案 C1（推荐，通用）**：采样方用方向图左列判定。

```lua
OrientationMap.Bind(material,false) -- 只需要方向图；传 true 会额外绑定哨兵
OrientationMap.Request()            -- 保活，直到 PaintedAfter(startFrame)
```

```glsl
float flip=orient_nvg_sampled_flip();
ALBEDO=texture(canvas_map,orient_apply(UV,flip)).rgb;
```

若该材质在方向图绘制完成前就已上传，方向图之后仍是全透明 → 判定 0 → 不翻。这类"静态上传一次"的场景需要像 `MvpBanner` 那样每帧 `OrientationMap.Request()` 直到 `PaintedAfter(startFrame)`（可用 `OrientationMap.Settle(startFrame)` 简写）。

**方案 C2（RT 内自带角标记）**：NanoVG 画布自身在左上/左下 2×2 画红蓝，shader 内比较两个标记：

```glsl
uniform sampler2D canvas_map : filter_linear, repeat_disable;
uniform vec2 canvas_marker = vec2(0.0);
float top=texture(canvas_map,canvas_marker).r;
float bottom=texture(canvas_map,vec2(canvas_marker.x,1.0-canvas_marker.y)).r;
float flip=step(0.5,bottom-top);
```

这种方式测的是"这张图在 shader 里读到的上下关系"，与方向图左列的 `nvgSampled` 等价，但不需要方向图。两方案二选一即可，**不要同时翻两次**。

注意：C2 的 UV v=0 是 RT 的"绘制顶部"还是"绘制底部"取决于该设备的 NanoVG 写 RT 行为，而 `step(bottom-top)` 的写法恰好与方向图右列同构——标记是随内容一起被翻转的，比较结果始终正确。

---

## 路径 D：相机 RT 快照 → NanoVG 显示（静态）

典型：场景截图、漫画格、Boss 结算实景格。内容 shader 不可控，所以做一次性 GPU 拷贝。

```lua
local OrientedCopy=require 'render.OrientedCopy'

-- 快照渲染好之后（至少 2~3 帧、QueueUpdate 已生效）
self.copy=OrientedCopy.New(self.texture)
-- 每帧推进，返回非 nil 时表示可显示
local shown=self.copy:Step()
if shown then
    if shown~=self.texture then MyLifetime.Retire(self.texture);self.texture=shown end
    self.copy=nil
end
```

- 拷贝 shader 用 `abs(orient_rt_sampled_flip() - orient_rt_shown_flip())`：源被反转 XOR 拷贝被显示反转。
- `Step()` 需要方向图在请求之后重绘（`PaintedAfter`），最多等 60 帧；超时保留原图（不翻），日志 `[OrientedCopy] orientation map never painted`。
- 拷贝目标创建时 `SetViewport`，完成后立刻 `SetNumViewports(0)` 并释放场景/材质。
- **静态结果**：拷贝完成后不再每帧请求方向图，开销只有一次全屏 quad。
- `OrientedCopy.Retire` 在模板里是"立即 Dispose"。若项目 runtime 存在 RenderSurface 包装器比纹理活得久的问题，替换成项目自己的延迟释放（本仓库是 `render.RenderTargetLifetime`）。

---

## 接入后的自检

1. `require('render.OrientationSelfTest').Start()` 看一屏（见 `verification.md`）。
2. 日志确认 `[OrientationMap] orientation map ready api=...`，且没有 `unavailable`。
3. 逐个检查旧的写死翻转是否还在（`grep -rn "flip\|颠倒\|翻转" scripts`），删除它们，否则会与新机制叠加成双重翻转。
