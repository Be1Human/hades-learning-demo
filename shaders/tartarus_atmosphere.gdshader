shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform vec4 tint : source_color = vec4(0.18, 0.6, 0.34, 0.1);
uniform bool shaft = false;
uniform float phase = 0.0;
void fragment() {
    vec2 p=UV*2.0-1.0;
    float mask;
    if (shaft) {
        float width=mix(.12,.92,UV.y);
        mask=(1.0-smoothstep(width*.3,width,abs(p.x)));
        mask*=sin(UV.y*3.14159)*(.75+.25*sin(UV.x*56.0+phase));
    } else {
        float drift=sin(p.x*7.0+p.y*5.0+TIME*.32+phase)*.13;
        mask=1.0-smoothstep(.25,1.0,length(p)+drift);
        mask*=.65+.35*sin(p.x*11.0-p.y*6.0-TIME*.24+phase);
    }
    ALBEDO=tint.rgb;
    EMISSION=tint.rgb*.5;
    ALPHA=max(mask,0.0)*tint.a;
}
