shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;
uniform float age=0.0;
uniform float duration=0.24;
uniform vec4 tint : source_color = vec4(1.0,0.35,0.08,0.35);
varying vec3 local_position;
void vertex(){local_position=VERTEX;}
float hash21(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+vec2(1)),f.x),f.y);}
void fragment(){
 float t=clamp(age/duration,0.0,1.0);
 float n=noise(local_position.xy*12.0+vec2(age*5.0,-age*7.0));
 float rim=pow(1.0-abs(dot(normalize(NORMAL),normalize(VIEW))),1.4);
 float mask=smoothstep(t-0.06,t+0.12,n);
 ALBEDO=mix(tint.rgb,vec3(1.0,0.9,0.62),rim*0.75);
 EMISSION=tint.rgb*rim*0.7;
 ALPHA=mask*tint.a*(0.18+rim*0.82)*(1.0-t);
}
