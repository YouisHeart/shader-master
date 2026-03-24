precision highp float;

uniform vec2 uResolution;
uniform float uTime;

varying vec2 vUv;

#define PI 3.1415927

// ====== 原 iTime 替换 ======
#define iTime uTime
#define iResolution vec3(uResolution, 1.0)

// ====== 你的原函数（几乎不动） ======

float hash1_2(in vec2 x) {
    return fract(sin(dot(x, vec2(52.127, 61.2871))) * 521.582);
}

vec2 hash2_2(in vec2 x) {
    return fract(sin(vec2(dot(x, vec2(127.1, 311.7)), dot(x, vec2(269.5, 183.3)))) * 43758.5453);
}

float noise1_2(in vec2 uv) {
    vec2 i = floor(uv);
    vec2 f = fract(uv);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash1_2(i);
    float b = hash1_2(i + vec2(1.0, 0.0));
    float c = hash1_2(i + vec2(0.0, 1.0));
    float d = hash1_2(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec2 noise2_2(in vec2 uv) {
    vec2 i = floor(uv);
    vec2 f = fract(uv);
    f = f * f * (3.0 - 2.0 * f);
    vec2 a = hash2_2(i);
    vec2 b = hash2_2(i + vec2(1.0, 0.0));
    vec2 c = hash2_2(i + vec2(0.0, 1.0));
    vec2 d = hash2_2(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec2 rotate(in vec2 point, in float deg) {
    float s = sin(deg);
    float c = cos(deg);
    return mat2(c, -s, s, c) * point;
}

// ====== smoke ======
float layeredNoise1_2(in vec2 uv, in float sizeMod, in float alphaMod, in int layers, in float animationSpeed) {
    float noise = 0.3; float alpha = 1.0; float size = 1.0; vec2 offset = vec2(0.0);
    for (int i = 0; i < 20; i++) {
        if(i >= layers) break;
        offset += hash2_2(vec2(alpha, size)) * 10.0;
        noise += noise1_2(uv * size + vec2(0.0, -iTime * animationSpeed) + offset) * alpha;
        alpha *= alphaMod; size *= sizeMod;
    }
    return noise * (1.0 - alphaMod)/(1.0 - pow(alphaMod, float(layers)));
}

// ====== fire ======
vec3 fireParticles(in vec2 uv, in vec2 originalUV){

    vec2 cellID = floor(uv);
    float deg = iTime * 0.6 * (hash1_2(cellID)-0.5)*2.0;

    vec2 randomPoint = hash2_2(cellID)-0.5;
    randomPoint = mat2(cos(deg), -sin(deg), sin(deg), cos(deg))*randomPoint * 0.66;
    randomPoint += cellID + 0.5;

    vec2 tempUV = uv + (noise2_2(uv*2.0)-0.5)*0.1;
    tempUV -= (noise2_2(uv*3.0+iTime)-0.5)*0.07;

    vec2 scale = vec2(0.5,1.6) + (hash2_2(cellID)-0.5)*vec2(0.25,0.2);
    vec2 glowScale = vec2(0.5,0.8) + (hash2_2(cellID)-0.5)*vec2(0.3,0.1);

    vec2 offset = tempUV-randomPoint;

    float particle_size = 0.009;
    float dist = length(rotate(offset, 0.7)*scale);
    float glowDist = length(rotate(offset, 0.7)*glowScale);

    float particle = 1.0 - smoothstep(particle_size*0.6, particle_size*3.0, dist);
    float glow = pow((1.0 - smoothstep(0.0, particle_size*6.0, glowDist)), 3.0);

    vec3 col = vec3(particle) * vec3(1.0,0.4,0.05)*2.0;
    col += glow * vec3(1.0,0.4,0.05)*0.8;

    float disappear = 1.0 - smoothstep(-0.5, 0.5, originalUV.y);
    float appear = smoothstep(-1.0, -0.6, originalUV.y);

    return col * disappear * appear;
}

// ====== layers ======
vec3 layeredParticles(in vec2 uv){

    vec3 particles = vec3(0.0);
    float size = 1.0;
    float alpha = 1.0;
    vec2 offset = vec2(0.0);

    for (int i = 0; i < 8; i++){
        vec2 noiseOffset = (noise2_2(uv*size*2.0+0.5)-0.5)*0.15;
        vec2 movingUV = (uv * size) + offset + noiseOffset;

        movingUV.y -= iTime*(2.0/size);

        particles += fireParticles(movingUV, uv) * alpha;

        offset += hash2_2(vec2(alpha,alpha))*10.0;
        alpha *= 0.6;
        size *= 1.4;
    }

    return particles;
}

// ====== main ======
void main() {

    vec2 fragCoord = vUv * uResolution;

    vec2 uv = (2.0*fragCoord-uResolution.xy)/uResolution.x;

    float vignette = 1.0 - smoothstep(0.4,1.4,length(uv+vec2(0.0,0.3)));

    uv = uv*1.8;

    float smokeIntensity = layeredNoise1_2(uv*2.0, 1.7, 0.7, 6, 2.0);
    smokeIntensity *= pow(1.0 - smoothstep(-1.0,1.6,uv.y/1.8),2.0);

    vec3 smoke = smokeIntensity * vec3(1.0,0.43,0.1)*0.64;

    vec3 col = layeredParticles(uv) + smoke;
    col *= vignette;

    gl_FragColor = vec4(col,1.0);
}