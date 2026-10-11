shader_type spatial;
render_mode unshaded, cull_front;
uniform float thickness = 0.004;
void vertex() {
    VERTEX += NORMAL * thickness;
}
void fragment() {
    ALBEDO = vec3(0.025, 0.019, 0.028);
}
