// Density/emission ported from three/src/parts/thrusterFx.js.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_front, fog_disabled;
#include "Volume.shaderinc"
void fragment() {
    vec3 ro=camera_local,rd=normalize(volume_local-ro);
    float raw=texture(scene_depth,SCREEN_UV).r;
    vec4 opaque=INV_PROJECTION_MATRIX*vec4(SCREEN_UV*2.0-1.0,raw,1.0);
    float sceneZ=-opaque.z/opaque.w;
    float surfaceZ=abs((VIEW_MATRIX*vec4(VERTEX,1.0)).z);
    vec2 interval=volume_interval(ro,rd,sceneZ/max(0.00001,surfaceZ)*length(volume_local-ro),volume_clip_plane,planar_clip_active(VIEW_MATRIX,IN_SHADOW_PASS));
    if(interval.y<=interval.x)discard;
    float steps=settings.w,ds=(interval.y-interval.x)/steps;
    float metric=length(rd*vec3(2.0,2.0,settings.z));
    vec3 light=vec3(0.0);float trans=1.0;
    for(int i=0;i<40;i++) {
        if(float(i)>=steps)break;
        vec3 p=ro+rd*(interval.x+(float(i)+0.5)*ds);
        float z=p.z+0.5;vec2 xy=p.xy*2.0;
        float twist=z*8.0-clock*3.0+settings.y*23.0;
        xy+=vec2(sin(twist),cos(twist*1.3))*0.025*z;
        float n=textureLod(flow_map,xy*0.43+vec2(z*0.61-clock*0.9,settings.y+z*0.23-clock*0.27),0.0).r;
        float r=length(xy),width=(0.91*(1.0-pow(z,0.9))+0.02)*mix(0.97,1.03,n);
        float edge=1.0-smoothstep(width*0.78,width,r);
        float taper=(1.0-smoothstep(0.72,1.0,z))*smoothstep(0.0,0.015,z);
        float density=edge*(0.78+0.16*n)*taper;
        float mw=0.86*pow(max(0.0,1.0-z/0.89),0.85);
        float mainFlame=(1.0-smoothstep(mw*0.72,max(0.001,mw),r))*step(z,0.89);
        float cw=0.48*pow(max(0.0,1.0-z/0.65),0.72);
        float hot=(1.0-smoothstep(cw*0.7,max(0.001,cw),r))*step(z,0.65);
        float shock=pow(max(0.0,cos(z*32.0-0.4)),14.0)*exp(-pow(r/max(0.035,width*0.55),2.0)*2.0)*(1.0-z);
        vec3 emission=vec3(0.012,0.16,1.0)*density+vec3(0.008,0.7,1.35)*mainFlame*taper+vec3(1.15,1.5,1.7)*(hot+shock*0.09)*taper;
        light+=trans*emission*ds*metric*1.35;trans*=exp(-density*ds*metric*0.7);
    }
    ALBEDO=light*settings.x;ALPHA=1.0;
}
