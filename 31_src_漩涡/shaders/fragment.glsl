precision highp float;

varying vec2 vUv;

uniform vec3 iResolution;
uniform float iTime;

vec4 tanh4(vec4 x){
    return (exp(2.0*x)-1.0)/(exp(2.0*x)+1.0);
}

void main() {
    vec4 O = vec4(0.0);
    vec2 I = vUv * iResolution.xy;

    float i = 0.0;
    float z = fract(dot(I,sin(I)));
    float d;

    for(i = 0.0; i < 100.0; i++){
        vec3 p = z * normalize(vec3(I+I,0.0) - iResolution.xyy);
        p.z += 6.0;

        for(d = 1.0; d < 9.0; d /= 0.8){
            p += cos(p.yzx*d - iTime) / d;
        }

        z += d = 0.002 + abs(length(p) - 0.5) / 40.0;

        O += (sin(z + vec4(6.0,2.0,4.0,0.0)) + 1.5) / d;
    }

    O = tanh4(O / 7000.0);

    gl_FragColor = O;
}