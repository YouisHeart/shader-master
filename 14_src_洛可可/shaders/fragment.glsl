// fragment.glsl
precision highp float;

// ===== uniforms（来自 Three.js）=====
uniform vec3 iResolution;
uniform float iTime;

// 如果后面要扩展可以保留（当前未使用）
// uniform vec4 iMouse;
// uniform vec4 iDate;

varying vec2 vUv;

void main() {
    // 输出颜色
    vec4 O = vec4(0.0);

    // Shadertoy 的像素坐标
    vec2 I = gl_FragCoord.xy;

    // ===== 原始逻辑 =====

    // Vector for scaling and turbulence
    vec2 v = iResolution.xy;

    // Centered and scaled coordinates
    vec2 p = (I + I - v) / v.y / 0.3;

    float i;
    float f;

    // 外层循环（层数）
    for (i = 0.0; i < 9.0; i++) {

        // 每一层都重置 v 和 f
        v = p;

        // turbulence
        for (f = 1.0; f < 9.0; f++) {
            v += sin(v.yx * f + i + iTime) / f;
        }

        // 颜色叠加
        O += (cos(i + vec4(0.0, 1.0, 2.0, 3.0)) + 1.0) 
             / 6.0 
             / length(v);
    }

    // tanh tonemapping
    O = tanh(O * O);

    gl_FragColor = O;
}