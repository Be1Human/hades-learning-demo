shader_type canvas_item;
// Altered implementation inspired by pmndrs/postprocessing's shock-wave.frag.
// Original copyright 2015 Raoul van Ruschen, zlib license reproduced at
// evidence/fx-r04/research/pmndrs-LICENSE.md. This is a Godot adaptation.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float age=0.0;
uniform vec2 center=vec2(0.5);
void fragment() {
    vec2 uv=SCREEN_UV;
    float aspect=SCREEN_PIXEL_SIZE.y/SCREEN_PIXEL_SIZE.x;
    vec2 delta=(uv-center)*vec2(aspect,1.0);
    float d=length(delta);
    float t=clamp((age-0.30)/0.56,0.0,1.0);
    float radius=0.02+0.48*(1.0-pow(1.0-t,2.0));
    float band=abs(d-radius)/0.055;
    float envelope=(1.0-smoothstep(0.0,1.0,band))*(1.0-t);
    float active=step(0.30,age)*(1.0-step(0.86,age));
    uv-=delta/max(d,0.0001)/vec2(aspect,1.0)*envelope*0.009*active;
    vec3 scene=texture(screen_texture,clamp(uv,vec2(0.001),vec2(0.999))).rgb;
    float focus=smoothstep(0.0,0.08,age)*(1.0-smoothstep(0.27,0.70,age));
    float edge=smoothstep(0.12,0.78,d);
    scene=mix(scene,scene*vec3(0.33,0.18,0.27),edge*focus*0.72);
    float flash=smoothstep(0.30,0.32,age)*(1.0-smoothstep(0.32,0.42,age));
    scene+=vec3(1.0,0.86,0.60)*exp(-d*d*30.0)*flash*0.17;
    COLOR=vec4(scene,1.0);
}
