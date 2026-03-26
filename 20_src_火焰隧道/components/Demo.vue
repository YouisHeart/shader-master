<template>
  <div ref="container" class="shader-container">
  </div>
  
</template>

<script setup>
import { ref, onMounted, onBeforeUnmount } from 'vue'
import * as THREE from 'three'
import vertexShader from '../shaders/vertex.glsl?raw'
import fragmentShader from '../shaders/fragment.glsl?raw'

const container = ref(null)

let scene, camera, renderer,material,mesh
let uniforms

const startTime = performance.now()


onMounted(() => {
    initThree() // 初始化Threejs
    initShaders() // 创建shader
    animate() // 开始渲染循环

    window.addEventListener('resize', onResize)
    // window.addEventListener('mousemove', onMouseMove)
})

onBeforeUnmount(() => {
  window.removeEventListener('resize', onResize)
  // window.removeEventListener('mousemove', onMouseMove)
})

// 初始化shader
const initShaders = () => {
  uniforms = {
  iTime: { value: 0 },
  iResolution: { value: new THREE.Vector3(window.innerWidth, window.innerHeight, 1) },
};

  material = new THREE.ShaderMaterial({
    vertexShader,
    fragmentShader,
    uniforms
  })

  // 👇 全屏矩形
  const geometry = new THREE.PlaneGeometry(2, 2)
  mesh = new THREE.Mesh(geometry, material)
  scene.add(mesh)            
}

const initThree = () => {
  scene = new THREE.Scene()
  
  camera = new THREE.OrthographicCamera(-1, 1, 1, -1, 0.1, 10) // 左右上下近远
  camera.position.z = 1
  
  renderer = new THREE.WebGLRenderer({ 
    antialias: true, 
    alpha: false, // 禁用透明
    powerPreference: "high-performance"
  })
  renderer.setSize(window.innerWidth, window.innerHeight)
  renderer.setPixelRatio(window.devicePixelRatio)
  container.value.appendChild(renderer.domElement)
}

let lastTime = performance.now()
function animate() {
  requestAnimationFrame(animate);
  uniforms.iTime.value = performance.now() * 0.001;
  renderer.render(scene, camera);
}

const onResize = () => {
  renderer.setSize(window.innerWidth, window.innerHeight)
  uniforms.iResolution.value.set(
    window.innerWidth,
    window.innerHeight
  )
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