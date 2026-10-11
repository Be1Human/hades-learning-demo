shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform float phase = 0.0;
uniform float intensity = 1.0;
void fragment(){
 float h=clamp(1.0-UV.y,0.0,1.0);
 float clock=TIME*1.15+phase;
 float center=.5+sin(h*7.5-clock)*(.05+h*.19);
 float width=mix(.36,.018,h)*(1.0+.18*sin(h*19.0-clock*1.7));
 float d=abs(UV.x-center);
 float edge=max(fwidth(d)*1.2,.009);
 float body=1.0-smoothstep(width-edge,width+edge,d);
 float inner=1.0-smoothstep(width*.35,width*.47,d);
 float curl=sin(h*12.0-clock*1.4);
 float hollow=inner*smoothstep(.24,.65,h)*smoothstep(-.4,.4,curl);
 float ribbon=max(body-hollow*.82,0.0);
 float core=(1.0-smoothstep(.04,.15,d))*(1.0-smoothstep(.06,.43,h));
 vec3 color=mix(vec3(.015,.32,.17),vec3(.12,.8,.47),step(.5,ribbon));
 color=mix(color,vec3(.65,1.0,.27),core);
 ALBEDO=color;
 EMISSION=color*(.65+core*1.8)*intensity;
 float taper=smoothstep(0.0,.07,h)*(1.0-smoothstep(.73,1.0,h));
 ALPHA=clamp((ribbon*.49+core*.28)*taper*intensity,0.0,.82);
}
