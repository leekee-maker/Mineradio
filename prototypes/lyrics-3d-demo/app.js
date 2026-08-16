import * as THREE from "https://unpkg.com/three@0.180.0/build/three.module.js";

const lyrics = [
  { time: 0, text: "你总是微笑如花" },
  { time: 4.8, text: "总是看我沉醉和绝望" },
  { time: 9.6, text: "我却迟迟都没发现真爱" },
  { time: 14.8, text: "原来就在我身旁" },
  { time: 20.2, text: "你应该被呵护被珍藏" },
  { time: 25.2, text: "而不是这样独自流浪" },
  { time: 30.4, text: "让我成为你的光" },
  { time: 35.6, text: "穿过漫长黑夜和风霜" },
  { time: 40.8, text: "小小的太阳也能照亮" }
];

const duration = 44;
const lineHeight = 54;
const lyricsTrack = document.querySelector("#lyricsTrack");
const lyricsViewport = document.querySelector("#lyricsViewport");
const progress = document.querySelector("#progress");
const currentTime = document.querySelector("#currentTime");
const playToggle = document.querySelector("#playToggle");
const modeToggle = document.querySelector("#modeToggle");

let isPlaying = true;
let isCrawl = true;
let startedAt = performance.now();
let pausedAt = 0;

lyricsTrack.innerHTML = lyrics
  .map((line, index) => `<p class="lyric-line" data-index="${index}">${line.text}</p>`)
  .join("");

const lineEls = [...document.querySelectorAll(".lyric-line")];

modeToggle.addEventListener("click", () => {
  isCrawl = !isCrawl;
  lyricsViewport.classList.toggle("crawl-mode", isCrawl);
  lyricsViewport.classList.toggle("flat-mode", !isCrawl);
  modeToggle.textContent = isCrawl ? "切换：平铺" : "切换：星空";
});

playToggle.addEventListener("click", () => {
  const now = getTime();
  isPlaying = !isPlaying;
  pausedAt = now;
  startedAt = performance.now() - now * 1000;
  playToggle.textContent = isPlaying ? "Ⅱ" : "▶";
});

progress.addEventListener("input", () => {
  const nextTime = (Number(progress.value) / 1000) * duration;
  pausedAt = nextTime;
  startedAt = performance.now() - nextTime * 1000;
  renderLyrics(nextTime);
});

function getTime() {
  if (!isPlaying) return pausedAt;
  return ((performance.now() - startedAt) / 1000) % duration;
}

function activeIndexAt(time) {
  let activeIndex = 0;
  for (let index = 0; index < lyrics.length; index += 1) {
    if (time >= lyrics[index].time) activeIndex = index;
  }
  return activeIndex;
}

function formatTime(time) {
  const minute = Math.floor(time / 60);
  const second = Math.floor(time % 60).toString().padStart(2, "0");
  return `${minute}:${second}`;
}

function renderLyrics(time) {
  const activeIndex = activeIndexAt(time);
  const nextLine = lyrics[activeIndex + 1];
  const currentLine = lyrics[activeIndex];
  const segment = nextLine ? nextLine.time - currentLine.time : duration - currentLine.time;
  const localProgress = Math.min(1, Math.max(0, (time - currentLine.time) / segment));
  const y = 146 - (activeIndex + localProgress) * lineHeight;

  lyricsTrack.style.setProperty("--crawl-y", `${y}px`);
  lyricsTrack.style.setProperty("--flat-y", `${118 - activeIndex * lineHeight}px`);
  progress.value = String(Math.round((time / duration) * 1000));
  currentTime.textContent = formatTime(time);

  lineEls.forEach((el, index) => {
    const distance = Math.abs(index - activeIndex);
    el.classList.toggle("is-current", index === activeIndex);
    el.style.opacity = String(Math.max(0.12, 1 - distance * 0.18));
  });
}

const canvas = document.querySelector("#stars");
const renderer = new THREE.WebGLRenderer({ canvas, alpha: true, antialias: true });
const scene = new THREE.Scene();
const camera = new THREE.PerspectiveCamera(60, 1, 1, 1000);
camera.position.z = 160;

const stars = 1200;
const positions = new Float32Array(stars * 3);
const colors = new Float32Array(stars * 3);
const color = new THREE.Color();

for (let i = 0; i < stars; i += 1) {
  positions[i * 3] = (Math.random() - 0.5) * 520;
  positions[i * 3 + 1] = (Math.random() - 0.5) * 760;
  positions[i * 3 + 2] = -Math.random() * 760;

  color.setHSL(0.56 + Math.random() * 0.18, 0.7, 0.62 + Math.random() * 0.24);
  colors[i * 3] = color.r;
  colors[i * 3 + 1] = color.g;
  colors[i * 3 + 2] = color.b;
}

const geometry = new THREE.BufferGeometry();
geometry.setAttribute("position", new THREE.BufferAttribute(positions, 3));
geometry.setAttribute("color", new THREE.BufferAttribute(colors, 3));

const material = new THREE.PointsMaterial({
  size: 1.8,
  vertexColors: true,
  transparent: true,
  opacity: 0.86,
  depthWrite: false,
  blending: THREE.AdditiveBlending
});

const starField = new THREE.Points(geometry, material);
scene.add(starField);

function resize() {
  const width = window.innerWidth;
  const height = window.innerHeight;
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
  renderer.setSize(width, height, false);
  camera.aspect = width / height;
  camera.updateProjectionMatrix();
}

window.addEventListener("resize", resize);
resize();

function animate() {
  const time = getTime();
  renderLyrics(time);

  starField.rotation.y += isPlaying ? 0.0007 : 0.00016;
  starField.rotation.x = Math.sin(performance.now() * 0.00016) * 0.08;
  renderer.render(scene, camera);
  requestAnimationFrame(animate);
}

animate();
