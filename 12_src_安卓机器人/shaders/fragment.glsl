precision highp float;

uniform vec3 iResolution;
uniform float iTime;

varying vec2 vUv;

// ===== 原始函数（完全保留） =====

float _union(float a, float b) { return min(a, b); }
float intersect(float a, float b) { return max(a, b); }
float difference(float a, float b) { return max(a, -b); }

float plane(vec3 p, vec3 planeN, vec3 planePos) {
    return dot(p - planePos, planeN);
}

float sphere(vec3 p, float r) {
    return length(p) - r;
}

float capsuleY(vec3 p, float r, float h) {
    p.y -= clamp(p.y, 0.0, h);
    return length(p) - r;
}

vec3 closestPtPointSegment(vec3 c, vec3 a, vec3 b, out float t) {
    vec3 ab = b - a;
    t = dot(c - a, ab) / dot(ab, ab);
    t = clamp(t, 0.0, 1.0);
    return a + t * ab;
}

float capsule(vec3 p, vec3 a, vec3 b, float r) {
    float t;
    vec3 c = closestPtPointSegment(p, a, b, t);
    return length(c - p) - r;
}

vec3 rotateX(vec3 p, float a) {
    float sa = sin(a);
    float ca = cos(a);
    return vec3(p.x, ca*p.y - sa*p.z, sa*p.y + ca*p.z);
}

vec3 rotateY(vec3 p, float a) {
    float sa = sin(a);
    float ca = cos(a);
    return vec3(ca*p.x + sa*p.z, p.y, -sa*p.x + ca*p.z);
}

float halfSphere(vec3 p, float r) {
    return difference(sphere(p, r),
        plane(p, vec3(0.0, 1.0, 0.0), vec3(0.0)));
}

// ===== scene =====

float scene(vec3 p)
{
    p += vec3(-3.0, 0.0, -3.0);
    p.x = mod(p.x, 6.0);
    p.z = mod(p.z, 6.0);
    p -= vec3(3.0, 0.0, 3.0);

    p.x = abs(p.x);

    float d = 1e10;

    p -= vec3(0.0, 1.0, 0.0);
    vec3 hp = p;

    d = halfSphere(hp, 1.0);
    d = _union(d, sphere(hp - vec3(0.3, 0.3, 0.9), 0.1));
    d = _union(d, capsule(hp, vec3(0.4, 0.7, 0.0), vec3(0.75, 1.2, 0.0), 0.05));
    d = _union(d, capsuleY((p*vec3(1.0, 4.0, 1.0) - vec3(0.0, -4.6, 0.0)), 1.0, 4.0));
    d = _union(d, capsuleY(rotateX(p, sin(iTime)) - vec3(1.2, -0.9, 0.0), 0.2, 0.7));
    d = _union(d, capsuleY(p - vec3(0.4, -1.8, 0.0), 0.2, 0.5));

    p += vec3(0.0, 1.0, 0.0);
    d = _union(d, plane(p, vec3(0.0, 1.0, 0.0), vec3(0.0, -1.0, 0.0)));

    return d;
}

vec3 sceneNormal(vec3 pos)
{
    float eps = 0.0001;
    vec3 n;
    n.x = scene(pos + vec3(eps,0,0)) - scene(pos - vec3(eps,0,0));
    n.y = scene(pos + vec3(0,eps,0)) - scene(pos - vec3(0,eps,0));
    n.z = scene(pos + vec3(0,0,eps)) - scene(pos - vec3(0,0,eps));
    return normalize(n);
}

float ambientOcclusion(vec3 p, vec3 n)
{
    float a = 0.0;
    float weight = 1.0;
    for(int i=1; i<=3; i++) {
        float d = float(i)/3.0 * 0.5;
        a += weight*(d - scene(p + n*d));
        weight *= 0.5;
    }
    return clamp(1.0 - a, 0.0, 1.0);
}

vec3 shade(vec3 pos, vec3 n, vec3 eyePos)
{
    vec3 lightPos = vec3(5.0, 10.0, 5.0);
    vec3 color = vec3(0.643, 0.776, 0.223);

    vec3 l = normalize(lightPos - pos);
    vec3 v = normalize(eyePos - pos);
    vec3 h = normalize(v + l);

    float diff = 0.5 + 0.5 * dot(n, l);
    float spec = pow(max(0.0, dot(n, h)), 100.0);
    float ao = ambientOcclusion(pos, n);

    return diff * ao * color + vec3(spec);
}

vec3 trace(vec3 ro, vec3 rd, out bool hit)
{
    hit = false;
    vec3 pos = ro;

    for(int i=0;i<64;i++){
        float d = scene(pos);
        if(d < 0.01){
            hit = true;
            return pos;
        }
        pos += d * rd;
    }
    return pos;
}

vec3 background(vec3 rd)
{
    return mix(vec3(1.0), vec3(0.0,0.25,1.0), rd.y);
}

// ===== main =====

void main()
{
    vec2 fragCoord = vUv * iResolution.xy;

    vec2 pixel = (fragCoord / iResolution.xy) * 2.0 - 1.0;

    float asp = iResolution.x / iResolution.y;
    vec3 rd = normalize(vec3(asp*pixel.x, pixel.y, -2.0));
    vec3 ro = vec3(0.0, 0.5, 4.5);

    float a = sin(iTime*0.3)*1.5;
    rd = rotateY(rd, a);
    ro = rotateY(ro, a);

    a = sin(iTime*0.25)*0.3;
    rd = rotateX(rd, a);
    ro = rotateX(ro, a);

    bool hit;
    vec3 pos = trace(ro, rd, hit);

    vec3 rgb;

    if(hit){
        vec3 n = sceneNormal(pos);
        rgb = shade(pos, n, ro);
    } else {
        rgb = background(rd);
    }

    gl_FragColor = vec4(rgb, 1.0);
}