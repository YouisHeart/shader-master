<template>
  <div class="cloud-scene-container" ref="containerRef">
    <div class="info-panel">
      <div class="title">☁️ 体积云 · 纯白云效果 (无天空背景)</div>
      <div class="controls-hint">🖱️ 鼠标拖拽旋转视角 | 右键平移 | 滚轮缩放</div>
    </div>
  </div>
</template>

<script setup>
import { onMounted, onBeforeUnmount, ref } from 'vue'
import * as THREE from 'three'
import { OrbitControls } from 'three/addons/controls/OrbitControls.js'

// ============================================================
// 纯白云效果 - 无天空背景，只输出云层颜色和透明度
// 方便后续移植到 Cesium 中叠加使用
// 原始GLSL作者: yjsdszz (https://gitee.com/yjsdszz)
// ============================================================

const containerRef = ref(null)

// Three.js 核心对象
let renderer = null
let camera = null
let scene = null
let controls = null
let clock = null
let cloudMesh = null
let starsPoints = null

// Shader uniforms
let uniforms = null

// 动画循环 ID
let animationId = null

// 鼠标位置 (用于控制相机视角，增强互动)
let targetMouseX = 0
let targetMouseY = 0
let currentMouseX = 0
let currentMouseY = 0

// 窗口尺寸适配
let resizeHandler = null

// ============================================================
// 1. 初始化场景
// ============================================================
const initScene = () => {
  if (!containerRef.value) return

  // 渲染器 (启用透明度，以便叠加到其他背景)
  renderer = new THREE.WebGLRenderer({ 
    antialias: true, 
    alpha: true  // 开启透明通道，不绘制背景
  })
  renderer.setPixelRatio(window.devicePixelRatio)
  renderer.setSize(window.innerWidth, window.innerHeight)
  renderer.setClearColor(0x000000, 0) // 完全透明背景
  containerRef.value.appendChild(renderer.domElement)

  // 相机
  camera = new THREE.PerspectiveCamera(60, window.innerWidth / window.innerHeight, 0.01, 10000)
  camera.position.set(4, 3.2, 5.5)
  camera.lookAt(0, 1.2, 0)

  // 场景
  scene = new THREE.Scene()
  
  // 轨道控制 (用户交互)
  controls = new OrbitControls(camera, renderer.domElement)
  controls.enableDamping = true
  controls.dampingFactor = 0.06
  controls.rotateSpeed = 1.0
  controls.zoomSpeed = 1.2
  controls.panSpeed = 0.8
  controls.target.set(0, 1.2, 0)
}

// ============================================================
// 2. 创建白云材质 (ShaderMaterial) - 纯云层，无天空
// ============================================================
const createCloudMaterial = () => {
  // 定义 uniforms
  uniforms = {
    iGlobalTime: { value: 0 },
    iResolution: { value: new THREE.Vector2(window.innerWidth, window.innerHeight) },
    iMouse: { value: new THREE.Vector2(0, 0) }
  }

  // 片段着色器 - 只输出云层，天空部分完全透明
  const fragmentShader = `
    precision mediump float;
    
    uniform vec2 iResolution;
    uniform float iGlobalTime;
    uniform vec2 iMouse;
    
    // 随机哈希函数
    float hash( float n ) {
      return fract(sin(n)*43758.5453);
    }
    
    // 3D 噪声函数，用于云层密度场
    float noise( in vec3 x ) {
      vec3 p = floor(x);
      vec3 f = fract(x);
      f = f*f*(3.0-2.0*f);
      float n = p.x + p.y*57.0 + 113.0*p.z;
      return mix(mix(mix( hash(n+  0.0), hash(n+  1.0),f.x),
                     mix( hash(n+ 57.0), hash(n+ 58.0),f.x),f.y),
                 mix(mix( hash(n+113.0), hash(n+114.0),f.x),
                     mix( hash(n+170.0), hash(n+171.0),f.x),f.y),f.z);
    }
    
    // 云层密度场与颜色映射
    vec4 map( in vec3 p ) {
      float d = 0.2 - p.y;
      vec3 q = p - vec3(1.0, 0.12, 0.0) * iGlobalTime;
      float f;
      f  = 0.5000 * noise( q ); q = q * 2.02;
      f += 0.2500 * noise( q ); q = q * 2.03;
      f += 0.1250 * noise( q ); q = q * 2.01;
      f += 0.0625 * noise( q );
      d += 3.0 * f;
      d = clamp( d, 0.0, 1.0 );
      vec4 res = vec4( d );
      // 云的颜色: 暖白到淡灰
      res.xyz = mix( 1.15 * vec3(1.0, 0.95, 0.85), vec3(0.72, 0.72, 0.75), res.x );
      return res;
    }
    
    // 太阳光方向 (用于云层光照)
    vec3 sundir = vec3(-1.0, 0.35, -0.45);
    
    // 射线步进 (Ray Marching) 累积云层颜色
    vec4 raymarch( in vec3 ro, in vec3 rd ) {
      vec4 sum = vec4(0.0);
      float t = 0.0;
      for(int i = 0; i < 70; i++) {
        if( sum.a > 0.99 ) continue;
        vec3 pos = ro + t * rd;
        vec4 col = map( pos );
        
        // 简单光照漫反射
        float dif = clamp((col.w - map(pos + 0.28 * sundir).w) / 0.6, 0.0, 1.0);
        vec3 lin = vec3(0.68, 0.70, 0.72) * 1.32 + 0.48 * vec3(0.75, 0.55, 0.35) * dif;
        col.xyz *= lin;
        
        col.a *= 0.38;
        col.rgb *= col.a;
        sum = sum + col * (1.0 - sum.a);
        
        t += max(0.08, 0.028 * t);
      }
      sum.xyz /= (0.001 + sum.w);
      return clamp( sum, 0.0, 1.0 );
    }
    
    void main(void) {
      vec2 q = gl_FragCoord.xy / iResolution.xy;
      vec2 p = -1.0 + 2.0 * q;
      p.x *= iResolution.x / iResolution.y;
      vec2 mo = -1.0 + 2.0 * iMouse.xy / iResolution.xy;
      
      // 动态相机: 基于鼠标位置旋转视角
      float angleHor = 2.75 - 3.0 * mo.x;
      float angleVer = 0.75 + (mo.y + 1.0) * 0.35;
      float clampedVer = clamp(angleVer, -0.3, 1.6);
      vec3 ro = 4.2 * normalize(vec3(cos(angleHor), clampedVer, sin(angleHor)));
      vec3 ta = vec3(0.0, 1.0, 0.0);
      vec3 ww = normalize( ta - ro );
      vec3 uu = normalize(cross( vec3(0.0, 1.0, 0.0), ww ));
      vec3 vv = normalize(cross(ww, uu));
      vec3 rd = normalize( p.x * uu + p.y * vv + 1.5 * ww );
      
      vec4 res = raymarch( ro, rd );
      
      // 纯云层输出 - 不混合任何天空背景
      // res.xyz 是云层颜色，res.w 是云层不透明度
      // 如果云层密度很低，则完全透明，露出背景
      vec4 finalColor = vec4(res.xyz, res.w);
      
      gl_FragColor = finalColor;
    }
  `

  // 顶点着色器
  const vertexShader = `
    void main() {
      gl_PointSize = 1.0;
      gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
    }
  `

  return new THREE.ShaderMaterial({
    uniforms: uniforms,
    vertexShader: vertexShader,
    fragmentShader: fragmentShader,
    transparent: true,      // 启用透明通道
    side: THREE.BackSide,   // 内表面渲染，包裹相机
    depthWrite: false,
    depthTest: true
  })
}

// ============================================================
// 3. 创建云层球体 (巨大的天空球)
// ============================================================
const createCloudSphere = () => {
  // 使用球体几何，半径足够大以包裹相机
  const geometry = new THREE.SphereGeometry(4900, 80, 80)
  const material = createCloudMaterial()
  const mesh = new THREE.Mesh(geometry, material)
  scene.add(mesh)
  return mesh
}


// ============================================================
// 5. 鼠标交互监听
// ============================================================
const setupMouseTracking = () => {
  const onMouseMove = (event) => {
    const nx = (event.clientX / window.innerWidth) * 2.0 - 1.0
    const ny = 1.0 - (event.clientY / window.innerHeight) * 2.0
    targetMouseX = nx
    targetMouseY = ny
  }
  window.addEventListener('mousemove', onMouseMove)
  return onMouseMove
}

// ============================================================
// 6. 窗口尺寸适配
// ============================================================
const setupResizeHandler = () => {
  const handler = () => {
    if (!camera || !renderer || !uniforms) return
    camera.aspect = window.innerWidth / window.innerHeight
    camera.updateProjectionMatrix()
    renderer.setSize(window.innerWidth, window.innerHeight)
    uniforms.iResolution.value.set(window.innerWidth, window.innerHeight)
  }
  window.addEventListener('resize', handler)
  return handler
}

// ============================================================
// 7. 动画循环
// ============================================================
const startAnimationLoop = () => {
  if (!renderer || !scene || !camera || !controls || !uniforms) return

  clock = new THREE.Clock()

  const animate = () => {
    const elapsedTime = clock.getElapsedTime()
    
    // 更新 Shader 时间
    uniforms.iGlobalTime.value = elapsedTime
    
    // 平滑鼠标值
    currentMouseX += (targetMouseX - currentMouseX) * 0.06
    currentMouseY += (targetMouseY - currentMouseY) * 0.06
    uniforms.iMouse.value.set(currentMouseX, currentMouseY)
    
    // 星星缓慢自转
    if (starsPoints) {
      starsPoints.rotation.y = elapsedTime * 0.005
      starsPoints.rotation.x = Math.sin(elapsedTime * 0.002) * 0.08
    }
    
    // 更新轨道控制
    controls.update()
    
    // 渲染 (透明背景，只输出云层)
    renderer.render(scene, camera)
    
    animationId = requestAnimationFrame(animate)
  }
  
  animate()
}

// ============================================================
// 8. 清理资源
// ============================================================
const cleanup = () => {
  if (animationId) {
    cancelAnimationFrame(animationId)
    animationId = null
  }
  
  if (resizeHandler) {
    window.removeEventListener('resize', resizeHandler)
    resizeHandler = null
  }
  
  if (renderer) {
    renderer.dispose()
    if (renderer.domElement && renderer.domElement.parentNode) {
      renderer.domElement.parentNode.removeChild(renderer.domElement)
    }
  }
  
  if (controls) {
    controls.dispose()
  }
  
  if (scene) {
    scene.traverse((obj) => {
      if (obj.isMesh) {
        obj.geometry?.dispose()
        if (obj.material) {
          if (Array.isArray(obj.material)) obj.material.forEach(m => m.dispose())
          else obj.material.dispose()
        }
      }
    })
  }
}

// ============================================================
// 生命周期
// ============================================================
onMounted(() => {
  initScene()
  cloudMesh = createCloudSphere()
  
  const mouseMoveHandler = setupMouseTracking()
  resizeHandler = setupResizeHandler()
  startAnimationLoop()
  
  window._cloudMouseHandler = mouseMoveHandler
})

onBeforeUnmount(() => {
  if (window._cloudMouseHandler) {
    window.removeEventListener('mousemove', window._cloudMouseHandler)
    delete window._cloudMouseHandler
  }
  cleanup()
})
</script>

<style scoped>
.cloud-scene-container {
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  overflow: hidden;
  background: transparent;  /* 完全透明背景，露出下方的天空 */
}

.info-panel {
  position: absolute;
  bottom: 20px;
  left: 20px;
  z-index: 10;
  pointer-events: none;
  font-family: 'Segoe UI', 'Microsoft YaHei', sans-serif;
  text-shadow: 0 1px 2px rgba(0,0,0,0.5);
}

.title {
  background: rgba(0, 0, 0, 0.6);
  backdrop-filter: blur(8px);
  padding: 8px 18px;
  border-radius: 30px;
  color: #f0ebe0;
  font-size: 13px;
  font-weight: 500;
  letter-spacing: 1px;
  margin-bottom: 8px;
  border-left: 3px solid #ffbc6e;
}

.controls-hint {
  background: rgba(0, 0, 0, 0.45);
  backdrop-filter: blur(5px);
  padding: 5px 14px;
  border-radius: 20px;
  color: #ccc;
  font-size: 11px;
  font-family: monospace;
}

@media (max-width: 600px) {
  .title { font-size: 10px; padding: 5px 12px; }
  .controls-hint { font-size: 9px; padding: 3px 10px; }
}
</style>