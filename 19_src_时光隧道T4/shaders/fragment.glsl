precision highp float;

uniform vec3 iResolution;
uniform float iTime;
uniform float iTimeDelta;
uniform float iFrameRate;
uniform int iFrame;
uniform vec4 iMouse;
uniform vec4 iDate;

varying vec2 vUv;

#define T (sin(iTime*.6)*16.+iTime*1e2)
#define P(z) (vec3(cos((z)*.011)*16.+cos((z) * .012)*24., \
                   cos((z)*.01)*4., (z)))
#define R(a) mat2(cos(a+vec4(0,33,11,0)))
#define N normalize

vec4 lights;

float boxen(vec3 p) {
    p = abs(fract(p/20.)*20. - 10.) - 1.;
    return min(p.x, min(p.y, p.z));
}

float map(vec3 p) {
    vec3 q = P(p.z);
    float m, g = q.y - p.y + 6.;

    m = boxen(p);
    p.xy -= q.xy;

    float red, blue;
    float e = min(
        red = length(p.xy - sin(p.z / 12. + vec2(0., 1.3)) * 12.) - 1.,
        blue = length(p.xy - sin(p.z / 16. + vec2(0., .7)) * 16.) - 2.
    );

    lights += vec4(10.,2.,1.,0.)/(.1+abs(red));
    lights += vec4(1.,2.,10.,0.)/(.1+abs(blue)/10.);

    p = abs(p);

    float tex = abs(length(sin(p*cos(p.yzx/30.)*4.)/(p*4.)));     
    float tun = min(32.-p.x - p.y, 24.-p.y);

    float d = max(min(m, g), tun) - tex;
    return min(e, d);
}

void main() {
    vec2 u = vUv * iResolution.xy;
    vec2 fragCoord = u;

    vec2 uv = (fragCoord - iResolution.xy * 0.5) / iResolution.y;
    uv.y -= 0.2;

    vec4 o = vec4(0.0);
    float i = 0.0, s = 0.0, d = 0.0;

    vec3 p = P(T);
    vec3 ro = p;

    vec3 Z = normalize(P(T+2.) - p);
    vec3 X = normalize(vec3(Z.z,0.,-Z.x));

    vec3 D = normalize(vec3(R(sin(T*.005)*.4)*uv, 1.0)
             * mat3(-X, cross(X, Z), Z));

    for(int j = 0; j < 100; j++) {
        p = ro + D * d;
        float dist = map(p) * 0.8;
        d += dist;
        o += lights + 1.0 / max(dist, 0.01);
    }

    // 法线
    float h = 0.005;
    vec2 k = vec2(1.0,-1.0);
    vec3 n = normalize(
        k.xyy*map(p + k.xyy*h) +
        k.yyx*map(p + k.yyx*h) +
        k.yxy*map(p + k.yxy*h) +
        k.xxx*map(p + k.xxx*h)
    );

    // 漫反射
    o *= (.1 + max(dot(n, -D), 0.));

    // 反射
    vec4 ref = vec4(0.0);
    lights = vec4(0.0);

    for(int j = 0; j < 50; j++) {
        p += n * 0.05;
        D = reflect(D, n);
        float dist = map(p) * 0.8;
        p += D * dist;
        ref += lights + 1.0 / max(dist, 0.01);
    }

    o += o * ref;

    o = tanh(o / 1e9 * exp(vec4(10.,2.,1.,0.) * d / 500.));

    gl_FragColor = o;
}