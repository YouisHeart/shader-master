precision highp float;

uniform vec3 iResolution;
uniform float iTime;
uniform float iTimeDelta;
uniform float iFrameRate;
uniform int iFrame;
uniform float iChannelTime[4];
uniform vec3 iChannelResolution[4];
uniform vec4 iMouse;
uniform sampler2D iChannel0;
uniform sampler2D iChannel1;
uniform sampler2D iChannel2;
uniform sampler2D iChannel3;
uniform vec4 iDate;
uniform float iSampleRate;

varying vec2 vUv;

// ===== 原始代码开始 =====

int hexid;
vec3 hpos, point, pt;
float tcol, bcol, hitbol, hexpos, fparam=0.;

mat2 rot(float a) {
    float s=sin(a),c=cos(a);
    return mat2(c,s,-s,c);
}

vec3 path(float t) {
    return vec3(sin(t*.3+cos(t*.2)*.5)*4.,cos(t*.2)*3.,t);
}

float hexagon( in vec2 p, in float r )
{
    const vec3 k = vec3(-0.866025404,0.5,0.577350269);
    p = abs(p);
    p -= 2.0*min(dot(k.xy,p),0.0)*k.xy;
    p -= vec2(clamp(p.x, -k.z*r, k.z*r), r);
    return length(p)*sign(p.y);
}

float hex(vec2 p) {
    p.x *= 0.57735*2.0;
    p.y+=mod(floor(p.x),2.0)*0.5;
    p=abs((mod(p,1.0)-0.5));
    return abs(max(p.x*1.5 + p.y, p.y*2.0) - 1.0);
}

mat3 lookat(vec3 dir) {
    vec3 up=vec3(0.,1.,0.);
    vec3 rt=normalize(cross(dir,up));
    return mat3(rt, cross(rt,dir), dir);
}

float hash12(vec2 p)
{
    p*=1000.;
    vec3 p3  = fract(vec3(p.xyx) * .1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float sphereLineAB(vec3 p, vec3 a, vec3 b, float rad){
    p = normalize(p);
    return dot(p, cross(a, b))/length(a - b);
}

vec3 erot(vec3 p, vec3 ax, float ro) {
  return mix(dot(ax, p)*ax, p, cos(ro)) + sin(ro)*cross(ax, p);
}

#define PI 3.14159265359
#define PHI (1. + sqrt(5.))/2.

void icosahedronVerts(in vec3 p, out vec3 face, out vec3 a, out vec3 b, out vec3 c) {
    vec3 V = vec3(PHI, 1,  0);
    vec3 ap = abs(p), v = V;
    if (dot(ap, V.yzx - v) > 0.) v = V.yzx;
    if (dot(ap, V.zxy - v) > 0.) v = V.zxy;
    a = normalize(v)*sign(p);

    v = V.xxx;
    V = vec3(V.zy, V.x + V.y);
    if (dot(ap, V - v) > 0.) v = V;
    if (dot(ap, V.yzx - v) > 0.) v = V.yzx;
    if (dot(ap, V.zxy - v) > 0.) v = V.zxy;
    face = normalize(v)*sign(p);

    float r = PI*2./3.;
    b = erot(a, face, -r);
    c = erot(a, face, r);
}

float de(vec3 p) {
    pt=vec3(p.xy-path(p.z).xy,p.z);
    float h=abs(hexagon(pt.xy,3.+fparam));
    hexpos=hex(pt.yz);
    tcol=smoothstep(.0,.15,hexpos);
    h-=tcol*.1;

    vec3 pp=p-hpos;
    pp=lookat(point)*pp;
    pp.y-=abs(sin(iTime))*3.+(fparam-(2.-fparam));
    pp.yz*=rot(-iTime);

    float bola=length(pp)-1.;

    if(length(pp)<1.5){
        vec3 face;
        vec3[3] v;
        icosahedronVerts(pp, face, v[0], v[1], v[2]);
        float rad = 1.;

        vec3[6] mid;
        for(int i = 0; i<3; i++){
            mid[i*2] = mix(v[i], v[(i + 1)%3], 1./3.);
            mid[i*2 + 1] = mix(v[i], v[(i + 1)%3], 2./3.);
        }

        float poly = -1e5;
        for(int i = 0; i<6; i++){
           poly = max(poly, sphereLineAB(pp, mid[i], mid[(i + 1)%6], rad));
        }

        bcol = smoothstep(0., .05, abs(poly));
        bola += bcol*.1;
    }

    float d=min(h,bola);

    if (d==bola) {
        tcol=1.;
        hitbol=1.;
    } else {
        hitbol=0.;
        bcol=1.;
    }

    return d*.5;
}

vec3 normal(vec3 p) {
    vec2 e=vec2(0.,.005);
    return normalize(vec3(de(p+e.yxx),de(p+e.xyx),de(p+e.xxy))-de(p));
}

vec3 march(vec3 from, vec3 dir) {
    vec3 odir=dir;
    vec3 p=from,col=vec3(0.);
    float d,td=0.;
    vec3 g=vec3(0.);

    for (int i=0; i<200; i++) {
        d=de(p);
        if (d<.001||td>200.) break;
        p+=dir*d;
        td+=d;
        g+=.1/(.1+d)*hitbol*abs(normalize(point));
    }

    float hp=hexpos*(1.-hitbol);
    p-=dir*.01;
    vec3 n=normal(p);

    if (d<.001) {
        col=pow(max(0.,dot(-dir,n)),2.)*vec3(.6,.7,.8)*tcol*bcol;
    }

    col+=float(hexid);

    vec3 pr=pt;

    // ⭐⭐⭐ 关键：反射
    dir=reflect(dir,n);
    td=0.;

    for (int i=0; i<200; i++) {
        d=de(p);
        if (d<.001||td>200.) break;
        p+=dir*d;
        td+=d;
        g+=.1/(.1+d)*abs(normalize(point));
    }

    float zz=p.z;

    if (d<.001) {
        vec3 refcol=pow(max(0.,dot(-odir,n)),2.)*vec3(.6,.7,.8)*tcol*bcol;

        // ⭐⭐⭐ 分形细节（你左图发光关键）
        p=pr;
        p=abs(.5-fract(p*.1));
        float m=100.;
        for (int i=0; i<10; i++) {
            p=abs(p)/dot(p,p)-.8;
            m=min(m,length(p));
        }

        col=mix(col,refcol,m)-m*.3;

        // ⭐⭐⭐ 动态闪烁
        col+=step(.3,hp)*step(.9,fract(pr.z*.05+iTime*.5+hp*.1))*.7;
        col+=step(.3,hexpos)*step(.9,fract(zz*.05+iTime+hexpos*.1))*.3;
    }

    col+=g*.03;

    // ⭐⭐⭐ 色彩旋转
    col.rb*=rot(odir.y*.5);

    return col;
}

// ===== Shadertoy入口 =====
void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord/iResolution.xy-.5;
    uv.x*=iResolution.x/iResolution.y;

    float t=iTime*2.;
    vec3 from=path(t);

    hpos=path(t+3.);
    vec3 adv=path(t+2.);

    vec3 dir=normalize(vec3(uv,.7));
    vec3 dd=normalize(adv-from);

    point=normalize(adv-hpos);
    dir=lookat(dd)*dir;

    vec3 col = march(from, dir);
    col*=vec3(1.,.9,.8);

    fragColor = vec4(col,1.0);
}

// ===== Three.js入口 =====
void main() {
    mainImage(gl_FragColor, gl_FragCoord.xy);
}