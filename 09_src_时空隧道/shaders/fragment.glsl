precision highp float;

uniform vec3 iResolution;
uniform float iTime;
uniform float iTimeDelta;
uniform float iFrameRate;
uniform int iFrame;
uniform vec4 iMouse;
uniform vec4 iDate;

varying vec2 vUv;

#define T (sin(iTime*.6)*64.+iTime*2e2)
#define P(z) (vec3(cos((z)*.015)*16.+cos((z) * .006)  *64., \
                   cos((z)*.011)*24.+cos((z) * .009) * 32., (z)))
#define R(a) mat2(cos(a+vec4(0,33,11,0)))
#define N normalize

vec4 lights;

float boxen(vec3 p) {
    p = abs(fract(p/4e1)*4e1 - 2e1) - 2.;
    return min(p.x, min(p.y, p.z));
}

float map(vec3 p) {
    vec3 q = P(p.z);
    float m, g = q.y-p.y + 6.;

    m = boxen(p);
    p.xy -= q.xy;
    
    float red,blue;
    float e = min(red=length(p.xy -   sin(p.y / 12. + vec2(5., 1.))*12.) - 1.,
                  blue=length(p.xy -  sin(p.y / 12. + vec2(0, 1.))*12.) - 1.);  

    lights += vec4(2.,10.,10.,0.)/(.1+abs(red)/10.);
    lights += vec4(10.,2.,10.,0.)/(.1+abs(blue)/10.);

    p = abs(p);
    
    float tex = abs(length(sin(p*cos(p.yzx/30.)*4.)/(p*4.)));     
    float tun = min(64.-p.x - p.y + m, 32.-p.y - m);

    float d = max(min(m, g), tun)-tex;
    return min(e, d);
}

void main() {

    vec2 u = vUv * iResolution.xy;
    float i = 0.0, s, d = 0.0;

    vec3 r = iResolution;
    
    u = (u - r.xy * 0.5) / r.y;
    u.y -= .2;

    vec4 o = vec4(0.0);

    vec3 p = P(T), ro = p,
         Z = N(P(T+10.0) - p),
         X = N(vec3(Z.z,0.0,-Z.x)),
         D = N(vec3(R(sin(T*.005)*.4)*u, 1.0) 
           * mat3(-X, cross(X, Z), Z));

    for(int j=0;j<128;j++) {
        p = ro + D * d;
        s = map(p) * .8;
        d += s;
        o += lights + 1.0 / max(s, .01);
    }

    // normal
    const float h = 0.005;
    const vec2 k = vec2(1.,-1.);
    vec3 n = N(
        k.xyy*map( p + k.xyy*h ) + 
        k.yyx*map( p + k.yyx*h ) + 
        k.yxy*map( p + k.yxy*h ) + 
        k.xxx*map( p + k.xxx*h )
    );

    // diffuse
    o *= (.1 + max(dot(n, -D), 0.));

    // reflection
    vec4 ref = vec4(0.0);
    lights = vec4(0.0);

    for(int j=0;j<40;j++) {
        p += n*.05;
        D = reflect(D, n);
        s = map(p)*.8;
        p += D*s;
        ref += lights + 1.0/max(s,.01);
    }

    o += o * ref;
    o = tanh(o / 6e6 / d);

    gl_FragColor = o;
}