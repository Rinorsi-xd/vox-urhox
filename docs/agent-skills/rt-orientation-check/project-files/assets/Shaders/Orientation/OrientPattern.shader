// render.OrientationSelfTest source content: red top, blue bottom, green top-left
// square (detects horizontal mirrors too). UV v=0 is the quad's top vertex.
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
void fragment() {
    float top=step(0.5,1.0-UV.y);
    vec3 c=mix(vec3(0.0,0.0,1.0),vec3(1.0,0.0,0.0),top);
    float corner=step(UV.x,0.25)*step(UV.y,0.25);
    ALBEDO=mix(c,vec3(0.0,1.0,0.0),corner);
}
