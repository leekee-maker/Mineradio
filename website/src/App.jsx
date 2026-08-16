import { useEffect, useState } from "react";
import {
  AppleLogo,
  ArrowUpRight,
  DownloadSimple,
  GithubLogo,
  ShieldCheck,
  Sparkle,
  UsersThree,
  Waveform,
  WindowsLogo,
} from "@phosphor-icons/react";
import { UniversePrototype } from "./UniversePrototype.jsx";

const WINDOWS_URL = import.meta.env.VITE_WINDOWS_DOWNLOAD_URL ||
  "/downloads/SelfRadio-2.0.3-Windows-x64-Setup.exe";
const MAC_URL = import.meta.env.VITE_MAC_DOWNLOAD_URL ||
  "/downloads/SelfRadio-2.0.3-macOS-universal.dmg";
const ASSET_BASE = import.meta.env.BASE_URL;

const downloads = [
  { id: "windows", label: "下载 Windows 版", detail: "Windows 10 / 11 · 64-bit", href: WINDOWS_URL, icon: WindowsLogo },
  { id: "mac", label: "下载 macOS 版", detail: "macOS 11+ · Apple Silicon / Intel", href: MAC_URL, icon: AppleLogo },
];

const features = [
  { title: "歌词舞台", copy: "逐字歌词与节奏同步，让每一句都拥有自己的镜头。", icon: Waveform },
  { title: "粒子视觉", copy: "动态粒子随音乐呼吸，让声音真正变得可见。", icon: Sparkle },
  { title: "多平台登录", copy: "支持网易云、QQ 音乐与汽水音乐，歌单随手同步。", icon: UsersThree },
];

function Brand() {
  return (
    <span className="brand-word" aria-label="SelfRadio">
      <span>Self</span><span>Ra</span><span>di</span><span>o</span>
    </span>
  );
}

function DownloadButton({ item, featured }) {
  const Icon = item.icon;
  return (
    <a className={`download-button ${featured ? "is-featured" : ""}`} href={item.href}
      download data-platform={item.id}>
      <Icon size={30} weight="fill" aria-hidden="true" />
      <span><strong>{item.label}</strong><small>{item.detail}</small></span>
      <DownloadSimple className="download-arrow" size={22} weight="bold" aria-hidden="true" />
    </a>
  );
}

export function App() {
  if (window.location.pathname === "/universe") return <UniversePrototype />;
  const [platform, setPlatform] = useState("");

  useEffect(() => {
    const value = navigator.userAgentData?.platform || navigator.platform || "";
    setPlatform(/mac|iphone|ipad/i.test(value) ? "mac" : /win/i.test(value) ? "windows" : "");
  }, []);

  const orderedDownloads = platform
    ? [...downloads].sort((a) => (a.id === platform ? -1 : 1))
    : downloads;

  return (
    <main>
      <header className="site-header">
        <a className="mini-brand" href="#top" aria-label="SelfRadio 首页">
          <img src={`${ASSET_BASE}assets/selfradio-icon-v5.png`} alt="" />
          <Brand />
        </a>
        <nav aria-label="主导航">
          <a href="#download">下载</a>
          <a href="/universe">音乐宇宙</a>
          <a href="https://github.com/leekee-maker/Mineradio" target="_blank" rel="noreferrer">
            GitHub <ArrowUpRight size={14} weight="bold" />
          </a>
        </nav>
      </header>

      <section className="hero" id="top">
        <img className="hero-stage" src={`${ASSET_BASE}assets/hero-stage.png`} alt="" />
        <div className="hero-content">
          <p className="eyebrow">YOUR PRIVATE VISUAL RADIO</p>
          <h1><Brand /></h1>
          <h2>让音乐成为你的私人现场</h2>
          <p className="hero-copy">沉浸式桌面音乐播放器，营造专属于你的听觉舞台。</p>

          <div className="download-grid" id="download">
            {orderedDownloads.map((item) => (
              <DownloadButton key={item.id} item={item} featured={item.id === platform} />
            ))}
          </div>

          <div className="release-meta">
            <span>当前版本 · v2.0.3</span><i aria-hidden="true" /><span>更新于 · 2026-07-29</span>
          </div>
          <p className="trust-line">
            <ShieldCheck size={18} weight="fill" aria-hidden="true" />
            开源透明 · 无广告 · 尊重隐私
          </p>
        </div>
      </section>

      <section className="feature-strip" aria-label="核心功能">
        {features.map((feature) => {
          const Icon = feature.icon;
          return (
            <article key={feature.title}>
              <Icon size={34} weight="duotone" aria-hidden="true" />
              <h3>{feature.title}</h3><p>{feature.copy}</p>
            </article>
          );
        })}
      </section>

      <footer>
        <div className="footer-brand">
          <img src={`${ASSET_BASE}assets/selfradio-icon-v5.png`} alt="" />
          <div><Brand /><small>radio.remjdor.cn</small></div>
        </div>
        <p>© 2026 SelfRadio. GPL-3.0 开源软件。</p>
        <a href="https://github.com/leekee-maker/Mineradio" target="_blank" rel="noreferrer" aria-label="SelfRadio GitHub">
          <GithubLogo size={24} weight="fill" />
        </a>
      </footer>
    </main>
  );
}
