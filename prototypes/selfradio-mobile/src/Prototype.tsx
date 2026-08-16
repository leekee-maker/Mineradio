import { useEffect, useMemo, useState } from "react";
import {
  CheckIcon,
  ChevronDownIcon,
  ChevronLeftIcon,
  DotsHorizontalIcon,
  ListBulletIcon,
  MagicWandIcon,
  PauseIcon,
  PlayIcon,
  TrackNextIcon,
  TrackPreviousIcon,
  UpdateIcon,
} from "@radix-ui/react-icons";
import { BottomSheet, MobileScroll } from "./mobile";

type SourceId = "qq" | "netease" | "qishui";
type Panel = "source" | "queue" | "scene" | null;

const sources = [
  { id: "qq" as const, name: "QQ音乐", quality: "SQ", note: "当前账号已登录" },
  { id: "netease" as const, name: "网易云音乐", quality: "Hi-Res", note: "可播放 · 音质更高" },
  { id: "qishui" as const, name: "汽水音乐", quality: "高清", note: "可播放 · 响应最快" },
];

const tracks = [
  {
    title: "深情的戏骗人的计算",
    artist: "小梁的（梁思琪）",
    duration: 276,
    lyrics: ["别总是为难自己", "对谁都想要不留余地", "她自由自在花天酒地", "却找不到可以相信的自己", "你说爱是一种放任"],
  },
  {
    title: "下山",
    artist: "徐泽",
    duration: 232,
    lyrics: ["要想练就绝世武功", "就要忍受常人难忍受的痛", "师傅喜欢喝的茶叫乌龙", "衣服爱穿中国红"],
  },
  {
    title: "谢谢侬",
    artist: "陈奕迅",
    duration: 261,
    lyrics: ["累得很突然", "什么都不想再管", "谢谢侬", "把我带回音乐里面"],
  },
];

function formatTime(value: number) {
  const minutes = Math.floor(value / 60);
  const seconds = Math.floor(value % 60).toString().padStart(2, "0");
  return `${minutes}:${seconds}`;
}

export default function Prototype() {
  const [trackIndex, setTrackIndex] = useState(0);
  const [source, setSource] = useState<SourceId>("qq");
  const [playing, setPlaying] = useState(true);
  const [elapsed, setElapsed] = useState(88);
  const [panel, setPanel] = useState<Panel>(null);
  const [scene, setScene] = useState("柔光空间");
  const [showFullLyrics, setShowFullLyrics] = useState(false);

  const track = tracks[trackIndex];
  const activeSource = useMemo(() => sources.find((item) => item.id === source) ?? sources[0], [source]);
  const progress = Math.min(100, (elapsed / track.duration) * 100);
  const activeLyricIndex = Math.min(track.lyrics.length - 1, Math.floor((progress / 100) * track.lyrics.length));
  const activeLyric = track.lyrics[activeLyricIndex];

  useEffect(() => {
    if (!playing) return;
    const timer = window.setInterval(() => {
      setElapsed((value) => (value >= track.duration ? 0 : value + 1));
    }, 1000);
    return () => window.clearInterval(timer);
  }, [playing, track.duration]);

  const changeTrack = (direction: number) => {
    setTrackIndex((index) => (index + direction + tracks.length) % tracks.length);
    setElapsed(0);
    setPlaying(true);
  };

  return (
    <>
      <MobileScroll key={showFullLyrics ? "lyrics" : "player"} className="app-screen player-scroll">
        {showFullLyrics ? (
          <main className="full-lyrics-screen" data-testid="full-lyrics-screen" aria-label="完整歌词">
            <header className="lyrics-header">
              <button className="icon-button" type="button" aria-label="返回播放页" onClick={() => setShowFullLyrics(false)}>
                <ChevronLeftIcon />
              </button>
              <div>
                <strong>{track.title}</strong>
                <span>{track.artist}</span>
              </div>
              <span aria-hidden="true" />
            </header>

            <section className="full-lyrics-list" aria-live="polite">
              {track.lyrics.map((line, index) => (
                <p className={index === activeLyricIndex ? "active" : ""} key={line}>{line}</p>
              ))}
            </section>

            <section className="full-lyrics-footer">
              <div className="lyrics-footer-meta">
                <img src="/assets/selfradio/selfradio-icon.png" alt="" />
                <span><strong>{track.title}</strong><small>{activeSource.name} · {activeSource.quality}</small></span>
                <button type="button" className="mini-play-button" aria-label={playing ? "暂停" : "播放"} onClick={() => setPlaying((value) => !value)}>
                  {playing ? <PauseIcon /> : <PlayIcon />}
                </button>
              </div>
              <ProgressBar elapsed={elapsed} duration={track.duration} onChange={setElapsed} />
            </section>
          </main>
        ) : (
        <main className="player-screen" data-testid="player-screen" aria-label="SelfRadio 正在播放">
          <header className="player-header">
            <button className="icon-button" type="button" aria-label="收起播放器">
              <ChevronDownIcon />
            </button>
            <div className="brand-lockup">
              <strong>SelfRadio</strong>
              <span>柔光私人电台</span>
            </div>
            <button className="icon-button" type="button" aria-label="更多操作">
              <DotsHorizontalIcon />
            </button>
          </header>

          <section className={`cover-stage ${playing ? "is-playing" : ""}`} aria-label="专辑封面">
            <img src="/assets/selfradio/selfradio-icon.png" alt="SelfRadio 专辑封面" draggable="false" />
          </section>

          <section className="track-meta" aria-live="polite">
            <h1>{track.title}</h1>
            <p>{track.artist}</p>
            <button className="source-pill" type="button" onClick={() => setPanel("source")} aria-label="切换音源">
              <span className={`source-dot source-${source}`} />
              <span>{activeSource.name} · {activeSource.quality}</span>
              <ChevronDownIcon />
            </button>
          </section>

          <button className="current-lyric" data-testid="current-lyric" type="button" onClick={() => setShowFullLyrics(true)}>
            <span key={`${trackIndex}-${activeLyricIndex}`}>{activeLyric}</span>
            <small>点击查看完整歌词</small>
          </button>

          <section className="timeline" aria-label="播放进度">
            <ProgressBar elapsed={elapsed} duration={track.duration} onChange={setElapsed} />
          </section>

          <section className="playback-controls" aria-label="播放控制">
            <button type="button" className="transport-button" aria-label="上一首" onClick={() => changeTrack(-1)}>
              <TrackPreviousIcon />
            </button>
            <button
              data-testid="play-toggle"
              type="button"
              className="play-button"
              aria-label={playing ? "暂停" : "播放"}
              onClick={() => setPlaying((value) => !value)}
            >
              {playing ? <PauseIcon /> : <PlayIcon />}
            </button>
            <button type="button" className="transport-button" aria-label="下一首" onClick={() => changeTrack(1)}>
              <TrackNextIcon />
            </button>
          </section>

          <section className="secondary-actions" aria-label="播放工具">
            <button type="button" onClick={() => setPanel("queue")}>
              <ListBulletIcon />
              <span>播放队列</span>
            </button>
            <button type="button" onClick={() => setPanel("scene")}>
              <MagicWandIcon />
              <span>{scene}</span>
            </button>
          </section>

          <p className="smart-source-note"><UpdateIcon /> 下一首将自动匹配最佳音源</p>
        </main>
        )}
      </MobileScroll>

      <BottomSheet open={panel === "source"} onOpenChange={(open) => setPanel(open ? "source" : null)} title="切换音源" description="同一首歌，选择当前可用的最佳版本。">
        <div className="sheet-list" data-testid="source-sheet">
          {sources.map((item) => (
            <button
              type="button"
              className="sheet-row"
              key={item.id}
              onClick={() => { setSource(item.id); setPanel(null); }}
            >
              <span className={`source-mark source-${item.id}`} />
              <span className="sheet-row-copy"><strong>{item.name}</strong><small>{item.note}</small></span>
              <span className="quality-tag">{item.quality}</span>
              {source === item.id ? <CheckIcon /> : null}
            </button>
          ))}
        </div>
      </BottomSheet>

      <BottomSheet open={panel === "queue"} onOpenChange={(open) => setPanel(open ? "queue" : null)} title="播放队列" description="跨平台歌单将自动寻找可用音源。">
        <div className="sheet-list" data-testid="queue-sheet">
          {tracks.map((item, index) => (
            <button type="button" className={`sheet-row queue-row ${index === trackIndex ? "selected" : ""}`} key={item.title} onClick={() => { setTrackIndex(index); setElapsed(0); setPlaying(true); setPanel(null); }}>
              <span className="queue-index">{index === trackIndex ? <PauseIcon /> : index + 1}</span>
              <span className="sheet-row-copy"><strong>{item.title}</strong><small>{item.artist}</small></span>
              <span className="quality-tag">{index === 1 ? "网易云" : index === 2 ? "汽水" : "QQ音乐"}</span>
            </button>
          ))}
        </div>
      </BottomSheet>

      <BottomSheet open={panel === "scene"} onOpenChange={(open) => setPanel(open ? "scene" : null)} title="音效空间" description="选择跟随音乐呼吸的视觉氛围。">
        <div className="scene-options" data-testid="scene-sheet">
          {["柔光空间", "纯净歌词", "夜间低光"].map((item) => (
            <button type="button" className={scene === item ? "selected" : ""} key={item} onClick={() => { setScene(item); setPanel(null); }}>
              <span>{item}</span>
              {scene === item ? <CheckIcon /> : null}
            </button>
          ))}
        </div>
      </BottomSheet>
    </>
  );
}

function ProgressBar({ elapsed, duration, onChange }: { elapsed: number; duration: number; onChange: (value: number) => void }) {
  const progress = Math.min(100, (elapsed / duration) * 100);

  return (
    <>
      <div className="progress-control">
        <div className="progress-track" data-testid="progress-track" aria-hidden="true">
          <div className="progress-fill" data-testid="progress-fill" style={{ width: `${progress}%` }} />
        </div>
        <input
          data-testid="progress-slider"
          type="range"
          min="0"
          max={duration}
          value={elapsed}
          aria-label="播放进度"
          onChange={(event) => onChange(Number(event.target.value))}
        />
      </div>
      <div className="time-row">
        <span>{formatTime(elapsed)}</span>
        <span>-{formatTime(Math.max(0, duration - elapsed))}</span>
      </div>
    </>
  );
}
