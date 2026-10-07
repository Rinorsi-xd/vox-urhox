// Source three/src/drive/trackView.js skyMaterial; X mirrored at engine boundary.
shader_type spatial;
render_mode unshaded, cull_front, fog_disabled, depth_draw_never;
varying vec3 sky_direction;
void vertex() { sky_direction = VERTEX; }
void fragment() {
    vec3 d = normalize(sky_direction);
    vec3 zen = vec3(0.05,0.15,0.42), hor = vec3(0.36,0.46,0.6), gnd = vec3(0.16,0.15,0.14);
    vec3 c = d.y > 0.0 ? mix(hor,zen,pow(d.y,0.45)) : mix(hor,gnd,pow(-d.y,0.35));
    float s = max(dot(d,normalize(vec3(-0.45,0.78,0.38))),0.0);
    ALBEDO = c + vec3(1.0,0.86,0.66) * (pow(s,1200.0)*40.0+pow(s,10.0)*0.22);
}
