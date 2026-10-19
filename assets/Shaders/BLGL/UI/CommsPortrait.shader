// Port of the frozen HoloPortrait fragment; px remains in source CSS pixels.
shader_type spatial;
render_mode shading_model_unlit, blend_mix, cull_disabled, depth_draw_never, fog_disabled;
uniform sampler2D face_map : filter_linear, repeat_disable;
uniform sampler2D mouth_map : filter_linear, repeat_disable;
uniform vec4 mouth_rect = vec4(0.431, 0.3025, 0.5172, 0.3646);
uniform vec2 canvas_size = vec2(330.0, 410.0);
uniform vec2 image_scale = vec2(1.0);
uniform vec2 image_offset = vec2(0.0);
uniform vec3 holo_tint = vec3(0.35, 0.85, 1.0);
uniform float clock = 0.0;
uniform float glitch = 0.0;
uniform float mouth_on = 0.0;
uniform float opaque_rgb = 0.0;
// Orientation probe: output the fitted source texel unmodified.
uniform float probe = 0.0;

float h1(float n) { return fract(sin(n * 12.9898) * 43758.5453); }
float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float inside(vec2 uv) { return step(0.0,uv.x)*step(uv.x,1.0)*step(0.0,uv.y)*step(uv.y,1.0); }
float alpha_at(vec2 uv) { return texture(face_map,uv).a*inside(uv); }
vec4 portrait(vec2 uv) {
    vec4 c=texture(face_map,uv);
    vec2 f=vec2(.01,.008);
    vec2 m=smoothstep(mouth_rect.xy,mouth_rect.xy+f,uv)*(1.0-smoothstep(mouth_rect.zw-f,mouth_rect.zw,uv));
    c=mix(c,texture(mouth_map,uv),m.x*m.y*mouth_on);
    c.rgb*=c.a;
    return c*inside(uv);
}
void fragment() {
    vec2 vp=vec2(UV.x,1.0-UV.y);
    vec2 px=vp*canvas_size;
    float t=clock,g=glitch;
    float row=floor(px.y/(4.0+36.0*h1(floor(t*9.0))));
    float tear=step(1.0-.45*g,h1(row+floor(t*24.0)*7.31))*g;
    float dx=(h1(row*3.7+floor(t*31.0))-.5)*.05*tear;
    float band=exp(-pow((vp.y-(1.15-fract(t*.14)*1.4))*16.0,2.0));
    dx+=band*.003*sin(px.y*.9+t*40.0)+sin(px.y*.045+t*2.3)*.0006;
    vec2 uv=(vp+vec2(dx,0.0)-image_offset)/image_scale;uv.y=1.0-uv.y;
    vec2 one_px=1.0/(image_scale*canvas_size);
    float ca=(1.2+5.0*g)*one_px.x;
    vec4 cg=portrait(uv),cr=portrait(uv+vec2(ca,0.0)),cb=portrait(uv-vec2(ca,0.0));
    vec3 col=vec3(cr.r,cg.g,cb.b);
    float a=max(cg.a,max(cr.a,cb.a));
    vec2 d=5.0*one_px;
    float n=(alpha_at(uv+vec2(d.x,0.0))+alpha_at(uv-vec2(d.x,0.0))+alpha_at(uv+vec2(0.0,d.y))+alpha_at(uv-vec2(0.0,d.y)))*.25;
    float rim=cg.a*clamp(1.0-n,0.0,1.0);
    col=mix(col,holo_tint*dot(col,vec3(.299,.587,.114)),.1);
    col+=holo_tint*(a*.035+rim*.55+band*a*.1);
    float sl=.5+.5*sin((px.y+t*14.0)*6.2832/3.0);
    col*=1.0-.16*sl;a*=1.0-.1*sl;
    col+=(h2(floor(px)+fract(t)*91.0)-.5)*.035*a;
    float fl=.96+.04*sin(t*47.0)*sin(t*13.7);
    fl*=1.0-.2*step(.985,h1(floor(t*15.0)));
    fl*=1.0-.25*g*h1(floor(t*40.0));
    float k=.94*fl*smoothstep(0.0,.12,vp.y);
    vec3 premul=min(max(col,vec3(0.0)),vec3(a))*k;
    float coverage=a*k;
    ALBEDO=mix(premul/max(coverage,.0001),premul,opaque_rgb);
    ALPHA=mix(coverage,1.0,opaque_rgb);
    if (probe > 0.5) {
        vec2 puv=(vp-image_offset)/image_scale;puv.y=1.0-puv.y;
        vec4 src=texture(face_map,puv);
        ALBEDO=mix(src.rgb,src.rgb*src.a,opaque_rgb);ALPHA=mix(src.a,1.0,opaque_rgb);
    }
}
