shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;
// R05: flow and erosion on an authored world-space ribbon. No wall-clock TIME.
uniform float age=0.0;
uniform float duration=0.4;
uniform vec4 tint : source_color = vec4(1.0);
uniform int style=0; // blade, water, lightning, ward, smoke streak
uniform float seed=0.0;
float hash21(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+vec2(1)),f.x),f.y);}
void fragment(){
 float t=clamp(age/duration,0.0,1.0),u=UV.x,v=abs(UV.y*2.0-1.0);
 float n=noise(vec2(u*11.0-age*5.0+seed,UV.y*4.0));
 float fine=noise(vec2(u*25.0-age*8.0,UV.y*15.0+seed));
 float head=smoothstep(0.0,0.15,t),tail=smoothstep(0.16,1.0,t);
 float taper=pow(max(sin(u*3.14159265),0.0),0.45);
 float width=taper*(0.83+0.17*n);
 float mask=(1.0-smoothstep(width*0.68,width,v))*(1.0-smoothstep(head-0.045,head+0.01,u));
 float erosion=u+0.22*(n-0.5)+(1.0-v)*0.1;
 mask*=smoothstep(tail-0.12,tail+0.06,erosion);
 float core=exp(-v*v*18.0);
 vec3 col=mix(tint.rgb*0.65,vec3(1.0,0.97,0.82),core*0.93);
 if(style==1){
  float foam=noise(vec2(u*22.0-age*6.0,UV.y*9.0));
  core=smoothstep(0.5,0.77,foam)*(0.35+0.65*v);
  col=mix(tint.rgb*0.5,vec3(0.82,1.0,0.95),core);
  mask*=smoothstep(tail*0.62,tail*0.62+0.18,n);
 }else if(style==2){
  mask=(1.0-smoothstep(0.1,0.95,v))*(0.85+0.15*sin(age*80.0));
  mask*=1.0-smoothstep(0.25,1.0,t);core=exp(-v*6.0);
  col=mix(tint.rgb,vec3(1.0),core);
 }else if(style==3){
  mask*=smoothstep(tail*0.5,tail*0.5+0.2,fine);
  col=mix(tint.rgb,vec3(1.0,0.99,0.85),core*0.7);
 }else if(style==4){
  mask*=n*0.65;core=0.0;col=tint.rgb;
 }
 ALBEDO=col;EMISSION=col*core*(style==2?1.5:0.5);
 ALPHA=clamp(mask*tint.a*(1.0-smoothstep(0.82,1.0,t)),0.0,1.0);
}
