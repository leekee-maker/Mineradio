import { useMemo, useRef, useState } from "react";
import { ThreeUniverseScene } from "./ThreeUniverseScene.jsx";

const DEMO_ALBUMS = [
  ["274336916", "即兴曲", "https://p3.music.126.net/O3jMNNilsLAdv1L85QlRZg==/109951171855827699.jpg"],
  ["259316984", "Six Degrees", "https://p4.music.126.net/rpAHIH09Z4Z1VGFV-CFewg==/109951171855825453.jpg"],
  ["241205548", "稻香 · Remix摇滚版", "https://p3.music.126.net/1cfHryFKjKHKJBrBrg9thg==/109951169749328875.jpg"],
  ["181638865", "圣诞星", "https://p3.music.126.net/3I77JdZCovBeNY6qvDl0-A==/109951169196882630.jpg"],
  ["147779282", "最伟大的作品", "https://p4.music.126.net/CX4CQLTVIso3F7bRUOwyRw==/109951171855825374.jpg"],
  ["90743831", "Mojito", "https://p4.music.126.net/d_yieD2xJu5VBydT-5U1ig==/109951167909350869.jpg"],
  ["84129171", "我是如此相信", "https://p4.music.126.net/uTI9r_-vSQ1nMTNoJYRDeg==/109951167896046972.jpg"],
  ["82918363", "地表最强巡回演唱会", "https://p3.music.126.net/qY6cK2wR2y55e4jYzCAs8Q==/109951172020012668.jpg"],
  ["81679689", "说好不哭", "https://p4.music.126.net/21uOFOUHXHDHuwAFRgEZSg==/109951164615900701.jpg"],
  ["38721188", "不爱我就拉倒", "https://p4.music.126.net/iHtm5f8JUy-ndnGW-3eE0Q==/109951167749318205.jpg"],
  ["37251353", "等你下课", "https://p3.music.126.net/A8qicH14toObbLpPMiKmBw==/109951163110962030.jpg"],
  ["34720827", "周杰伦的床边故事", "https://p3.music.126.net/cUTk0ewrQtYGP2YpPZoUng==/3265549553028224.jpg"],
  ["34685590", "魔天伦巡回演唱会", "https://p3.music.126.net/23lKa3CBQbCwUH5a4EsYWw==/109951171937474980.jpg"],
  ["34588039", "英雄", "https://p3.music.126.net/9JOVl48dMe7U8zShniMPcA==/1372190515036862.jpg"],
].map(([id, name, cover]) => ({ id, name, cover }));

function StarField() {
  const stars = useMemo(() => Array.from({ length: 190 }, (_, index) => ({
    left: `${(index * 47.31) % 100}%`,
    top: `${(index * 83.17) % 100}%`,
    size: `${1 + (index % 3) * 0.7}px`,
    opacity: 0.22 + (index % 7) * 0.09,
    delay: `${-(index % 9) * 0.7}s`,
  })), []);
  return <div className="universe-stars" aria-hidden="true">{stars.map((star, index) => <i key={index} style={star} />)}</div>;
}

export function UniversePrototype() {
  const stageRef = useRef(null);
  const pointers = useRef(new Map());
  const dragRef = useRef({ x: 0, angle: -0.38 });
  const pinchRef = useRef({ distance: 0, zoom: 1 });
  const [angle, setAngle] = useState(-0.38);
  const [zoom, setZoom] = useState(1);
  const [resetToken, setResetToken] = useState(0);
  const [selectedId, setSelectedId] = useState(DEMO_ALBUMS[0].id);
  const [drawerOpen, setDrawerOpen] = useState(false);

  const selected = DEMO_ALBUMS.find((album) => album.id === selectedId) || DEMO_ALBUMS[0];
  const orbitItems = useMemo(() => DEMO_ALBUMS.map((album, index) => {
    const jitter = Math.sin(index * 17.71) * 0.16;
    const theta = angle + (Math.PI * 2 * index) / DEMO_ALBUMS.length + jitter;
    const orbitRadius = 0.84 + (Math.sin(index * 5.13) * 0.5 + 0.5) * 0.28;
    const depth = Math.min(1, Math.max(0, (Math.sin(theta) + 1) / 2 + Math.sin(index * 9.7) * 0.08));
    return {
      album,
      x: Math.cos(theta) * 35 * orbitRadius * zoom,
      y: Math.sin(theta) * 23 * orbitRadius * zoom,
      z: (depth - 0.5) * 180 + Math.sin(index * 3.2) * 26,
      scale: (0.48 + ((index * 29) % 9) / 18) * (0.72 + depth * 0.42),
      size: 62 + ((index * 41) % 46),
      opacity: 0.24 + depth * 0.76,
      depth,
    };
  }), [angle, zoom]);

  function beginPointer(event) {
    if (event.target.closest("button")) return;
    pointers.current.set(event.pointerId, { x: event.clientX, y: event.clientY });
    event.currentTarget.setPointerCapture?.(event.pointerId);
    if (pointers.current.size === 1) dragRef.current = { x: event.clientX, angle };
    if (pointers.current.size === 2) {
      const [a, b] = [...pointers.current.values()];
      pinchRef.current = { distance: Math.hypot(a.x - b.x, a.y - b.y), zoom };
    }
  }

  function movePointer(event) {
    if (!pointers.current.has(event.pointerId)) return;
    pointers.current.set(event.pointerId, { x: event.clientX, y: event.clientY });
    if (pointers.current.size >= 2) {
      const [a, b] = [...pointers.current.values()];
      const distance = Math.hypot(a.x - b.x, a.y - b.y);
      if (pinchRef.current.distance > 0) setZoom(Math.min(1.55, Math.max(0.72, pinchRef.current.zoom * distance / pinchRef.current.distance)));
      return;
    }
    const delta = (event.clientX - dragRef.current.x) / Math.max(stageRef.current?.clientWidth || 1, 1);
    setAngle(dragRef.current.angle + delta * Math.PI * 1.35);
  }

  function endPointer(event) {
    pointers.current.delete(event.pointerId);
    if (pointers.current.size === 0) pinchRef.current.distance = 0;
  }

  function resetView() {
    setZoom(1);
    setResetToken((value) => value + 1);
  }

  return (
    <main className="universe-page">
      <header className="universe-header">
        <a href="/" className="universe-back">‹ <span>返回 SelfRadio</span></a>
        <div className="universe-title"><span className="universe-kicker">MUSIC UNIVERSE / WEB PROTOTYPE</span><h1>音乐宇宙</h1></div>
        <button className="universe-reset" onClick={resetView}>重置视角</button>
      </header>

      <section className="universe-layout">
        <div className="universe-copy">
          <p className="universe-eyebrow">ARTIST CONSTELLATION</p>
          <h2>周杰伦</h2>
          <p>14 个轨道节点 · 全部专辑将在后台补齐</p>
          <div className="universe-hints"><span>拖拽旋转</span><span>滚轮 / 双指缩放</span><span>点击专辑查看</span></div>
        </div>

        <div className="universe-stage">
          <div className="universe-milky-way" aria-hidden="true" />
          <ThreeUniverseScene albums={DEMO_ALBUMS} selectedId={selectedId} onSelectAlbum={setSelectedId} resetToken={resetToken} onZoomChange={setZoom} />
          <div className="universe-stage-footer"><span>✦</span><span>Drag to browse</span><span>双指或滚轮缩放空间</span></div>
          <div className="universe-zoom-readout">{Math.round(zoom * 100)}%</div>
        </div>

        <aside className={`universe-drawer ${drawerOpen ? "is-open" : ""}`}>
          <div className="drawer-head"><div><span>SELECTED ORBIT</span><h3>{selected.name}</h3></div><button onClick={() => setDrawerOpen(false)} aria-label="关闭列表">×</button></div>
          <p className="drawer-subtitle">歌曲详情按需加载，先保持星云流畅。</p>
          <button className="drawer-play" onClick={() => setDrawerOpen(false)}>▶ 播放整张</button>
          <div className="drawer-list">{DEMO_ALBUMS.map((album, index) => <button key={album.id} className={album.id === selectedId ? "is-active" : ""} onClick={() => { setSelectedId(album.id); setDrawerOpen(false); }}><span>{String(index + 1).padStart(2, "0")}</span><img src={album.cover} alt="" /><b>{album.name}</b><em>网易云</em></button>)}</div>
        </aside>
      </section>
      <button className="universe-drawer-toggle" onClick={() => setDrawerOpen(true)}>歌单抽屉 <span>↗</span></button>
    </main>
  );
}
