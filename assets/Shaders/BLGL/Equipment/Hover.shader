shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_front, fog_disabled;
#include "Volume.shaderinc"
void fragment() {
    vec3 ro=camera_local,rd=normalize(volume_local-ro);
    float raw=texture(scene_depth,SCREEN_UV).r;
    vec4 opaque=INV_PROJECTION_MATRIX*vec4(SCREEN_UV*2.0-1.0,raw,1.0);
    float sceneZ=-opaque.z/opaque.w;
    float surfaceZ=abs((VIEW_MATRIX*vec4(VERTEX,1.0)).z);
    vec2 interval=volume_interval(ro,rd,sceneZ/max(0.00001,surfaceZ)*length(volume_local-ro),volume_clip_plane,planar_clip_active(VIEW_MATRIX,IN_SHADOW_PASS));if(interval.y<=interval.x)discard;
    float steps=settings.w,ds=(interval.y-interval.x)/steps;
    float metric=length(rd*vec3(2.0,1.0,2.0));
    vec3 light=vec3(0.0);float trans=1.0;
    for(int i=0;i<16;i++) {
        if(float(i)>=steps)break;
        vec3 p=(ro+rd*(interval.x+(float(i)+0.5)*ds))*vec3(2.0,1.0,2.0);
        float y=p.y+0.5;
        float n=textureLod(flow_map,p.xz*0.35+vec2(y*0.26-clock*0.09,y*0.4-clock*0.13),0.0).r;
        float width=0.62+0.23*(1.0-y),r=length(p.xz)/width;
        float ends=smoothstep(0.0,0.1,y)*(1.0-smoothstep(0.89,1.0,y));
        float edge=1.0-smoothstep(0.72,1.35,r);
        float cloud=exp(-r*r*2.3)*(0.72+0.28*n),core=exp(-r*r*17.0)*(0.65+0.35*n);
        float wave=pow(0.5+0.5*sin(y*17.0+clock*2.5+n*2.0),6.0)*0.13;
        float density=(cloud*0.55+core*0.75)*edge*ends;
        vec3 emission=(vec3(0.018,0.28,0.82)*cloud+vec3(0.24,0.86,1.25)*core+vec3(0.05,0.45,0.8)*wave*cloud)*edge*ends;
        light+=trans*emission*ds*metric*1.15;trans*=exp(-density*ds*metric*0.75);
    }
    ALBEDO=light*settings.x;ALPHA=1.0;
}
