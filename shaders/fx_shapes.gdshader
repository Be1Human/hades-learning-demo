shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;

uniform float age = 0.0;
uniform float duration = 0.4;
uniform int shape = 0;
uniform vec4 tint : source_color = vec4(1.0);
uniform bool face_camera = false;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float noise(vec2 p) {
    vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);
}
void vertex() {
    if(face_camera) {
        vec3 scaling=vec3(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz),length(MODEL_MATRIX[2].xyz));
        MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);
        VERTEX*=scaling;
    }
}
float fbm(vec2 p){return noise(p)*0.57+noise(p*2.03+17.1)*0.28+noise(p*4.11+9.2)*0.15;}
void fragment() {
 vec2 p=UV*2.0-1.0;
 float t=clamp(age/duration,0.0,1.0),r=length(p),a=atan(p.y,p.x);
 float n=fbm(p*4.5+vec2(age*2.5,-age*3.5));
 float mask=0.0,core=0.0;
 float fade=1.0-smoothstep(0.22,1.0,t);
 if(shape==0){
  float grow=0.65+0.35*(1.0-pow(1.0-t,4.0));
  float rays=pow(abs(cos(a*2.0+0.4)),20.0)*0.53+pow(max(cos(a*5.0-0.7),0.0),28.0)*0.25;
  float boundary=(0.12+rays)*grow;
  mask=1.0-smoothstep(boundary-0.025,boundary+0.018,r+(n-0.5)*0.065);
  mask*=smoothstep(t*0.7,t*0.7+0.20,n+0.22);
  core=exp(-r*r*38.0);
 }else if(shape==1){
  vec2 q=vec2(cos(a),sin(a))*3.7;
  float flow=fbm(q+vec2(age*2.3,age*0.9));
  float radius=mix(0.12,0.88,1.0-pow(1.0-t,3.0));
  float distance_to_front=abs(r-radius+(flow-0.5)*0.10);
  float w=mix(0.12,0.025,t);
  mask=1.0-smoothstep(w*0.12,w,distance_to_front);
  mask*=smoothstep(0.18+t*0.55,0.38+t*0.55,flow);
  core=exp(-distance_to_front*70.0);
 }else if(shape==2){
  vec2 q=p*2.5+vec2(age*0.65,-age*1.6);
  vec2 warp=vec2(fbm(q),fbm(q+8.3));
  float f=fbm(q+warp*2.2);
  float radius=mix(0.34,0.79,1.0-pow(1.0-t,2.0));
  float density=radius-length(p*vec2(0.9,1.1))+(f-0.5)*0.58;
  mask=smoothstep(0.0,0.18,density)*smoothstep(0.0,0.07,t);
  mask*=smoothstep(t*0.56,t*0.56+0.25,f);
  fade=1.0-smoothstep(0.40,1.0,t);core=0.0;
 }else if(shape==3){
  float y=1.0-UV.y;
  vec2 q=vec2(p.x*3.4,y*4.0-age*2.0);
  float f=fbm(q+vec2(fbm(q+4.3),fbm(q+15.0))*1.8);
  float body=1.0-abs(p.x+sin(y*5.0-age*3.0)*0.15)/mix(0.6,0.06,y);
  float field=body+(f-0.5)*1.6-smoothstep(0.48,1.0,t)*0.85;
  mask=smoothstep(0.04,0.20,field)*smoothstep(0.0,0.1,y)*(1.0-smoothstep(0.8,1.0,y));
  core=1.0-smoothstep(0.12,0.4,abs(field-0.15));fade=1.0-smoothstep(0.8,1.0,t);
 }else if(shape==4){
  float turn=a+age*3.0;
  float radius=0.56+0.12*sin(turn*3.0+1.5);
  float w=0.038+0.055*pow(max(cos(turn*3.0),0.0),3.0);
  mask=(1.0-smoothstep(w*0.35,w,abs(r-radius)))*smoothstep(-0.5,0.3,sin(turn*3.0));
  mask=max(mask,exp(-r*r*35.0)*0.8);
  mask*=smoothstep(t*0.42,t*0.42+0.18,n);
  core=exp(-r*r*24.0);fade=1.0-smoothstep(0.76,1.0,t);
 }else if(shape==5){
  float swirl=fbm(vec2(cos(a)*2.8,sin(a)*2.8)+vec2(age*2.0,-age*2.8));
  float edge=0.42+(swirl-0.5)*0.36;
  mask=(1.0-smoothstep(edge*0.38,edge,r))*0.85;
  core=exp(-r*r*45.0);fade=1.0;
 }else if(shape==6){
  float f=fbm(vec2(cos(a)*4.0,sin(a)*4.0)+vec2(age*3.0,age));
  float front=0.20+0.64*(1.0-pow(1.0-t,2.4));
  float edge=front+sin(a*7.0+f*3.0)*0.045;
  float distance_to_front=abs(r-edge+(f-0.5)*0.09);
  mask=1.0-smoothstep(0.035,0.17*(1.0-t)+0.035,distance_to_front);
  mask*=smoothstep(0.20+t*0.4,0.42+t*0.4,f);
  core=smoothstep(0.48,0.7,f)*smoothstep(edge-0.12,edge,r);
 }else{
  float y=p.y;
  float center=0.14*sin(y*2.6+0.6);
  float width=0.27*pow(max(0.0,1.0-y*y),1.5);
  mask=(1.0-smoothstep(width*0.7,width+0.012,abs(p.x-center)))*(1.0-smoothstep(0.8,1.0,abs(y)));
  mask*=smoothstep(t*0.6,t*0.6+0.18,n);
  core=exp(-abs(p.x-center)*30.0);
 }
 ALBEDO=mix(tint.rgb,vec3(1.0,0.97,0.84),core*(shape==2?0.0:0.78));
 EMISSION=tint.rgb*core*(shape==2?0.0:0.65);
 ALPHA=clamp(mask*fade*tint.a,0.0,1.0);
}
