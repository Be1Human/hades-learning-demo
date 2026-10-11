shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;
uniform float progress=0.0;
uniform float reach=2.45;
uniform bool lane=false;
varying vec2 local_ground;
void vertex(){local_ground=VERTEX.xz;}
void fragment(){
 float r=lane ? local_ground.y/reach : length(local_ground)/reach;
 float filled=1.0-smoothstep(progress-0.015,progress+0.015,r);
 float front=1.0-smoothstep(0.0,0.025,abs(r-progress));
 float hatch=0.5+0.5*sin((local_ground.x+local_ground.y)*22.0-progress*7.0);
 vec3 col=mix(vec3(0.48,0.035,0.025),vec3(1.0,0.39,0.08),front);
 ALBEDO=col;EMISSION=col*front*0.35;
 ALPHA=0.055+filled*(0.10+hatch*0.065)+front*0.32;
}
