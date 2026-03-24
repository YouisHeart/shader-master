// fragment.glsl
precision highp float;

uniform vec3 iResolution;
uniform float iTime;

varying vec2 vUv;

void main() {
    vec4 O;
    vec2 F = gl_FragCoord.xy;

    float i = .2, a;

    vec2 r = iResolution.xy;

    vec2 p = (F + F - r) / r.y / .7;

    vec2 d = vec2(-1.0, 1.0);

    vec2 b = p - i * d;

    vec2 c = p * mat2(1.0, 1.0, d / (.1 + i / dot(b, b)));

    a = dot(c, c);

    vec4 tmp = vec4(0.0, 33.0, 11.0, 0.0);

    vec2 v = c * mat2(
        cos(.5 * log(a) + iTime * i + tmp.xy),
        cos(.5 * log(a) + iTime * i + tmp.zw)
    ) / i;

    vec4 w = vec4(0.0);

    for (; i++ < 9.0; ) {
        w += 1.0 + sin(v).xyxy;
        v += .7 * sin(v.yx * i + iTime) / i + .5;
    }

    float disk = length(sin(v / .3) * .4 + c * (3.0 + d));

    O = 1.0 - exp(
        -exp(c.x * vec4(.6, -.4, -1.0, 0.0))
        / w
        / (2.0 + disk * disk / 4.0 - disk)
        / (.5 + 1.0 / a)
        / (.03 + abs(length(p) - .7))
    );

    gl_FragColor = O;
}