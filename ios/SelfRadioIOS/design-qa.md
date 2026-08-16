**Design QA — SelfRadio iOS soft-glow redesign**

- source visual truth path: `/var/folders/94/q8fw6ndj7cvb9bgd78102vgr0000gn/T/codex-clipboard-4922fd92-682c-4ca1-8878-a08fd09d6274.png`
- implementation screenshot path: `/tmp/selfradio-home-2.png`
- combined comparison evidence: `/tmp/selfradio-design-comparison.jpg`
- source pixels: 853 × 1844
- implementation pixels: 1206 × 2622
- viewport: iPhone 17 simulator, portrait, iOS 26.0.1, 402 × 874 points at 3×
- density normalization: both images proportionally downsampled to a 720 px comparison column
- state: signed-out home screen, no active playback

**Findings**

- No actionable P0/P1/P2 visual issues remain in the captured home state.
- Fonts and typography: rounded, heavy Chinese display headings preserve the reference hierarchy; small supporting copy remains readable and does not compete with playback content.
- Spacing and layout rhythm: 20 pt outer margins, large rounded feature surfaces, and compact persistent navigation preserve clear mobile rhythm. The scroll inset leaves enough trailing space for the mini-player and navigation.
- Colors and visual tokens: warm off-white canvas, cyan/violet/rose glow, dark indigo text, translucent white surfaces, and low-opacity shadows consistently translate the source direction.
- Image quality and asset fidelity: supplied or remote cover artwork is used when available. The brand-gradient fallback is intentionally reserved for missing artwork; no emoji or improvised text glyphs replace icons.
- Copy and content: navigation and feature labels describe SelfRadio capabilities rather than copying decorative reference lyrics into unrelated screens.

**Full-view comparison evidence**

- The implementation retains the reference's airy light canvas, cyan-to-violet-to-pink focal color, oversized rounded focal surface, dark indigo hierarchy, and restrained chrome.
- The home screen is intentionally not a pixel clone of the player screenshot: it translates the same design system to discovery and navigation while the full-screen player owns the source composition.

**Focused region comparison evidence**

- Header: brand lockup and subtitle use the same centered/compact visual language with dark indigo foreground.
- Hero/cover treatment: large rounded gradient surface and soft glow match the reference album-art focal treatment.
- Bottom navigation: translucent rounded material, violet selected state, and generous hit targets maintain the same soft-glass control language.

**Primary interactions verified**

- App compiles for the iOS simulator.
- App installs and launches on an iPhone 17 simulator.
- Home renders without clipping or startup crash.
- Player, search, library, account, queue, lyrics, and effects code paths compile; live account/network flows require configured service credentials and are not asserted by visual QA.
- Lock-screen Now Playing metadata now loads, caches, and publishes the current song artwork; late responses are prevented from replacing a newer song's cover.
- Signed iPhone device build succeeded and was installed on the paired iPhone 15 Plus.

**Comparison history**

- Iteration 1: simulator capture showed the app had not yet surfaced because initial simulator migration was still running; waited for boot completion and relaunched.
- Iteration 2: home screen rendered at the intended viewport. No P0/P1/P2 layout mismatch was found.
- Iteration 3: the lock-screen media card omitted `MPMediaItemPropertyArtwork`, leaving its thumbnail empty. Added remote cover loading, in-memory caching, stale-request protection, and republishing of Now Playing metadata.
- Iteration 4: physical-device playback crashed when MediaPlayer requested artwork from a background queue because the callback inherited `MainActor` isolation. Moved artwork construction to a `nonisolated` factory with an explicit `@Sendable` callback; regression tests and signed device build pass. Physical-device reinstall is pending device reconnection.

**Follow-up Polish**

- P3: replace gradient fallback art with per-station editorial artwork once final content is available.
- P3: tune beat-driven cover breathing on physical devices after energy-impact profiling.

**Implementation Checklist**

- Verify platform login and playback with production credentials.
- Capture the active full-screen player and lyrics states on a physical iPhone.
- Profile animation energy use before App Store release.

---

**Design QA — SelfRadio iOS search redesign**

- source visual truth path: `/var/folders/94/q8fw6ndj7cvb9bgd78102vgr0000gn/T/codex-clipboard-541ebe4a-087b-4a98-ba30-4d2abcb519de.png`
- implementation screenshot path: `/tmp/selfradio-search-redesign.png`
- combined comparison evidence: `/tmp/selfradio-search-comparison.jpg`
- source pixels: 1179 × 2556
- implementation pixels: 1206 × 2622
- viewport: iPhone 17 simulator, portrait, iOS 26.0, 402 × 874 points at 3×
- density normalization: both screenshots proportionally downsampled to 600 px comparison columns
- state: search discovery with one persisted history item, no keyboard, no active mini-player

**Findings**

- No actionable P0/P1/P2 visual issues remain in the final search state.
- Fonts and typography: native rounded display weights preserve SelfRadio hierarchy while matching the reference's bold section headers and compact ranking rows.
- Spacing and layout rhythm: search bar, provider selector, four shortcuts, history, discovery chips, and horizontal hot-search cards follow the reference's top-to-bottom information density without crowding.
- Colors and visual tokens: the reference's dark palette is intentionally translated into SelfRadio's established soft-glow canvas, violet selected state, white material cards, and dark-indigo foreground.
- Image quality and asset fidelity: the redesigned search state does not require editorial raster assets; all visible controls use native SF Symbols. Home discovery now accepts only valid cover URLs, upgrades HTTP artwork to HTTPS, and does not render image-less playlist cards.
- Copy and content: labels are SelfRadio-specific and the three source-platform filters remain explicit.

**Full-view comparison evidence**

- Both views prioritize the search field, shortcut row, history, discovery chips, and partially revealed second ranking card.
- The QQ promotional banner and AI assistant entry are intentionally omitted because they are unrelated to SelfRadio's product scope; source-platform filters occupy that hierarchy instead.

**Focused region comparison evidence**

- Header: compact back control, large rounded search field, and trailing search action align with the reference interaction model.
- Discovery: history deletion, chip wrapping, and vertical section rhythm are preserved.
- Rankings: numbered rows, emphasized top-three ranks, secondary descriptions, and a horizontally clipped next card mirror the source affordance.

**Primary interactions verified**

- Home opens the redesigned search screen without automatically showing the keyboard.
- Custom bottom navigation hides while search is open and restores after leaving.
- Tapping `周杰伦` performs a live NetEase search and returns 20 playable result rows.
- Production discovery endpoint returned 16 chart cards: 12 NetEase charts, 0 missing covers, and 0 insecure HTTP covers.

**Comparison history**

- Iteration 1: the keyboard opened automatically and custom bottom navigation overlapped search content, hiding the ranking cards. Removed initial focus and added search-route chrome state.
- Iteration 2: full search discovery layout is visible without overlap; reference and implementation were combined into the recorded comparison image. No remaining P0/P1/P2 mismatch.

**Follow-up Polish**

- P3: replace static search-discovery terms with a future server-provided trending-keywords endpoint.

final result: passed
**Design QA — Playback & Audio Quality redesign (方案 1)**

- source visual truth: latest generated image option 1, “音质优先控制台”
- implementation target: `PlaybackSettingsView` in `RootView.swift`
- static verification: Swift frontend parse passed; iOS UI consistency/player tests passed (15/15); `git diff --check` passed
- runtime capture: blocked — Xcode reports no available iOS Simulator runtimes and CoreSimulatorService is unavailable
- final result: blocked

**Implemented scope**

- Current playback quality hero card with source and actual quality
- Smart / standard / 320K / lossless quality selection
- Audio-effect controls intentionally omitted until a real DSP chain is available
- Quality selection now re-resolves and restarts the current song when possible
- Strict source fallback, lyric offset, and background playback status retained
- Removed duplicate page heading and split controls into 音质 / 听感 / 播放策略 groups
- Added 播放页右上角“更多 → 播放与音质效果”; configuration route hides Dock and mini-player chrome
