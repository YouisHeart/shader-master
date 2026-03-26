// fragment.glsl
precision highp float;

uniform vec3 iResolution; // viewport resolution (in pixels)
uniform float iTime;      // shader playback time (in seconds)

varying vec2 vUv;         // 从 vertex shader 传过来的 uv

// --- 全局变量 ---
mat2 R;           // 2D 旋转矩阵
float d = 1.;     // 最近一次的距离
float z;          // raymarch 距离累计
float G = 9.;     // glow 强度
float M = 1e-3;   // epsilon

// --- 距离函数 (SDF) ---
float D(vec3 p) {
    // 空间旋转
    p.xy *= R;
    p.xz *= R;

    // 高频表面细节
    vec3 S = sin(123.0 * p);

    // glow 值更新
    G = min(
        G,
        max(
            abs(length(p) - 0.6),
            d = pow(dot(p *= p*p*p, p), 0.125) - 0.5 - pow(1.0 + S.x*S.y*S.z, 8.0)/1e5
        )
    );

    return d;
}

// --- Shadertoy mainImage 封装 ---
void mainImage(out vec4 o, vec2 C) {
    vec3 p, O, r = iResolution, I = normalize(vec3(C - 0.5 * r.xy, r.y)), B = vec3(1.0, 2.0, 9.0) * M;

    // raymarch 循环
    for (
        R = mat2(cos(0.3*iTime + vec4(0.0, 11.0, 33.0, 0.0)));
        z < 9.0 && d > M;
        z += D(p)
    ) {
        p = z * I;
        p.z -= 2.0;
    }

    if (z < 9.0) {
        // 法线计算
        for (int i = 0; i < 3; i++) {
            r -= r;
            r[i] = M;
            O[i] = D(p + r) - D(p - r);
        }

        z = 1.0 + dot(O = normalize(O), I);
        r = reflect(I, O);
        C = (p + r * (5.0 - p.y) / abs(r.y)).xz;

        // 颜色计算
        O = z*z * (
            r.y > 0.0
            ? 5e2 * smoothstep(5.0, 4.0, d = sqrt(length(C*C)) + 1.0) * d * B
            : exp(-2.0 * length(C)) * (B/M - 1.0)
        ) + pow(1.0 + O.y, 5.0) * B;
    }

    o = vec4(sqrt(O + B/G), 1.0);
}

// --- WebGL main ---
void main() {
    vec2 C = vUv * iResolution.xy; // uv 转屏幕坐标
    vec4 o;
    mainImage(o, C);
    gl_FragColor = o;
}