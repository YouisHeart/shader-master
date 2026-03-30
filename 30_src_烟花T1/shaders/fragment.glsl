// fragment.glsl
precision highp float;

uniform vec3 iResolution;
uniform float iTime;
uniform vec4 iMouse;

varying vec2 vUv;

#define s(a, b, t) smoothstep(a, b, t)
#define g -9.81

float distLine(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float t = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * t);
}

float line(vec2 uv, vec2 a, vec2 b, float w) {
    return w / distLine(uv, a, b);
}

float N21(vec2 p) {
    p = fract(p * vec2(233.34, 851.73));
    p += dot(p, p + 23.45);
    return fract(p.x * p.y);
}

vec2 N22(vec2 p) {
    float n = N21(p);
    return vec2(n, N21(p + n));
}

float N11(float n) {
    return fract(sin(dot(vec2(cos(n), sin(n)) ,vec2(27.9898, 38.233))) * 88.5453);
}

float particle(vec2 uv, vec2 p, vec2 v, float r, float t) {
    float x = p.x + v.x * t;
    float y = p.y + v.y * t + g / 2.0 * t * t;
    vec2 j = (vec2(x, y) - uv) * 20.0;
    float sparkle = 1.0 / dot(j, j);
    return sparkle;
}

vec2 p1(vec2 p, float h, float t) {
    return vec2(p.x, p.y + clamp(pow(t, 5.0), 0.0, h));
}

vec2 p2(vec2 p, float h, float t) {
    return vec2(p.x, p.y + clamp(pow(0.95 * t, 5.0), 0.0, h));
}

float endTime(float h) {
    return pow(h, 1.0 / 5.0) * 1.1;
}

float seed = 0.32;

float explosion(vec2 uv, vec2 p, float s, float n, float f, float t) {
    float m = 0.0;
    float dt = 0.5;
    for(float i = 0.0; i < n; i++) {
        seed += i;
        vec2 rand = vec2(1.0, 2.0) * (vec2(-1.0, 1.0) + 2.0 * N22(vec2(seed, i)));
        vec2 v = vec2(cos(seed), sin(seed)) + rand;
        m += particle(uv, p, v, s, t)
            * s(2.0, 2.0 - dt, t)
            * s(0.0, dt, t);
    }   
    return m;
}

float fireworks(vec2 uv, vec2 p, float h, float n, float s, float f, float t) {
    vec2 p_ = p1(p, h, t);
    float e = endTime(h);
    return explosion(uv, p_, s, n, f, t - e * 0.9);
}

float shaft(vec2 uv, vec2 p, float w, float h, float t) {
    vec2 p_1 = p1(p, h, t) + vec2(0.0, 0.3);
    vec2 p_2 = p2(p, h, t);
    float e = 1.0 / 0.95 * endTime(h);
    vec2 j = (p_1 - uv) * 15.0;
    float sparkle = 1.0 / dot(j, j);
    return (line(uv, p_1, p_2, w) + sparkle) * s(e, e - 0.5, t) * 0.5;
}

vec3 base(vec2 uv) {
    return 0.5 + 0.5 * cos(iTime + uv.xyx + vec3(0.0, 2.0, 4.0));   
}

float back(vec2 uv, vec2 p, float t) {
    float dt = 0.3;
    float j = length(p - uv);
    float m = exp(-0.005 * j * j);
    return 0.2 * m * s(-dt / 4.0, 0.0, t) * s(dt, 0.0, t);
}

float stars(vec2 uv) {
    float r = N21(uv);
    return s(0.001, 0.0, r);
}

void main() {
    vec2 fragCoord = vUv * iResolution.xy;
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    float t = iTime / 10.0;
    float scale = 10.0;
    uv *= scale;
    vec3 col = vec3(0.05 + stars(uv));
    
    float a = -0.035 * sin(t * 15.0);
    float co = cos(a);
    float si = sin(a);
    mat2 trans1 = mat2(co, si, -si, co);
    vec2 trans2 = vec2(-15.0 * a, 0.0);
    uv *= trans1;
    uv += trans2;
    
    for(float i = 0.0; i < 1.0; i += 1.0 / 8.0) {
        float ti = mod(t * 9.0 - i * 5.0, 4.0);
        float scale_ = mix(2.0, 0.3, ti / 4.0);
        vec2 uvs = uv * scale_;
        float rand = N11(i);
        float h = 10.0 + rand * 4.0;
        float w = 0.02;
        float n = 80.0;
        float s = 0.9;
        float f = 1.5;
        vec2 p = vec2(mix(-8.0, 8.0, rand), -10.0);
          
        col += back(uvs, vec2(p.x, p.y + h), ti - 1.8) 
            + fireworks(uvs, p, h, n, s, f, ti) * base(uv)
            + shaft(uvs, p, w, h, ti);
    }
    
    gl_FragColor = vec4(col, 1.0);
}