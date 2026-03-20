<template>
  <div ref="container" class="shader-container"></div>
</template>

<script setup>
import { ref, onMounted, onBeforeUnmount } from 'vue'
import * as THREE from 'three'
import vertexShader from '../shaders/vertex.glsl?raw'
import fragmentShader from '../shaders/fragment.glsl?raw'

const container = ref(null)

let scene, camera, renderer, material, mesh
let animationId = null
let lastTime = performance.now()
let frame = 0

// 鼠标交互
const mouse = new THREE.Vector4(0, 0, 0, 0)
let isMouseDown = false

onMounted(() => {
  try {
    initThree()
    initShaders()
    setupEventListeners()
    animate()
  } catch (error) {
    console.error('初始化失败:', error)
  }
})

onBeforeUnmount(() => {
  if (animationId) {
    cancelAnimationFrame(animationId)
  }
  if (renderer) {
    renderer.dispose()
  }
  if (material) {
    material.dispose()
  }
  window.removeEventListener('resize', handleResize)
  window.removeEventListener('mousemove', handleMouseMove)
  window.removeEventListener('mousedown', handleMouseDown)
  window.removeEventListener('mouseup', handleMouseUp)
})

const initThree = () => {
  scene = new THREE.Scene()
  
  camera = new THREE.OrthographicCamera(-1, 1, 1, -1, 0.1, 10)
  camera.position.z = 1
  
  renderer = new THREE.WebGLRenderer({ 
    antialias: true, 
    alpha: false,
    powerPreference: "high-performance"
  })
  renderer.setSize(window.innerWidth, window.innerHeight)
  renderer.setPixelRatio(window.devicePixelRatio)
  container.value.appendChild(renderer.domElement)
  
  console.log('Three.js 初始化完成')
}

const initShaders = () => {
  // 创建平面几何体，并传递 UV 坐标
  const geometry = new THREE.PlaneGeometry(2, 2)
  
  // 创建音频纹理
  const audioTexture = createAudioTexture()
  
  // 初始化 uniforms
  const uniforms = {
    iResolution: { value: new THREE.Vector3(window.innerWidth, window.innerHeight, 1) },
    iTime: { value: 0 },
    iTimeDelta: { value: 0 },
    iFrameRate: { value: 60 },
    iFrame: { value: 0 },
    iChannelTime: { value: [0, 0, 0, 0] },
    iChannelResolution: { value: [
      new THREE.Vector3(512, 512, 1),
      new THREE.Vector3(512, 512, 1),
      new THREE.Vector3(512, 512, 1),
      new THREE.Vector3(512, 512, 1)
    ] },
    iMouse: { value: mouse },
    iChannel0: { value: audioTexture },
    iDate: { value: getCurrentDate() },
    iSampleRate: { value: 44100 }
  }
  
  material = new THREE.ShaderMaterial({
    uniforms: uniforms,
    vertexShader: vertexShader,
    fragmentShader: fragmentShader,
    transparent: false,
    depthTest: false,
    depthWrite: false
  })
  
  mesh = new THREE.Mesh(geometry, material)
  scene.add(mesh)
  
  console.log('Shader 材质创建成功')
  
  // 检查编译错误
  if (material.program) {
    console.log('Shader 编译成功')
  }
}

const createAudioTexture = () => {
  const canvas = document.createElement('canvas')
  canvas.width = 512
  canvas.height = 512
  const ctx = canvas.getContext('2d')
  ctx.fillStyle = '#000000'
  ctx.fillRect(0, 0, canvas.width, canvas.height)
  
  const texture = new THREE.CanvasTexture(canvas)
  texture.wrapS = THREE.RepeatWrapping
  texture.wrapT = THREE.RepeatWrapping
  texture.needsUpdate = true
  
  return texture
}

const getCurrentDate = () => {
  const now = new Date()
  const seconds = now.getHours() * 3600 + now.getMinutes() * 60 + now.getSeconds()
  return new THREE.Vector4(now.getFullYear(), now.getMonth() + 1, now.getDate(), seconds)
}

const setupEventListeners = () => {
  window.addEventListener('resize', handleResize)
  window.addEventListener('mousemove', handleMouseMove)
  window.addEventListener('mousedown', handleMouseDown)
  window.addEventListener('mouseup', handleMouseUp)
}

const handleResize = () => {
  const width = window.innerWidth
  const height = window.innerHeight
  
  renderer.setSize(width, height)
  if (material) {
    material.uniforms.iResolution.value.set(width, height, 1)
  }
}

const handleMouseMove = (event) => {
  if (isMouseDown) {
    mouse.z = event.clientX
    mouse.w = event.clientY
  }
  mouse.x = event.clientX
  mouse.y = event.clientY
  if (material) {
    material.uniforms.iMouse.value = mouse
  }
}

const handleMouseDown = (event) => {
  isMouseDown = true
  mouse.z = event.clientX
  mouse.w = event.clientY
  if (material) {
    material.uniforms.iMouse.value = mouse
  }
}

const handleMouseUp = () => {
  isMouseDown = false
  mouse.z = 0
  mouse.w = 0
  if (material) {
    material.uniforms.iMouse.value = mouse
  }
}

const animate = () => {
  animationId = requestAnimationFrame(animate)
  
  const currentTime = performance.now() / 1000
  const deltaTime = Math.min(currentTime - lastTime, 0.033)
  
  if (material) {
    material.uniforms.iTime.value = currentTime
    material.uniforms.iTimeDelta.value = deltaTime
    material.uniforms.iFrame.value = frame++
    material.uniforms.iDate.value = getCurrentDate()
    
    for (let i = 0; i < 4; i++) {
      material.uniforms.iChannelTime.value[i] = currentTime
    }
  }
  
  lastTime = currentTime
  
  if (renderer && scene && camera) {
    renderer.render(scene, camera)
  }
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