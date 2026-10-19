-- 渲染目标交给 NanoVG 画时，部分设备（手机 WebGL）会上下/左右颠倒。
-- portrait 由 ui.PortraitOrientation 实测并复核。scene 暂沿用立绘结果，
-- source=portrait-inferred 表示尚未单独验证场景后处理链；未测出时保持原方向。
local M={scene={x=1,y=1,source='default'}}
function M.Get(kind) return M[kind] or M.scene end
--- 用当前路径填一张 RT 图：只镜像图案，不镜像已建好的路径（漫画格的斜切形状保持原样）。
function M.Fill(vg,kind,image,x,y,w,h,alpha)
 local f=M.Get(kind)
 nvgSave(vg)
 if f.x~=1 or f.y~=1 then
  local cx,cy=x+w/2,y+h/2
  nvgTranslate(vg,cx,cy);nvgScale(vg,f.x,f.y);nvgTranslate(vg,-cx,-cy)
 end
 nvgFillPaint(vg,nvgImagePattern(vg,x,y,w,h,0,image,alpha or 1));nvgFill(vg)
 nvgRestore(vg)
end
return M
