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
void fragment() {
    vec2 p=UV*2.0-1.0;
    float t=clamp(age/duration,0.0,1.0), r=length(p), a=atan(p.y,p.x);
    float n=noise(p*9.0+vec2(age*7.0,-age*11.0));
    float mask=0.0, core=0.0;
    float fade=1.0-smoothstep(0.45,1.0,t);
    if(shape==0) { // Impact: four long blades, shorter off-axis spikes and an opaque center.
        float boundary=0.18+0.60*pow(abs(cos(a*2.0)),18.0)+0.18*pow(abs(sin(a*4.0)),12.0);
        boundary*=mix(0.6,1.0,smoothstep(0.0,0.12,t));
        mask=1.0-smoothstep(boundary-0.035,boundary,r);
        core=1.0-smoothstep(0.08,0.4,r);
    } else if(shape==1) { // Ground blast: irregular expanding edge with a broken inner wake.
        float radius=mix(0.16,0.88,1.0-pow(1.0-t,3.0));
        float wave=r+(n-0.5)*0.055+sin(a*11.0)*0.025;
        float width=mix(0.21,0.035,t);
        mask=smoothstep(radius-width,radius-width+0.04,wave)*(1.0-smoothstep(radius-0.025,radius+0.01,wave));
        mask*=mix(1.0,smoothstep(0.19,0.5,n),t);
        core=smoothstep(radius-0.07,radius,wave);
    } else if(shape==2) { // Opaque ink smoke, never an additive luminous sphere.
        vec2 q=p/vec2(0.83,1.0);
        float edge=length(q)+(noise(p*4.0+vec2(0,-age*2.0))-0.5)*0.38;
        mask=(1.0-smoothstep(0.42,0.84,edge))*smoothstep(0.0,0.10,t);
        fade=1.0-smoothstep(0.28,1.0,t);
    } else if(shape==3) { // Tongues of flame; upper silhouette narrows and splits.
        float y=1.0-UV.y;
        float center=0.17*sin(y*8.0-age*14.0)+0.09*sin(y*19.0-age*9.0);
        float width=(0.06+0.40*(1.0-y))*(0.65+0.35*n);
        mask=(1.0-smoothstep(width*0.6,width,abs(p.x-center)))*smoothstep(0.0,0.10,y)*(1.0-smoothstep(0.78,1.0,y+n*0.15));
        core=(1.0-smoothstep(0.02,width*0.55,abs(p.x-center)))*(1.0-y);
        fade=1.0-smoothstep(0.88,1.0,t);
    } else if(shape==4) { // Spell seal with separated angular ticks.
        float outer=1.0-smoothstep(0.025,0.05,abs(r-0.72));
        float inner=1.0-smoothstep(0.015,0.035,abs(r-0.46));
        float spokes=pow(max(cos(a*8.0+age*2.0),0.0),32.0)*step(0.49,r)*step(r,0.88);
        mask=max(outer,max(inner*0.6,spokes));core=outer;
    } else if(shape==5) { // A projectile heart surrounded by a rough corona.
        mask=1.0-smoothstep(0.32,0.68,r+(n-0.5)*0.14);
        core=1.0-smoothstep(0.12,0.33,r);
        fade=1.0;
    } else if(shape==6) { // Low ground splash with separated crest tips.
        float edge=0.48+0.20*sin(a*7.0+t*2.0)+0.13*sin(a*13.0);
        mask=(1.0-smoothstep(edge-0.03,edge+0.015,r))*smoothstep(0.12,0.35,r);
        core=smoothstep(edge-0.12,edge,r);
    } else { // Tapered feather/leaf for defensive fragments.
        float width=0.24*pow(max(0.0,1.0-p.y*p.y),1.6);
        mask=(1.0-smoothstep(width-0.02,width+0.01,abs(p.x+0.10*p.y)))*step(abs(p.y),0.92);
        core=1.0-smoothstep(0.02,0.045,abs(p.x+0.10*p.y));
    }
    ALBEDO=mix(tint.rgb,vec3(1.0,0.96,0.82),core*0.88);
    EMISSION=tint.rgb*core*0.45;
    ALPHA=clamp(mask*fade*tint.a,0.0,1.0);
}
