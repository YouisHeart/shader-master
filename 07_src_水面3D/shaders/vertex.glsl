precision highp float;

uniform float uTime;
uniform vec4 uWaves[12];

varying vec3 vWorldPosition;
varying vec3 vWorldNormal;
varying float vHeight;
varying float vFoamFactor;
varying vec2 vUv;

#define PI 3.14159265359
#define GRAVITY 9.81

vec3 gerstnerWave(vec4 wave, vec3 p, inout vec3 tangent, inout vec3 binormal) {
    float steepness = wave.z;
    float wavelength = wave.w;
    float k = 2.0 * PI / wavelength;
    float c = sqrt(GRAVITY / k);
    vec2 d = normalize(wave.xy);
    float f = k * (dot(d, p.xz) - c * uTime);
    float a = steepness / k;

    tangent += vec3(
        -d.x * d.x * steepness * sin(f),
         d.x * steepness * cos(f),
        -d.x * d.y * steepness * sin(f)
    );
    binormal += vec3(
        -d.x * d.y * steepness * sin(f),
         d.y * steepness * cos(f),
        -d.y * d.y * steepness * sin(f)
    );

    return vec3(
        d.x * a * cos(f),
        a * sin(f),
        d.y * a * cos(f)
    );
}

// ── Hash-based value noise for vertex displacement chaos ──
float hash31(vec3 p) {
    p = fract(p * vec3(0.1031, 0.1030, 0.0973));
    p += dot(p, p.yxz + 33.33);
    return fract((p.x + p.y) * p.z);
}

float vnoise(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(mix(hash31(i), hash31(i+vec3(1,0,0)), f.x),
            mix(hash31(i+vec3(0,1,0)), hash31(i+vec3(1,1,0)), f.x), f.y),
        mix(mix(hash31(i+vec3(0,0,1)), hash31(i+vec3(1,0,1)), f.x),
            mix(hash31(i+vec3(0,1,1)), hash31(i+vec3(1,1,1)), f.x), f.y), f.z);
}

float vfbm(vec3 p) {
    float f = 0.0;
    f += 0.500 * vnoise(p); p *= 2.03;
    f += 0.250 * vnoise(p); p *= 2.01;
    f += 0.125 * vnoise(p); p *= 2.04;
    f += 0.0625 * vnoise(p);
    return f;
}

void main() {
    vUv = uv;
    vec3 pos = position;
    vec3 tangent = vec3(1.0, 0.0, 0.0);
    vec3 binormal = vec3(0.0, 0.0, 1.0);

    vec3 totalDisp = vec3(0.0);
    for (int i = 0; i < 12; i++) {
        totalDisp += gerstnerWave(uWaves[i], position, tangent, binormal);
    }

    // ── Turbulent noise displacement for ocean chaos ──
    // Breaks the periodic uniformity of Gerstner waves
    vec3 nc1 = position * 0.015 + vec3(uTime * 0.35, 0.0, uTime * 0.22);
    float heightNoise = (vfbm(nc1) - 0.5) * 2.0;
    totalDisp.y += heightNoise * 2.2;

    // Horizontal noise for organic undulation
    vec3 nc2 = position * 0.01 + vec3(-uTime * 0.12, 0.0, uTime * 0.08);
    totalDisp.x += (vfbm(nc2) - 0.5) * 0.9;
    totalDisp.z += (vfbm(nc2 + vec3(4.7, 1.3, 6.1)) - 0.5) * 0.9;

    // ── Crest softening: tanh compression rounds off sharp peaks ──
    float softFactor = 3.5;
    totalDisp.y = tanh(totalDisp.y / softFactor) * softFactor;

    pos += totalDisp;

    vec3 normal = normalize(cross(binormal, tangent));

    vWorldPosition = (modelMatrix * vec4(pos, 1.0)).xyz;
    vWorldNormal = normalize(mat3(modelMatrix) * normal);
    vHeight = totalDisp.y;

    // More foam: lower threshold for scattered whitecaps
    float maxH = 2.2;
    vFoamFactor = smoothstep(0.25 * maxH, maxH, totalDisp.y);

    gl_Position = projectionMatrix * modelViewMatrix * vec4(pos, 1.0);
}