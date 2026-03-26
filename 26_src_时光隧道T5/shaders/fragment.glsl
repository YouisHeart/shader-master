// fragment.glsl
precision highp float;

uniform vec3 iResolution;
uniform float iTime;

varying vec2 vUv;

// ---------- Helper Functions ----------

// 2D rotation
vec2 r(vec2 v,float t){
    float s=sin(t),c=cos(t);
    return mat2(c,-s,s,c)*v;
}

// ACES tonemap
vec3 a(vec3 c){
    mat3 m1=mat3(0.59719,0.07600,0.02840,
                 0.35458,0.90834,0.13383,
                 0.04823,0.01566,0.83777);
    mat3 m2=mat3(1.60475,-0.10208,-0.00327,
                 -0.53108,1.10813,-0.07276,
                 -0.07367,-0.00605,1.07602);
    vec3 v = m1 * c;
    vec3 a_ = v*(v+0.0245786)-0.000090537;
    vec3 b = v*(0.983729*v+0.4329510)+0.238081;
    return m2*(a_/b);
}

// Xor's Dot Noise
float n(vec3 p){
    const float PHI = 1.618033988;
    const mat3 GOLD = mat3(
        -0.571464913, +0.814921382, +0.096597072,
        -0.278044873, -0.303026659, +0.911518454,
        +0.772087367, +0.494042493, +0.399753815);
    return dot(cos(GOLD * p), sin(PHI * p * GOLD));
}

// ---------- Main ----------

void main(){
    vec2 u = vUv * iResolution.xy; // Shadertoy coords
    vec3 o = vec3(0.0);
    float i, s, t = iTime;
    vec3 p, l = vec3(0.0), b, d;
    p.z = t;
    d = normalize(vec3(2.0*u - iResolution.xy, iResolution.y));

    for(i=0.0;i<10.0;i++){
        b = p;
        b.xy = r(sin(b.xy), t*1.5 + b.z*3.0);
        s = 0.001 + abs(n(b*12.0)/12.0 - n(b))*0.4;
        s = max(s, 2.0 - length(p.xy));
        s += abs(p.y*0.75 + sin(p.z + t*0.1 + p.x*1.5))*0.2;
        p += d*s;
        l += (1.0 + sin(i + length(p.xy*0.1) + vec3(3.0,1.5,1.0))) / s;
    }

    gl_FragColor = vec4(a(l*l/600.0), 1.0);
}