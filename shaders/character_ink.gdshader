shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;
uniform float outline_pixels : hint_range(0.0, 3.0) = 0.85;
void vertex() {
    vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
    vec3 n = normalize(MODELVIEW_NORMAL_MATRIX * NORMAL);
    vec2 direction = (PROJECTION_MATRIX * vec4(n, 0.0)).xy;
    float length_xy = length(direction);
    if (length_xy > 0.001) {
        clip.xy += direction / length_xy * (2.0 * outline_pixels / VIEWPORT_SIZE) * clip.w;
    }
    POSITION = clip;
}
void fragment() {
    ALBEDO = vec3(0.008, 0.006, 0.016);
}
