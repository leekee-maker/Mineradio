import { useEffect, useRef } from "react";
import * as THREE from "three";
import { OrbitControls } from "three/examples/jsm/controls/OrbitControls.js";

function fallbackTexture(album) {
  const canvas = document.createElement("canvas");
  canvas.width = 512;
  canvas.height = 512;
  const context = canvas.getContext("2d");
  const gradient = context.createRadialGradient(150, 120, 15, 380, 410, 500);
  gradient.addColorStop(0, "#d9bbff");
  gradient.addColorStop(.34, "#6b4bc4");
  gradient.addColorStop(1, "#0b0a23");
  context.fillStyle = gradient;
  context.fillRect(0, 0, 512, 512);
  context.fillStyle = "rgba(255,255,255,.9)";
  context.font = "600 36px system-ui";
  context.textAlign = "center";
  context.fillText(album.name, 256, 275, 420);
  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  return texture;
}

export function ThreeUniverseScene({ albums, selectedId, onSelectAlbum, resetToken, onZoomChange }) {
  const mountRef = useRef(null);
  const resetRef = useRef(() => {});

  useEffect(() => {
    const mount = mountRef.current;
    if (!mount) return undefined;

    const scene = new THREE.Scene();
    const camera = new THREE.PerspectiveCamera(38, mount.clientWidth / mount.clientHeight, .1, 1000);
    camera.position.set(0, 1.1, 12.2);
    const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true, powerPreference: "high-performance" });
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 1.7));
    renderer.setSize(mount.clientWidth, mount.clientHeight);
    renderer.outputColorSpace = THREE.SRGBColorSpace;
    mount.appendChild(renderer.domElement);

    const controls = new OrbitControls(camera, renderer.domElement);
    controls.enablePan = false;
    controls.enableDamping = true;
    controls.dampingFactor = .075;
    controls.minDistance = 7;
    controls.maxDistance = 19;
    controls.target.set(0, 0, 0);
    controls.update();

    const ambient = new THREE.AmbientLight(0x6e63a8, 1.35);
    const keyLight = new THREE.DirectionalLight(0xe6d9ff, 4.6);
    keyLight.position.set(-4, 5, 8);
    const rimLight = new THREE.PointLight(0x8b5cff, 12, 24, 2);
    rimLight.position.set(3, -1, 4);
    scene.add(ambient, keyLight, rimLight);

    const starsGeometry = new THREE.BufferGeometry();
    const starPositions = [];
    for (let index = 0; index < 1000; index += 1) {
      const radius = 28 + ((index * 37) % 220) / 10;
      const theta = (index * 2.39996) % (Math.PI * 2);
      const phi = Math.acos(1 - 2 * ((index + 1) / 1001));
      starPositions.push(radius * Math.sin(phi) * Math.cos(theta), radius * Math.cos(phi), radius * Math.sin(phi) * Math.sin(theta));
    }
    starsGeometry.setAttribute("position", new THREE.Float32BufferAttribute(starPositions, 3));
    const stars = new THREE.Points(starsGeometry, new THREE.PointsMaterial({ color: 0xded9ff, size: .035, sizeAttenuation: true, transparent: true, opacity: .82 }));
    scene.add(stars);

    const orbitMaterial = new THREE.MeshBasicMaterial({ color: 0x9e75ff, transparent: true, opacity: .56 });
    const orbit = new THREE.Mesh(new THREE.TorusGeometry(4.55, .012, 8, 180), orbitMaterial);
    orbit.rotation.x = THREE.MathUtils.degToRad(62);
    orbit.rotation.z = THREE.MathUtils.degToRad(-7);
    scene.add(orbit);
    const orbitFar = new THREE.Mesh(new THREE.TorusGeometry(5.35, .007, 8, 180), new THREE.MeshBasicMaterial({ color: 0x5c6cbf, transparent: true, opacity: .2 }));
    orbitFar.rotation.x = THREE.MathUtils.degToRad(64);
    orbitFar.rotation.z = THREE.MathUtils.degToRad(12);
    scene.add(orbitFar);

    const textureLoader = new THREE.TextureLoader();
    const objects = [];
    const nodeGroup = new THREE.Group();
    scene.add(nodeGroup);
    albums.forEach((album, index) => {
      const theta = (Math.PI * 2 * index) / albums.length + Math.sin(index * 17.7) * .17;
      const radial = 4.25 + Math.sin(index * 5.13) * .6 + (index % 3) * .18;
      const depth = Math.sin(theta) * 1.3 + Math.sin(index * 2.7) * .35;
      const radius = .32 + ((index * 31) % 7) * .045;
      const texture = textureLoader.load(album.cover, undefined, undefined, () => {});
      texture.colorSpace = THREE.SRGBColorSpace;
      const material = new THREE.MeshStandardMaterial({ map: texture, roughness: .52, metalness: .08, emissive: 0x100b29, emissiveIntensity: .14 });
      const sphere = new THREE.Mesh(new THREE.SphereGeometry(radius, 36, 24), material);
      sphere.position.set(Math.cos(theta) * radial, Math.sin(theta) * 2.5, depth);
      sphere.userData.albumId = album.id;
      sphere.userData.album = album;
      sphere.userData.baseScale = .74 + (index % 5) * .12;
      sphere.scale.setScalar(sphere.userData.baseScale);
      nodeGroup.add(sphere);
      objects.push(sphere);
    });

    const selected = albums.find((album) => album.id === selectedId) || albums[0];
    const selectedTexture = textureLoader.load(selected.cover, undefined, undefined, () => {});
    selectedTexture.colorSpace = THREE.SRGBColorSpace;
    const coreMaterial = new THREE.MeshStandardMaterial({ map: selectedTexture, roughness: .4, metalness: .12, emissive: 0x26114c, emissiveIntensity: .18 });
    const core = new THREE.Mesh(new THREE.SphereGeometry(1.58, 64, 48), coreMaterial);
    core.userData.albumId = selected.id;
    scene.add(core);
    const coreGlow = new THREE.Mesh(new THREE.SphereGeometry(1.74, 48, 32), new THREE.MeshBasicMaterial({ color: 0x9966ff, transparent: true, opacity: .13, side: THREE.BackSide }));
    scene.add(coreGlow);

    const raycaster = new THREE.Raycaster();
    const pointer = new THREE.Vector2();
    let downX = 0;
    const onPointerDown = (event) => { downX = event.clientX; };
    const onPointerUp = (event) => {
      if (Math.abs(event.clientX - downX) > 6) return;
      const rect = renderer.domElement.getBoundingClientRect();
      pointer.x = ((event.clientX - rect.left) / rect.width) * 2 - 1;
      pointer.y = -((event.clientY - rect.top) / rect.height) * 2 + 1;
      raycaster.setFromCamera(pointer, camera);
      const hit = raycaster.intersectObjects([core, ...objects], false)[0];
      if (hit?.object?.userData?.albumId) onSelectAlbum(hit.object.userData.albumId);
    };
    renderer.domElement.addEventListener("pointerdown", onPointerDown);
    renderer.domElement.addEventListener("pointerup", onPointerUp);

    resetRef.current = () => { camera.position.set(0, 1.1, 12.2); controls.target.set(0, 0, 0); controls.update(); };
    onZoomChange?.(Math.round((12.2 / camera.position.distanceTo(controls.target)) * 100));
    let frameId;
    const animate = () => {
      controls.update();
      stars.rotation.y += .00012;
      orbit.rotation.y += .00018;
      orbitFar.rotation.y -= .00011;
      const zoom = Math.round((12.2 / camera.position.distanceTo(controls.target)) * 100);
      onZoomChange?.(zoom);
      renderer.render(scene, camera);
      frameId = requestAnimationFrame(animate);
    };
    animate();

    const resize = () => { camera.aspect = mount.clientWidth / mount.clientHeight; camera.updateProjectionMatrix(); renderer.setSize(mount.clientWidth, mount.clientHeight); };
    window.addEventListener("resize", resize);
    return () => {
      cancelAnimationFrame(frameId);
      window.removeEventListener("resize", resize);
      renderer.domElement.removeEventListener("pointerdown", onPointerDown);
      renderer.domElement.removeEventListener("pointerup", onPointerUp);
      controls.dispose();
      scene.traverse((object) => { object.geometry?.dispose(); if (object.material) { const materials = Array.isArray(object.material) ? object.material : [object.material]; materials.forEach((material) => { material.map?.dispose(); material.dispose(); }); } });
      renderer.dispose();
      mount.removeChild(renderer.domElement);
    };
  }, [albums, onSelectAlbum, selectedId, onZoomChange]);

  useEffect(() => { resetRef.current(); }, [resetToken]);
  return <div ref={mountRef} className="three-universe-scene" aria-label="Three.js 3D 音乐宇宙" />;
}
