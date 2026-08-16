# SelfRadio Mobile Prototype — Design QA

## Comparison Target

- Source visual truth: `/Users/tcg/.codex/generated_images/019fa99e-323f-77e0-84cf-089369853b31/exec-9d65d93f-67ec-43ea-b9d4-820084865489.png`
- Implementation screenshot: `/Users/tcg/Documents/cursor_project/Mineradio音乐播放器/prototypes/selfradio-mobile/implementation-mobile-screen-final.png`
- Combined comparison: `/Users/tcg/Documents/cursor_project/Mineradio音乐播放器/prototypes/selfradio-mobile/design-comparison-final.png`
- Browser viewport: `1400 × 1200`
- App viewport: `393 × 852` CSS px, deviceScaleFactor `1`
- Source pixels: `853 × 1844`, normalized with center-fit to `393 × 852`
- Implementation pixels: `393 × 852`
- State: iPhone, default Now Playing screen, QQ音乐 · SQ, playing, 柔光空间

## Evidence

### Full-view comparison

The combined comparison verifies the selected bright soft-light direction, centered brand lockup, rounded gradient cover, readable synchronized lyrics, source pill, progress control, transport controls, queue action, scene action, and smart-source note. Template-owned status bar, Dynamic Island, bezel, and home indicator are expected runtime differences and are excluded from app-owned fidelity findings.

### Focused regions

No separate focused crop was required. Both source and implementation were normalized to the native `393 × 852` app viewport and all important typography, iconography, source labels, progress values, and controls are legible in the combined full-view comparison.

## Required Fidelity Surfaces

- Fonts and typography: system iOS/PingFang-style stack, hierarchy and Chinese copy match the selected direction; the default player keeps one active lyric as the strongest text moment.
- Spacing and layout rhythm: all app-owned controls fit above the iOS home-indicator safe area with no clipping or persistent-control overflow.
- Colors and visual tokens: pearl base, lavender/sky/coral lighting, dark indigo text, and restrained translucent surfaces match the selected visual language.
- Image quality and asset fidelity: generated soft-light background, supplied SelfRadio logo asset, and generated playback-control orb are sharp raster assets; no visible asset is replaced by placeholder, emoji, CSS drawing, or handcrafted SVG.
- Copy and content: song, artist, synchronized lyric, source, quality, queue, scene, and smart-source copy are complete and readable.

## Findings

- No actionable P0, P1, or P2 visual differences remain.
- [P3] The native runtime status bar reduces the app-owned vertical area slightly versus the image concept. The implementation compensates by tightening the cover and lyric spacing without changing hierarchy.

## Interaction Verification

- Play/pause toggles correctly and updates the accessible control state.
- The default player shows one time-synchronized lyric; tapping it opens the complete lyric view, and the back control returns to playback.
- Progress uses an app-owned visible track, fill, and thumb instead of browser-native styling; the slider responds to touch-equivalent adjustment.
- Source sheet opens; selecting 网易云音乐 changes the source pill to `网易云音乐 · Hi-Res` and dismisses the sheet.
- Queue sheet opens; selecting `下山` updates the song title, lyrics, timer, and playback state.
- Sound-scene sheet opens; selecting `纯净歌词` updates the visible action and dismisses the sheet.
- Click-outside dismissal is provided by the runtime BottomSheet.
- Fresh iPhone viewport visual check: player, full lyrics, safe area, return action, and explicit progress track passed.
- `npm run check:runtime`: passed.
- `npm run test:runtime`: 10/10 passed.
- `npm run build`: passed.

## Comparison History

1. First implementation: [P2] the smart-source note fell under the home-indicator safe area. Fixed by reducing cover size and tightening vertical spacing across lyrics and controls. Post-fix evidence: `implementation-mobile-screen-v2.png`.
2. Second implementation: [P2] the pause control used a flat color instead of the selected concept's luminous brand treatment. Fixed with a dedicated generated raster asset. Post-fix evidence: `implementation-mobile-screen-final.png` and `design-comparison-final.png`.
3. Playback interaction iteration: [P1] multi-line lyrics depended on a gesture-heavy layout and the native range track could become nearly invisible in WebView. Replaced with one dynamic lyric that opens a complete lyric view, plus an app-owned progress track, fill, and thumb. Verified in an iPhone viewport and by user-facing Playwright tests.

## Follow-up Polish

- Optional P3: connect lyric timestamps from the real music source instead of evenly distributing mock lyric lines across the track duration.

final result: passed
