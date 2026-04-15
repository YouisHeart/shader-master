<template>
  <div ref="container" class="shader-container">
  </div>
  
</template>

<script setup>
import { ref, onMounted, onBeforeUnmount } from 'vue'
import * as THREE from 'three'
import { OrbitControls } from "three/examples/jsm/controls/OrbitControls.js";
import { Sky } from 'three/addons/objects/Sky.js';
import { EffectComposer } from 'three/addons/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/addons/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/addons/postprocessing/UnrealBloomPass.js';
import { OutputPass } from 'three/addons/postprocessing/OutputPass.js';
import vertexShader from '../shaders/vertex.glsl?raw'
import fragmentShader from '../shaders/fragment.glsl?raw'

const container = ref(null)

let scene, camera, renderer,material,mesh,sunPosition,cubeRenderTarget,controls
let uniforms

const WAVE_CONFIG = [
    // Primary ocean swells (dominant energy, long period)
    [1.0, 0.15, 0.10, 140.0],
    [0.80, -0.30, 0.09, 95.0],
    [0.55, 0.60, 0.07, 70.0],
    // Cross swells (directional chaos)
    [-0.20, 1.0, 0.11, 48.0],
    [0.70, -0.55, 0.13, 36.0],
    [-0.85, 0.25, 0.12, 28.0],
    // Medium chop (more steepness for dramatic peaks)
    [0.92, 0.40, 0.16, 24.0],
    [0.35, -0.88, 0.14, 20.0],
    [-0.45, 0.80, 0.12, 18.0],
    // Short-medium chop (aggressive but mesh-safe)
    [0.78, 0.20, 0.14, 17.0],
    [0.20, 0.95, 0.11, 16.5],
    [-0.55, -0.70, 0.10, 16.0],
];

// ─── Sun / Sky Configuration ───────────────────────────────────
const SUN_CONFIG = {
    elevation: 15,      // degrees above horizon
    azimuth: 160,       // degrees rotation
    turbidity: 4,
    rayleigh: 2,
    mieCoefficient: 0.005,
    mieDirectionalG: 0.82,
};

// ─── Color Palette (dark, deep ocean matching reference) ───────
const COLORS = {
    deep: new THREE.Color(0.0, 0.025, 0.08),
    shallow: new THREE.Color(0.02, 0.18, 0.25),
    fog: new THREE.Color(0.55, 0.62, 0.72),
    sun: new THREE.Color(1.0, 0.95, 0.85),
};

const wavesUniform = WAVE_CONFIG.map(w =>
    new THREE.Vector4(w[0], w[1], w[2], w[3])
);

onMounted(() => {
    initThree() // 初始化Threejs
    initShaders() // 创建shader
    animate() // 开始渲染循环
    window.addEventListener('resize', onResize)
})

onBeforeUnmount(() => {
  window.removeEventListener('resize', onResize)
})



// 初始化shader
const initShaders = () => {
  uniforms = {
        uTime: { value: 0.0 },
        uWaves: { value: wavesUniform },
        uSunDirection: { value: sunPosition.clone().normalize() },
        uSunColor: { value: COLORS.sun },
        uEnvMap: { value: cubeRenderTarget.texture },
        uDeepColor: { value: COLORS.deep },
        uShallowColor: { value: COLORS.shallow },
        uFogColor: { value: COLORS.fog },
        uFogDensity: { value: 0.00035 },
    },
  material = new THREE.ShaderMaterial({
    vertexShader,
    fragmentShader,
    uniforms,
    side: THREE.FrontSide
  })

  // 👇 全屏矩形
  const geometry = new THREE.PlaneGeometry(4000,4000,512,512)
  geometry.rotateX(-Math.PI / 2)
  mesh = new THREE.Mesh(geometry, material)
  scene.add(mesh)            
}

const initThree = () => {
  scene = new THREE.Scene()

  // ✅ 先创建 renderer（关键！）
  renderer = new THREE.WebGLRenderer({ 
    antialias: true, 
    alpha: false,
    powerPreference: "high-performance"
  })
  renderer.setSize(window.innerWidth, window.innerHeight)
  renderer.setPixelRatio(window.devicePixelRatio)
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 0.55;
  renderer.outputColorSpace = THREE.SRGBColorSpace;

  container.value.appendChild(renderer.domElement)

  // ─── Sky ───
  const sky = new Sky();
  sky.scale.setScalar(10000);
  scene.add(sky);

  sunPosition = new THREE.Vector3();
  const phi = THREE.MathUtils.degToRad(90 - SUN_CONFIG.elevation);
  const theta = THREE.MathUtils.degToRad(SUN_CONFIG.azimuth);
  sunPosition.setFromSphericalCoords(1, phi, theta);

  sky.material.uniforms['sunPosition'].value.copy(sunPosition);

  // ─── CubeMap（现在 renderer 已经存在 ✅）
  cubeRenderTarget = new THREE.WebGLCubeRenderTarget(1024, {
      format: THREE.RGBAFormat,
      generateMipmaps: true,
      minFilter: THREE.LinearMipmapLinearFilter,
  });

  const cubeCamera = new THREE.CubeCamera(1, 10000, cubeRenderTarget);
  cubeCamera.update(renderer, scene); // ✅ 不会报错了

  // ─── Camera ───
  camera = new THREE.PerspectiveCamera(
    70,
    window.innerWidth / window.innerHeight,
    0.05,
    1000
  );

  camera.position.set(-80, 45, 120)
  camera.lookAt(0, 0, 0)

  // ─── Controls ───
  controls = new OrbitControls(camera, renderer.domElement);
}

const clock = new THREE.Clock()
function animate() {
  requestAnimationFrame(animate)

  const elapsed = clock.getElapsedTime();
  uniforms.uTime.value = elapsed;

  controls.update();
  renderer.render(scene, camera);
}

const onResize = () => {
  renderer.setSize(window.innerWidth, window.innerHeight);
}

</script>

<style scoped>
.shader-container {
  width: 100vw;
  height: 100vh;
  overflow: hidden;
  position: fixed;
  top: 0;
  left: 0;
  background: #000;
}

.shader-container :deep(canvas) {
  display: block;
  width: 100%;
  height: 100%;
}
</style>