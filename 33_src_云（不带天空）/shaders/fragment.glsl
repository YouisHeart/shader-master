precision highp float;

uniform vec3 sun_color;
uniform vec3 skyGlowColor;
uniform sampler2D map;   // 云噪声图
uniform float uTime;

varying vec3 vWorldPosition;

void main() {
    // 方向向量
    vec3 dir = normalize(vWorldPosition);

    // 简单天空渐变
    vec3 sky = mix(vec3(0.05, 0.1, 0.3), skyGlowColor, max(dir.y, 0.0));

    // 云噪声采样
    vec2 uv = dir.xz * 2.0 + vec2(uTime * 0.05); // 缓慢移动
    float cloud = texture2D(map, uv).r;
    cloud = smoothstep(0.5, 0.7, cloud); // 阈值，控制云覆盖

    vec3 finalColor = mix(sky, sun_color, cloud * 0.5);

    gl_FragColor = vec4(finalColor, 1.0);
}