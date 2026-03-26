precision highp float;

uniform vec3 iResolution;
uniform float iTime;
uniform vec2 iMouse;

varying vec2 vUv;

#define T (iTime * 12.)
#define N normalize
#define R(a) mat2(cos(a+vec4(0,33,11,0)))
#define P(z) (vec3(cos((z)*.005)*16.+cos((z) * .006)  *64., \
                   cos((z)*.011)*24.+cos((z) * .004) * 64., (z)))

float tri(in float x){return abs(fract(x)-.5);}
vec3 tri3(in vec3 p){
    return vec3(
        tri(p.z+tri(p.y)),
        tri(p.z+tri(p.x)),
        tri(p.y+tri(p.x))
    );
}

vec4 fire(vec3 p) {
    float s, n;
    s = 40.0 - length(p.xy);
    for (n = 1.6; n < 32.; n += n )
        s -= abs(dot(sin( p.z + T + 2.*p/n ), vec3(n+n))) / n;
    s = (.01 + abs(s)*.15);
    return vec4(7.0,2.0,1.0,1.0) / s;
}

float triNoise3d(vec3 p)
{
    p.z += T/20.0;
    float z=1.5;
    float rz = 0.;
    vec3 bp = p;
    mat2 m2 = R(.3);

    for (float i=0.; i<=3.; i++ )
    {
        vec3 dg = tri3(bp*2.);
        p += (dg+T/20.0);

        bp *= 2.5;
        z *= 1.35;
        p *= 1.1;
        p.yz*= m2;
        
        rz+= (tri(p.z+tri(p.x+tri(p.y))))/z;
        bp += .1;
    }
    return rz;
}

void main() {
    vec4 o = vec4(0.0);
    vec2 u = vUv * iResolution.xy;

    float e=0.0,i=0.0,s=0.0,n=0.0,d=0.0,t = iTime;
    vec3  r = iResolution;    
    
    u = (u+u-r.xy)/r.y;
    u +=  cos(t*vec2(.5, .4))*.6;

    vec3  p = P(T*20.0), ro = p,
          Z = N(P(T*20.0+10.0) - p),
          X = N(vec3(Z.z, 0.0, -Z.x)),
          D = N(vec3(R(sin(T*.1)*.2)*u, 1.0) * mat3(-X, cross(X, Z), Z));    

    for(i=0.0; i<64.0 && d < 1000.0; i++)
    {
        d += s = min(.15+.3*abs(s), e=max(.4*e,1.));
        o += vec4(6.0,2.0,1.0,0.0)/e/2. + .1/s;

        p = ro + D*d;
        p.xy -= P(p.z).xy;

        o += fire(p)/30.0;

        e = length(p.xy - vec2(0.0, 40.0))/2. 
            - 4.0*dot(sin(T+p/2.0), cos(T*2.0+p.yzx/3.0));

        p.xy *= mat2(cos(p.z/70.0+vec4(0,33,11,0)));

        s = 50.0 - abs(p.y) - 50.0*triNoise3d(p/70.0);
    }

    o = tanh(o*o/300.0);

    gl_FragColor = o;
}