precision highp float;

uniform vec3 iResolution;
uniform float iTime;

varying vec2 vUv;

#define MaxSteps 30
#define MinimumDistance 0.0009
#define normalDistance 0.0002

#define Iterations 7
#define PI 3.141592
#define Scale 3.0
#define FieldOfView 1.0
#define Jitter 0.05
#define FudgeFactor 0.7
#define NonLinearPerspective 2.0

#define Ambient 0.32184
#define Diffuse 0.5

#define LightDir vec3(1.0)
#define LightColor vec3(1.0,1.0,0.858824)
#define LightDir2 vec3(1.0,-1.0,1.0)
#define LightColor2 vec3(0.0,0.333333,1.0)

#define Offset vec3(0.92858,0.92858,0.32858)

vec2 rotate(vec2 v, float a) {
    return vec2(cos(a)*v.x + sin(a)*v.y, -sin(a)*v.x + cos(a)*v.y);
}

vec3 getLight(in vec3 color, in vec3 normal, in vec3 dir) {
    vec3 lightDir = normalize(LightDir);
    float diffuse = max(0.0,dot(-normal, lightDir));
    
    vec3 lightDir2 = normalize(LightDir2);
    float diffuse2 = max(0.0,dot(-normal, lightDir2));
    
    return
    (diffuse*Diffuse)*(LightColor*color) +
    (diffuse2*Diffuse)*(LightColor2*color);
}

float DE(in vec3 z)
{
    z  = abs(1.0-mod(z,2.0));

    float d = 1000.0;
    for (int n = 0; n < Iterations; n++) {
        z.xy = rotate(z.xy,4.0+2.0*cos( iTime/8.0));        
        z = abs(z);
        if (z.x<z.y){ z.xy = z.yx;}
        if (z.x< z.z){ z.xz = z.zx;}
        if (z.y<z.z){ z.yz = z.zy;}
        z = Scale*z-Offset*(Scale-1.0);
        if( z.z<-0.5*Offset.z*(Scale-1.0))  z.z+=Offset.z*(Scale-1.0);
        d = min(d, length(z) * pow(Scale, float(-n)-1.0));
    }
    
    return d-0.001;
}

vec3 getNormal(in vec3 pos) {
    vec3 e = vec3(0.0,normalDistance,0.0);
    
    return normalize(vec3(
        DE(pos+e.yxx)-DE(pos-e.yxx),
        DE(pos+e.xyx)-DE(pos-e.xyx),
        DE(pos+e.xxy)-DE(pos-e.xxy)
    ));
}

vec3 getColor(vec3 normal, vec3 pos) {
    return vec3(1.0);
}

float rand(vec2 co){
    return fract(cos(dot(co,vec2(4.898,7.23))) * 23421.631);
}

vec4 rayMarch(in vec3 from, in vec3 dir, in vec2 fragCoord) {

    float totalDistance = Jitter*rand(fragCoord.xy+vec2(iTime));
    vec3 dir2 = dir;
    float distance;
    int steps = 0;
    vec3 pos;

    for (int i=0; i < MaxSteps; i++) {

        dir.zy = rotate(dir2.zy,totalDistance*cos( iTime/4.0)*NonLinearPerspective);

        pos = from + totalDistance * dir;
        distance = DE(pos)*FudgeFactor;
        totalDistance += distance;

        if (distance < MinimumDistance) break;
        steps = i;
    }

    float smoothStep = float(steps) + distance/MinimumDistance;
    float ao = 1.1-smoothStep/float(MaxSteps);

    vec3 normal = getNormal(pos-dir*normalDistance*3.0);

    vec3 color = getColor(normal, pos);
    vec3 light = getLight(color, normal, dir);

    color = (color*Ambient+light)*ao;

    return vec4(color,1.0);
}

void main() {

    vec2 fragCoord = vUv * iResolution.xy;

    vec3 camPos = 0.5*iTime*vec3(1.0,0.0,0.0);
    vec3 target = camPos + vec3(1.0,0.0*cos(iTime),0.0*sin(0.4*iTime));
    vec3 camUp  = vec3(0.0,1.0,0.0);
    
    vec3 camDir   = normalize(target-camPos);
    camUp = normalize(camUp-dot(camDir,camUp)*camDir);
    vec3 camRight = normalize(cross(camDir,camUp));
    
    vec2 coord = -1.0 + 2.0 * vUv;
    coord.x *= iResolution.x/iResolution.y;
    
    vec3 rayDir = normalize(camDir + (coord.x*camRight + coord.y*camUp)*FieldOfView);
    
    gl_FragColor = rayMarch(camPos, rayDir, fragCoord);
}