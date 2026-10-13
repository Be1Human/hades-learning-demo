shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

// Authored vertex colors carry bone planes, cracks and soot; actual room lamps
// supply attenuated colored illumination. This is not a fixed baked key light.
uniform vec4 base_tint : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color;
uniform bool use_texture = false;
uniform float paint_exposure : hint_range(0.5, 1.5) = 1.04;
uniform float readability_light : hint_range(0.0, 0.4) = 0.18;
uniform float ink_strength : hint_range(0.0, 0.5) = 0.18;
uniform float emission_strength : hint_range(0.0, 3.0) = 0.0;
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 0.72, 0.40, 1.0);

void fragment() {
    vec3 paint = COLOR.rgb * base_tint.rgb;
    if (use_texture) {
        paint *= texture(albedo_texture, UV).rgb;
    }
    paint = clamp(paint * paint_exposure, vec3(0.0), vec3(1.0));
    float edge = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 3.5);
    // Gentle interior edge ink is complemented by a sub-pixel outline pass.
    paint *= 1.0 - edge * ink_strength;
    ALBEDO = mix(paint, flash_color.rgb, flash_amount * 0.54);
    EMISSION = paint * (readability_light + emission_strength)
        + flash_color.rgb * flash_amount * 0.18;
    ROUGHNESS = 0.92;
    METALLIC = 0.0;
}

void light() {
    float ndl = max(dot(NORMAL, LIGHT), 0.0);
    // Preserve broad painted facets with only a restrained light-facing lift.
    float planes = 0.07 + 0.48 * smoothstep(0.03, 0.10, ndl)
        + 0.45 * smoothstep(0.56, 0.67, ndl);
    float diffuse = mix(ndl, planes, 0.18);
    float facing_edge = smoothstep(0.70, 0.91, 1.0 - max(dot(NORMAL, VIEW), 0.0));
    float matte_highlight = facing_edge * smoothstep(0.28, 0.65, ndl) * 0.035;
    vec3 incident = LIGHT_COLOR * ATTENUATION;
    float intensity = dot(incident, vec3(0.2126, 0.7152, 0.0722));
    incident /= 1.0 + max(intensity - 3.0, 0.0) * 0.45;
    DIFFUSE_LIGHT += incident * (diffuse + matte_highlight) / 3.14159265;
}
