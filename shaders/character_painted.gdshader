shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
uniform sampler2D albedo_texture : source_color;
uniform bool use_texture = true;
uniform vec4 base_tint : source_color = vec4(1.0);
uniform float readability_light : hint_range(0.0, 1.0) = 0.3;
uniform float paint_exposure : hint_range(0.5, 2.0) = 1.05;
uniform float texture_simplification : hint_range(0.0, 1.0) = 0.22;
void fragment() {
    vec3 paint = base_tint.rgb;
    if (use_texture) { paint *= texture(albedo_texture, UV, 1.15).rgb; }
    // Collapse small texture value changes into painted masses, preserving hue.
    float value = max(dot(paint, vec3(0.2126, 0.7152, 0.0722)), 0.001);
    float level = floor(value * 6.0);
    float edge = max(fwidth(value * 6.0), 0.025);
    float poster = (level + smoothstep(0.48-edge, 0.48+edge, fract(value*6.0))) / 6.0;
    paint *= mix(1.0, max(poster, 0.025) / value, texture_simplification);
    // Do not bake a second fixed light direction into the texture: it fights the
    // actual cast shadows and turns the skin grey when the actor turns.
    ALBEDO = clamp(mix(vec3(value),paint,1.12)*paint_exposure,vec3(0.0),vec3(1.0));
    // Preserve authored skin/cloth color in a dark room, as a painted character
    // readability floor. Nearby lights still add their diffuse, attenuated tint.
    EMISSION = ALBEDO * readability_light;
    ROUGHNESS = 0.92;
}
void light() {
    float ndl = dot(NORMAL, LIGHT);
    float planes = 0.06 + 0.48 * smoothstep(0.02, 0.06, ndl)
        + 0.46 * smoothstep(0.54, 0.59, ndl);
    // Most illumination is a broad diffuse response; painted texture carries the
    // graphic forms instead of turning every nearby lamp into a hard band.
    planes=mix(max(ndl,0.0),planes,.22);
    // A narrow light-facing rim, not a permanent luminous silhouette.
    float rim = smoothstep(0.65, 0.84, 1.0-max(dot(NORMAL, VIEW),0.0));
    rim *= smoothstep(0.08, 0.3, ndl) * 0.22;
    vec3 incident = LIGHT_COLOR * ATTENUATION;
    float intensity = dot(incident, vec3(0.2126, 0.7152, 0.0722));
    incident /= 1.0 + max(intensity-3.0, 0.0)*0.5;
    DIFFUSE_LIGHT += incident * (planes + rim) / 3.14159265;
}
