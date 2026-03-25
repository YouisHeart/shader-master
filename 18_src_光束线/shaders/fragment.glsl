precision highp float;

uniform vec3 iResolution;
uniform float iTime;

#define SCROLL 2.8
#define SPEED 3.4

varying vec2 vUv;

float ncos(float x) {
    return cos(x) / (.5 + .4 * abs(cos(x)));
}

void main() {
    // 将 0~1 的 vUv 转为像素坐标
    vec2 fragCoord = vUv * iResolution.xy;

    // === 原 Shadertoy mainImage 开始 ===
    vec2 s = (fragCoord * 2.0 - iResolution.xy) / iResolution.y;
    float v = (s.y + 1.0) * (s.y + 1.0) * 0.25;
    s.y -= 1.2;
    float per = 2.0 / abs(s.y);

    vec3 col = vec3(0.0);
    for (float z = 0.0; z < 1.0; z += 0.08) {
        float d = 1.0 + 0.4 * z;
        vec2 p = vec2(s.x * d, s.y + d) * per;
        vec2 ss = p;
        ss.y += SCROLL * iTime;
        vec2 c = ss - 0.05 * iTime + sin(ss * 5.3 + 0.03 * iTime);

        float shift = cos(z / 0.08);
        float wave = ncos(ss.y * 1.4) + ncos(ss.y * 0.9 + 0.3 * iTime);
        ss.x += shift + (wave) / (1.0 + 0.01 * per * per);

        float w = ss.x;
        float l = sin(ss.y * 0.7 + z / 0.08 + SPEED * iTime * sign(shift));
        float intensity = exp(min(l, -l / 0.3 / (1.0 + 4.0 * w * w)));

        vec3 coldA = vec3(0.05, 0.12, 0.45);
        vec3 coldB = vec3(0.55, 0.85, 1.0);
        vec3 tint = mix(coldA, coldB, tanh(shift / 0.1) * 0.5 + 0.5);

        tint += vec3(0.15, 0.0, 0.25) * smoothstep(0.3, 0.7, sin(z * 30.0 + iTime * 0.7));

        col += intensity * tint / (abs(w) + 0.01 * per) * per;
    }
    col = tanh(col / 2e1);

    gl_FragColor = vec4(col * col, 1.0);
}