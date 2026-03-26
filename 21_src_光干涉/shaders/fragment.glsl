// fragment.glsl

precision highp float;

uniform vec3 iResolution;
uniform float iTime;

varying vec2 vUv;

#define R(a) *= mat2(cos(a + vec4(0,33,11,0)))
#define L(x) length(x)

void mainImage(out vec4 O, vec2 F) {

    float a = 0.0;
    float r = 0.0;
    float t = iTime;
    
    for (a = 0.0; a < 40.0; a++) {

        vec3 i = iResolution;
        vec3 f;
        
        vec3 p = r * normalize(vec3((F + F - i.xy) / i.y, 1.0));
             
        p.z -= 3.0;
        p.xz R(.3);
        p.zy R(sin(t/4.0)*.3 + .9);
        p.xy R(t/4.0);
        p.x = abs(p.x) - 1.0;
        
        O += (.01 + .02*smoothstep(.9, 1.0, cos(L(p.xy+p.z)*2.0 - t))) *
             (1.0 + cos(L(p.xy)*2.0 + a*.2 + vec4(0,1,2,0))) / L(p.xy);
             
        p.yx R(atan(p.y, p.x));
        p.zx R(atan(max(p.z, 0.0), p.x));
        
        f.x = pow(.67, floor(t - log(p.x)/.4) - t);
        
        r += min(L(p.xy), min(
             abs(L(p - f) - f.x*.2), 
             abs(L(p - f*.67) - f.x*.134)
        )) + .01;
    }
    
    O = tanh(O);
}

void main() {
    vec4 color = vec4(0.0);

    mainImage(color, gl_FragCoord.xy);

    gl_FragColor = color;
}