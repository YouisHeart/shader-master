precision highp float;

uniform float uTime;
uniform vec3 uSunDirection;
uniform vec3 uSunColor;
uniform samplerCube uEnvMap;
uniform vec3 uDeepColor;
uniform vec3 uShallowColor;
uniform vec3 uFogColor;
uniform float uFogDensity;

varying vec3 vWorldPosition;
varying vec3 vWorldNormal;
varying float vHeight;
varying float vFoamFactor;
varying vec2 vUv;

// ─── Simplex Noise (Ashima) ───
vec3 mod289(vec3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4 mod289(vec4 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4 permute(vec4 x) { return mod289(((x * 34.0) + 10.0) * x); }
vec4 taylorInvSqrt(vec4 r) { return 1.79284291400159 - 0.85373472095314 * r; }

float snoise(vec3 v) {
    const vec2 C = vec2(1.0 / 6.0, 1.0 / 3.0);
    const vec4 D = vec4(0.0, 0.5, 1.0, 2.0);

    vec3 i = floor(v + dot(v, C.yyy));
    vec3 x0 = v - i + dot(i, C.xxx);

    vec3 g = step(x0.yzx, x0.xyz);
    vec3 l = 1.0 - g;
    vec3 i1 = min(g.xyz, l.zxy);
    vec3 i2 = max(g.xyz, l.zxy);

    vec3 x1 = x0 - i1 + C.xxx;
    vec3 x2 = x0 - i2 + C.yyy;
    vec3 x3 = x0 - D.yyy;

    i = mod289(i);
    vec4 p = permute(permute(permute(
        i.z + vec4(0.0, i1.z, i2.z, 1.0))
        + i.y + vec4(0.0, i1.y, i2.y, 1.0))
        + i.x + vec4(0.0, i1.x, i2.x, 1.0));

    float n_ = 0.142857142857;
    vec3 ns = n_ * D.wyz - D.xzx;

    vec4 j = p - 49.0 * floor(p * ns.z * ns.z);
    vec4 x_ = floor(j * ns.z);
    vec4 y_ = floor(j - 7.0 * x_);

    vec4 x2_ = x_ * ns.x + ns.yyyy;
    vec4 y2_ = y_ * ns.x + ns.yyyy;
    vec4 h = 1.0 - abs(x2_) - abs(y2_);

    vec4 b0 = vec4(x2_.xy, y2_.xy);
    vec4 b1 = vec4(x2_.zw, y2_.zw);

    vec4 s0 = floor(b0) * 2.0 + 1.0;
    vec4 s1 = floor(b1) * 2.0 + 1.0;
    vec4 sh = -step(h, vec4(0.0));

    vec4 a0 = b0.xzyw + s0.xzyw * sh.xxyy;
    vec4 a1 = b1.xzyw + s1.xzyw * sh.zzww;

    vec3 p0 = vec3(a0.xy, h.x);
    vec3 p1 = vec3(a0.zw, h.y);
    vec3 p2 = vec3(a1.xy, h.z);
    vec3 p3 = vec3(a1.zw, h.w);

    vec4 norm = taylorInvSqrt(vec4(dot(p0, p0), dot(p1, p1), dot(p2, p2), dot(p3, p3)));
    p0 *= norm.x; p1 *= norm.y; p2 *= norm.z; p3 *= norm.w;

    vec4 m = max(0.5 - vec4(dot(x0, x0), dot(x1, x1), dot(x2, x2), dot(x3, x3)), 0.0);
    m = m * m;
    return 105.0 * dot(m * m, vec4(dot(p0, x0), dot(p1, x1), dot(p2, x2), dot(p3, x3)));
}

float fbm(vec3 p) {
    float f = 0.0;
    f += 0.5000 * snoise(p); p *= 2.01;
    f += 0.2500 * snoise(p); p *= 2.02;
    f += 0.1250 * snoise(p); p *= 2.03;
    f += 0.0625 * snoise(p);
    return f;
}

// ─── Fresnel (Schlick) ───
float fresnelSchlick(float cosTheta, float F0) {
    return F0 + (1.0 - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}

void main() {
    vec3 viewDir = normalize(cameraPosition - vWorldPosition);
    vec3 N = normalize(vWorldNormal);

    // ═══ DOMAIN-WARPED MULTI-SCALE NORMAL PERTURBATION ═══
    // Creates dense micro-ripples that break the plastic look

    // Domain warp: noise distorts noise coordinates for organic feel
    float wt = uTime * 0.04;
    vec3 warp = vec3(
        snoise(vWorldPosition * 0.02 + vec3(wt, 0.0, wt * 0.7)),
        0.0,
        snoise(vWorldPosition * 0.02 + vec3(0.0, wt, -wt * 0.5))
    ) * 3.0;

    // Layer 1: medium ripples (wind direction)
    float t1 = uTime * 0.22;
    vec3 p1 = vWorldPosition * 0.07 + warp * 0.3 + vec3(t1, 0.0, t1 * 0.65);
    float r1x = fbm(p1);
    float r1z = fbm(p1 + vec3(7.3, 1.1, 3.7));

    // Layer 2: fine ripples (cross-wind)
    float t2 = uTime * 0.16;
    vec3 p2 = vWorldPosition * 0.18 + warp * 0.2 + vec3(-t2 * 0.5, 0.0, t2);
    float r2x = snoise(p2) * 0.55;
    float r2z = snoise(p2 + vec3(5.2, 0.0, 2.8)) * 0.55;

    // Layer 3: micro-ripples (high frequency)
    float t3 = uTime * 0.35;
    vec3 p3 = vWorldPosition * 0.45 + vec3(t3 * 0.4, 0.0, -t3 * 0.25);
    float r3x = snoise(p3) * 0.35;
    float r3z = snoise(p3 + vec3(3.1, 2.7, 0.0)) * 0.35;

    // Layer 4: capillary waves (very high frequency)
    float t4 = uTime * 0.5;
    vec3 p4 = vWorldPosition * 0.9 + vec3(-t4 * 0.2, 0.0, t4 * 0.15);
    float r4x = snoise(p4) * 0.22;
    float r4z = snoise(p4 + vec3(1.9, 0.5, 4.3)) * 0.22;

    // Layer 5: ultra-fine detail (breaks any remaining smoothness)
    float t5 = uTime * 0.7;
    vec3 p5 = vWorldPosition * 1.8 + vec3(t5 * 0.15, 0.0, -t5 * 0.1);
    float r5x = snoise(p5) * 0.15;
    float r5z = snoise(p5 + vec3(6.4, 3.2, 1.1)) * 0.15;

    // Combine all layers with strong perturbation
    float ns = 0.22;
    vec3 noiseOffset = vec3(
        (r1x + r2x + r3x + r4x + r5x) * ns,
        1.0,
        (r1z + r2z + r3z + r4z + r5z) * ns
    );
    vec3 noiseNormal = normalize(noiseOffset);
    N = normalize(mix(N, noiseNormal, 0.45));

    float NdotV = max(dot(N, viewDir), 0.001);

    // ── Fresnel ──
    float fresnel = fresnelSchlick(NdotV, 0.02);

    // ── Sky reflection via cubemap ──
    vec3 reflectDir = reflect(-viewDir, N);
    vec3 envColor = textureCube(uEnvMap, reflectDir).rgb;

    // ── Water body color (deep vs shallow) ──
    float depthFactor = pow(NdotV, 0.35);
    vec3 waterColor = mix(uDeepColor, uShallowColor, depthFactor);

    // ── Subsurface scattering ──
    vec3 sssDir = normalize(uSunDirection + N * 0.6);
    float sssDot = pow(max(dot(viewDir, -sssDir), 0.0), 5.0);
    float sssHeight = clamp(vHeight / 3.0, 0.0, 1.0);
    vec3 sssColor = vec3(0.05, 0.55, 0.35) * sssDot * sssHeight * 0.7;

    // ── Specular sun glints (triple-lobe for scattered micro-glints) ──
    vec3 halfVec = normalize(uSunDirection + viewDir);
    float NdotH = max(dot(N, halfVec), 0.0);
    float specSharp  = pow(NdotH, 512.0) * 4.0;  // tight sun disc
    float specMedium = pow(NdotH, 128.0) * 0.6;  // medium scatter
    float specBroad  = pow(NdotH, 32.0)  * 0.15; // wide ambient glow
    vec3 specular = uSunColor * (specSharp + specMedium + specBroad);

    // ═══ ADVANCED FOAM SYSTEM ═══
    // Multi-layer anisotropic foam matching reference image

    vec2 worldXZ = vWorldPosition.xz;
    // Wind direction for anisotropic stretching
    vec2 windDir = normalize(vec2(0.85, 0.35));
    vec2 windPerp = vec2(-windDir.y, windDir.x);

    // Coordinates stretched along wind direction (elongated foam streaks)
    vec2 stretchA = vec2(dot(worldXZ, windDir) * 0.06, dot(worldXZ, windPerp) * 0.22);
    vec2 stretchB = vec2(dot(worldXZ, windDir) * 0.12, dot(worldXZ, windPerp) * 0.35);

    // Layer 1: Streaky crest foam (elongated along wind)
    float streak = snoise(vec3(stretchA + uTime * vec2(0.035, 0.015), uTime * 0.04));
    streak = smoothstep(0.30, 0.75, streak);

    // Layer 2: Secondary streaks (different scale, cross-angle)
    vec2 crossDir = normalize(vec2(0.5, 0.85));
    vec2 stretchC = vec2(dot(worldXZ, crossDir) * 0.09, dot(worldXZ, vec2(-crossDir.y, crossDir.x)) * 0.28);
    float streak2 = snoise(vec3(stretchC + uTime * vec2(-0.02, 0.03), uTime * 0.06));
    streak2 = smoothstep(0.35, 0.8, streak2) * 0.45;

    // Layer 3: Cellular texture — soft detail, NOT hard mask
    float cell1 = abs(snoise(vec3(worldXZ * 0.5, uTime * 0.08)));
    float cell2 = abs(snoise(vec3(worldXZ * 1.0 + 5.3, uTime * 0.12)));
    float cellular = cell1 * cell2;
    cellular = smoothstep(0.03, 0.20, cellular);  // soft gradient, not binary

    // Layer 4: Fine spray wisps
    float spray = snoise(vec3(stretchB + uTime * vec2(0.05, 0.02), uTime * 0.12));
    spray = smoothstep(0.60, 0.92, spray) * 0.3;

    // Combine: cellular modulates opacity (creates gaps/holes in foam)
    float crest = vFoamFactor;
    float foamBase = crest * streak * cellular * 0.8;
    foamBase += crest * streak2 * cellular * 0.4;
    foamBase += crest * spray * 0.3;

    // Scattered thin whitecaps
    float scatterBase = smoothstep(0.65, 0.92, snoise(vec3(worldXZ * 0.06 + uTime * 0.02, 0.5)));
    foamBase += scatterBase * streak * cellular * 0.1;

    float totalFoam = clamp(foamBase, 0.0, 1.0);

    // Foam color — slight variation
    float colorVar = snoise(vec3(worldXZ * 0.6, uTime * 0.04)) * 0.05;
    vec3 foamColor = vec3(0.82 + colorVar, 0.88 + colorVar, 0.93 + colorVar);

    // Gentle blending — translucent wisps, not opaque patches
    float foamEdge = smoothstep(0.0, 0.20, totalFoam);

    // ── Combine ──
    vec3 color = mix(waterColor + sssColor, envColor, fresnel);
    color += specular;
    color = mix(color, foamColor, foamEdge * 0.45);

    // ── Distance fog ──
    float dist = length(vWorldPosition - cameraPosition);
    float fogFactor = 1.0 - exp(-dist * uFogDensity);
    color = mix(color, uFogColor, fogFactor);

    gl_FragColor = vec4(color, 1.0);
}