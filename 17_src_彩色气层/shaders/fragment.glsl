// fragment.glsl
precision highp float;

uniform vec3 iResolution;
uniform float iTime;
uniform sampler2D iChannel0;

varying vec2 vUv;

void main() {
    vec2 I = vUv * iResolution.xy;  // 将 uv 映射到像素坐标
    vec4 O = vec4(0.0);

    float t = iTime;
    float i = 0.0;
    float z = 0.0;
    float d = 0.0;
    float s = 0.0;

    for(O *= i; i++ < 100.0; ) {
        vec3 p = z * normalize(vec3(I + I, 0.0) - iResolution.xyy);

        for(d = 5.0; d < 200.0; d += d)
            p += 0.6 * sin(p.yzx * d - 0.2 * t) / d;

        z += d = 0.005 + max(s = 0.3 - abs(p.y), -s * 0.2) / 4.0;
        O += (cos(s / 0.07 + p.x + 0.5 * t - vec4(3.0, 4.0, 5.0, 0.0)) + 1.5) * exp(s / 0.1) / d;
    }

    O = tanh(O * O / 4e8);
    gl_FragColor = O;
}