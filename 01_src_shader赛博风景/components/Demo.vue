<template>
  <div ref="container" class="shader-container">
    <Button type="primary" @click="startAudio">播放音乐</Button>
  </div>
  
</template>

<script setup>
import { ref, onMounted, onBeforeUnmount } from 'vue'
import { Button } from "ant-design-vue"
import * as THREE from 'three'
import vertexShader from '../shaders/vertex.glsl?raw'
import fragmentShader from '../shaders/fragment.glsl?raw'

const container = ref(null)

let scene, camera, renderer, material, mesh
let animationId = null
let lastTime = performance.now()
let frame = 0
let audioTexture

// 音频
let audioContext
let analyser
let dataArray
let audio

// 鼠标交互
const mouse = new THREE.Vector4(0, 0, 0, 0)
let isMouseDown = false

onMounted(() => {
    initThree() // 初始化Threejs
    initShaders() // 创建shader
    // setupEventListeners() // 注册事件
    animate() // 开始渲染循环
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

// 音频
const initAudio = async () => {
  audio = new Audio("./music/lianren.mp3")
  audio.crossOrigin = "anonymous"
  audio.loop = true

  audioContext = new (window.AudioContext || window.webkitAudioContext)()

  const source = audioContext.createMediaElementSource(audio)

  analyser = audioContext.createAnalyser()
  analyser.fftSize = 1024

  const bufferLength = analyser.frequencyBinCount
  dataArray = new Uint8Array(bufferLength)

  source.connect(analyser)
  analyser.connect(audioContext.destination)
  await audio.play()
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

const initShaders = () => {
  // 创建平面几何体，并传递 UV 坐标
  const geometry = new THREE.PlaneGeometry(2, 2)
  
  // 创建音频纹理
  audioTexture = createAudioTexture()
  
  // 初始化 uniforms
  const uniforms = {
    iResolution: { value: new THREE.Vector3(window.innerWidth, window.innerHeight, 1) }, // 屏幕分辨率
    iTime: { value: 0 }, // 运行时间
    iTimeDelta: { value: 0 }, // 帧间隔
    iFrameRate: { value: 60 },
    iFrame: { value: 0 }, // 帧数
    iChannelTime: { value: [0, 0, 0, 0] },
    iChannelResolution: { value: [
      new THREE.Vector3(512, 512, 1),
      new THREE.Vector3(512, 512, 1),
      new THREE.Vector3(512, 512, 1),
      new THREE.Vector3(512, 512, 1)
    ] },
    iMouse: { value: mouse }, // 鼠标
    iChannel0: { value: audioTexture.texture },
    iDate: { value: getCurrentDate() }, // 当前时间
    iSampleRate: { value: 44100 } // 音频采样率
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
}

// 这是一个创建音频的测试，后面使用真实的音乐
// const createAudioTexture = () => {
//   const canvas = document.createElement('canvas')
//   canvas.width = 512
//   canvas.height = 1
//   const ctx = canvas.getContext('2d')

//   const texture = new THREE.CanvasTexture(canvas)

//   return {
//     texture,
//     update() {
//       const imageData = ctx.createImageData(512, 1)
//       for (let i = 0; i < 512; i++) {
//         const v = Math.random() * 255
//         imageData.data[i * 4 + 0] = v
//         imageData.data[i * 4 + 1] = v
//         imageData.data[i * 4 + 2] = v
//         imageData.data[i * 4 + 3] = 255
//       }
//       ctx.putImageData(imageData, 0, 0)
//       texture.needsUpdate = true
//     }
//   }
// }

// 使用真实的音频
const createAudioTexture = () => {
  const canvas = document.createElement('canvas')
  canvas.width = 512
  canvas.height = 1
  const ctx = canvas.getContext('2d')

  const texture = new THREE.CanvasTexture(canvas)

  return {
    texture,
    update() {
      if (!analyser) return

      analyser.getByteFrequencyData(dataArray)

      const imageData = ctx.createImageData(512, 1)

      for (let i = 0; i < 512; i++) {
        const v = dataArray[i] || 0

        imageData.data[i * 4 + 0] = v
        imageData.data[i * 4 + 1] = v
        imageData.data[i * 4 + 2] = v
        imageData.data[i * 4 + 3] = 255
      }

      ctx.putImageData(imageData, 0, 0)
      texture.needsUpdate = true
    }
  }
}


const startAudio = async () => {
  if (!audioContext) {
    await initAudio()
  }

  if (audioContext.state === 'suspended') {
    await audioContext.resume()
  }
}


const getCurrentDate = () => {
  const now = new Date()
  const seconds = now.getHours() * 3600 + now.getMinutes() * 60 + now.getSeconds()
  return new THREE.Vector4(now.getFullYear(), now.getMonth() + 1, now.getDate(), seconds)
}

/**
 * 下面的代码注释不影响画面功能
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
 */

const animate = () => {
  animationId = requestAnimationFrame(animate)
  
  const currentTime = performance.now() / 1000
  const deltaTime = Math.min(currentTime - lastTime, 0.033)
  audioTexture.update()
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
  renderer.render(scene, camera) 
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