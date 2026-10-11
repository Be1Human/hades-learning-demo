shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;
// R04: original implementation of advected noise, threshold erosion and life curves.
// Study notes and source attribution: docs/fx/webgl-study.html.
uniform float age = 0.0;
uniform float duration = 1.65;
uniform int layer = 0; // 0 rising veil, 1 ground wave, 2 soft ember, 3 ignition
uniform float seed = 0.0;
uniform bool face_camera = true;
uniform bool continuous = false;
uniform vec4 tint : source_color = vec4(0.16, 0.95, 0.61, 1.0);
float hash21(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
    vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+vec2(1)),f.x),f.y);
}
float fbm(vec2 p) { return noise(p)*0.57+noise(p*2.03+17.1)*0.28+noise(p*4.11+9.2)*0.15; }
void vertex() {
    if(face_camera) {
        vec3 s=vec3(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz),length(MODEL_MATRIX[2].xyz));
        MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);
        VERTEX*=s;
    }
}
void fragment() {
    vec2 p=UV*2.0-1.0;
    float t=clamp(age/duration,0.0,1.0);
    float mask=0.0, hot=0.0;
    vec3 col=tint.rgb;
    if(layer==0) {
        // Large drifting lobes deform the fine tongues, avoiding a waving straight line.
        float y=1.0-UV.y;
        vec2 q=vec2(p.x*2.7,y*3.8-age*1.9)+seed;
        vec2 warp=vec2(fbm(q+2.7),fbm(q+13.4))*1.5;
        float n=fbm(q+warp);
        float sway=0.21*sin(y*5.4-age*2.8+seed)+0.16*(fbm(q*0.6)-0.5);
        float width=mix(0.69,0.10,pow(y,0.8));
        float body=1.0-abs(p.x-sway)/width-y*0.32;
        float erosion=continuous ? 0.08 : smoothstep(0.42,1.0,t)*0.85;
        float field=body+(n-0.5)*1.5-erosion;
        mask=smoothstep(0.02,0.19,field)*smoothstep(0.0,0.09,y)*(1.0-smoothstep(0.82,1.0,y));
        if(!continuous) { mask*=smoothstep(0.0,0.09,t)*(1.0-smoothstep(0.84,1.0,t)); }
        hot=(1.0-smoothstep(0.14,0.40,abs(field-0.16)))*mask;
        col=mix(tint.rgb*0.48,tint.rgb,clamp(field,0.0,1.0));
        col=mix(col,vec3(0.84,1.0,0.69),hot*0.66);
        mask*=0.76;
    } else if(layer==1) {
        float r=length(p), a=atan(p.y,p.x);
        // Periodic angular coordinates avoid an atan seam in the noise field.
        vec2 q=vec2(cos(a),sin(a))*3.0;
        float n=fbm(q+age*1.3);
        float radius=mix(0.10,0.89,1.0-pow(1.0-t,3.0));
        float w=mix(0.095,0.018,t);
        float distance_to_front=abs(r-radius+(n-0.5)*0.09);
        mask=(1.0-smoothstep(w*0.15,w,distance_to_front));
        mask*=smoothstep(0.25+t*0.48,0.43+t*0.48,n)*(1.0-smoothstep(0.3,1.0,t));
        hot=pow(max(0.0,1.0-distance_to_front/max(w,0.001)),4.0);
        col=mix(tint.rgb,vec3(1.0,0.98,0.78),hot*0.8);
    } else if(layer==2) {
        float d=length(p*vec2(1.0,0.8));
        mask=(1.0-smoothstep(0.04,0.9,d))*smoothstep(0.0,0.12,t)*(1.0-smoothstep(0.40,1.0,t));
        hot=exp(-d*7.0);
        col=mix(tint.rgb,vec3(1.0,0.98,0.82),hot);
    } else {
        float r=length(p), a=atan(p.y,p.x);
        float flare=exp(-r*5.0)*(0.3+0.7*pow(abs(cos(a*3.0+0.6)),12.0));
        mask=(exp(-r*r*22.0)+flare)*(1.0-pow(t,0.45));
        hot=1.0; col=mix(tint.rgb,vec3(1.0,0.99,0.87),exp(-r*4.0));
    }
    ALBEDO=col;
    EMISSION=col*hot*0.8;
    ALPHA=clamp(mask*tint.a,0.0,1.0);
}
