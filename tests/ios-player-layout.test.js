'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const source = fs.readFileSync(path.resolve(__dirname, '..', 'ios/SelfRadioIOS/SelfRadioIOS/RootView.swift'), 'utf8');
const models = fs.readFileSync(path.resolve(__dirname, '..', 'ios/SelfRadioIOS/SelfRadioIOS/Models.swift'), 'utf8');
const playerStore = fs.readFileSync(path.resolve(__dirname, '..', 'ios/SelfRadioIOS/SelfRadioIOS/PlayerStore.swift'), 'utf8');
const infoPlist = fs.readFileSync(path.resolve(__dirname, '..', 'ios/SelfRadioIOS/SelfRadioIOS/Info.plist'), 'utf8');
const player = source.slice(source.indexOf('private struct PlayerView'), source.indexOf('private struct PlayerArtworkPage'));
const portraitLayout = source.slice(source.indexOf('private struct PortraitPlayerLayout'), source.indexOf('private struct LandscapePlayerLayout'));
const landscapeLayout = source.slice(source.indexOf('private struct LandscapePlayerLayout'), source.indexOf('private struct LandscapeArtworkPanel'));
const controls = source.slice(source.indexOf('private struct PlayerControlsView'), source.indexOf('private struct PlayerIconButton'));
const playbackModeButton = source.slice(source.indexOf('private struct PlaybackModeButton'), source.indexOf('private struct PlayerIconButton'));
const lyricPreview = source.slice(source.indexOf('private struct LyricPreviewView'), source.indexOf('private struct PlayerProgressView'));
const fullLyrics = source.slice(source.indexOf('private struct FullLyricsView'), source.indexOf('private struct QualitySheet'));
const queue = source.slice(source.indexOf('private struct QueueView'), source.indexOf('private struct EffectsView'));
const visualSettings = source.slice(source.indexOf('private struct VisualSettingsView'), source.indexOf('private struct SettingsCard'));
const songInfo = source.slice(source.indexOf('private struct SongInfoSheet'), source.indexOf('private struct SongInfoRow'));
const playlistDetail = source.slice(source.indexOf('private struct PlaylistDetailView'), source.indexOf('private struct PlaylistSongRow'));

test('the immersive player hides app navigation and provides a back action', () => {
  assert.match(source, /safeAreaInset[\s\S]{0,160}if selection != \.player/);
  assert.match(source, /case \.player:\s*PlayerView \{ selection = \.home \}/);
  assert.match(player, /Button\(action: onClose\)/);
  assert.match(player, /chevron\.left/);
  assert.match(player, /edgeBackOffset/);
  assert.match(player, /@State private var isDismissing = false/);
  assert.match(player, /simultaneousGesture\([\s\S]*DragGesture\(minimumDistance: 12\)/);
  assert.match(player, /gesture\.startLocation\.x <= 28/);
  assert.match(player, /gesture\.translation\.width > 92/);
  assert.match(player, /edgeBackOffset = min\(max\(gesture\.translation\.width, 0\), proxy\.size\.width\)/);
  assert.match(player, /withAnimation\(\.interactiveSpring\(response: 0\.32, dampingFraction: 0\.88\)\) \{ edgeBackOffset = proxy\.size\.width \}/);
  assert.match(player, /DispatchQueue\.main\.asyncAfter\(deadline: \.now\(\) \+ 0\.28\) \{ onClose\(\) \}/);
});

test('the player uses the simplified lyric-first playback layout', () => {
  assert.match(player, /PortraitPlayerLayout/);
  assert.match(source, /LyricPreviewView\(action: showLyrics\)/);
  assert.match(player, /PlayerProgressView\(\)/);
  assert.match(source, /PlayerControlsView\(showQueue: showQueue\)/);
  assert.doesNotMatch(player, /DragGesture\(\)\s*\.onChanged/);
  assert.doesNotMatch(player, /showingQuality/);
  assert.match(player, /showingSongInfo/);
  assert.match(source, /private struct SongInfoSheet/);
  assert.match(player, /PlayerMotionBackground\(\)/);
});

test('portrait player keeps the original layout for normal artwork and scrolls only tall posters', () => {
  assert.match(portraitLayout, /if player\.artworkAspectRatio < 1/);
  assert.match(portraitLayout, /ScrollView\(showsIndicators: false\)/);
  assert.match(portraitLayout, /PlayerArtworkPage\(isScrollable: true\)[\s\S]*LyricPreviewView/);
  assert.match(portraitLayout, /else \{[\s\S]*PlayerArtworkPage\(\)[\s\S]*LyricPreviewView/);
  assert.ok(portraitLayout.indexOf('PlayerProgressView()') > portraitLayout.indexOf('ScrollView(showsIndicators: false)'));
  assert.match(playerStore, /artworkAspectRatio: CGFloat = 1/);
  assert.match(playerStore, /displayAspectRatio\(for image: UIImage\)/);
});

test('the player has a dedicated landscape layout with safe bottom controls', () => {
  assert.match(player, /let isLandscape = proxy\.size\.width > proxy\.size\.height/);
  assert.match(player, /LandscapePlayerLayout/);
  assert.match(source, /private struct LandscapePlayerLayout/);
  assert.match(source, /private struct LandscapeArtworkPanel/);
  assert.match(source, /PlayerHeaderBar\(onClose: onClose, showSongInfo: showSongInfo, showPlaybackSettings: showPlaybackSettings, showVisualSettings: showVisualSettings, compact: true\)/);
  assert.match(source, /LyricPreviewView\(action: showLyrics, isLandscapeStage: true\)/);
  assert.match(source, /private struct LandscapeImmersiveLyricsView/);
  assert.match(player, /showingLandscapeLyrics/);
  assert.match(landscapeLayout, /proxy\.safeAreaInsets\.bottom \+ 8/);
  assert.match(infoPlist, /UISupportedInterfaceOrientations/);
  assert.match(infoPlist, /UIInterfaceOrientationLandscapeLeft/);
  assert.match(infoPlist, /UIInterfaceOrientationLandscapeRight/);
  assert.ok(landscapeLayout.indexOf('PlayerProgressView()') > landscapeLayout.indexOf('HStack(alignment: .center'));
  assert.ok(landscapeLayout.indexOf('PlayerControlsView(showQueue: showQueue)') > landscapeLayout.indexOf('PlayerProgressView()'));
  assert.match(source, /if compact \{/);
  assert.match(source, /Image\(systemName: player\.isFavorite\(player\.current\) \? "heart\.fill" : "heart"\)/);
});

test('the lyric preview opens the appropriate lyric view and highlights the active line', () => {
  assert.match(source, /private struct FullLyricsView/);
  assert.match(source, /private struct LandscapeImmersiveLyricsView/);
  assert.match(lyricPreview, /previewLines/);
  assert.match(source, /isActive \? \(isLandscapeStage \? 30 : 18\) : \(isLandscapeStage \? 19 : 13\)/);
  assert.match(source, /player\.lyricMotionEnabled/);
  assert.match(lyricPreview, /accessibilityLabel\("查看完整歌词"\)/);
});

test('playlist detail uses a compact horizontal cover hero and a unified play action bar', () => {
  assert.match(playlistDetail, /PlaylistHeroHeader\(playlist: playlist\)/);
  assert.match(playlistDetail, /PlaylistActionBar\(/);
  assert.match(source, /private struct PlaylistHeroHeader/);
  assert.match(source, /private struct PlaylistActionBar/);
  assert.match(source, /Text\("歌单 · /);
  assert.match(source, /\.frame\(width: 132, height: 132\)/);
  assert.match(source, /Text\("播放全部"\)/);
  assert.match(source, /Text\("\\\(playlist\.trackCount\) 首"\)/);
});

test('the lyric preview supports plain, nebula, moonsea, and star wars display styles', () => {
  assert.match(models, /enum LyricDisplayStyle/);
  assert.match(models, /case plain = "平铺歌词"/);
  assert.match(models, /case nebula = "星云诗幕"/);
  assert.match(models, /case moonsea = "月海回声"/);
  assert.match(models, /case starWars = "星际大战"/);
  assert.match(models, /if rawValue == "3D 星空字幕" \{ return \.nebula \}/);
  assert.match(playerStore, /lyricDisplayStyle = LyricDisplayStyle\.stored\(UserDefaults\.standard\.string\(forKey: "selfradio\.lyrics\.displayStyle"\) \?\? ""\)/);
  assert.match(lyricPreview, /switch player\.lyricDisplayStyle/);
  assert.match(source, /private struct ImmersiveLyricPreviewLine/);
  assert.match(source, /case \.nebula, \.moonsea, \.starWars/);
  assert.match(source, /rotation3DEffect\(\.degrees\(style == \.nebula/);
  assert.match(visualSettings, /Picker\("歌词样式", selection: \$player\.lyricDisplayStyle\)/);
  assert.match(songInfo, /Picker\("歌词样式", selection: \$player\.lyricDisplayStyle\)/);
});

test('the full lyrics sheet provides native and embedded immersive lyric stages', () => {
  assert.match(fullLyrics, /case \.nebula, \.moonsea, \.starWars/);
  assert.match(fullLyrics, /ImmersiveLyricsPage\(style: player\.lyricDisplayStyle\)/);
  assert.match(fullLyrics, /Picker\("歌词样式", selection: \$player\.lyricDisplayStyle\)/);
  assert.match(fullLyrics, /private struct ImmersiveLyricsPage/);
  assert.match(fullLyrics, /private struct ImmersiveLyricsBackdrop/);
  assert.match(fullLyrics, /private struct NebulaBackdropCanvas/);
  assert.match(fullLyrics, /private struct MoonSeaBackdropCanvas/);
  assert.match(fullLyrics, /TimelineView\(\.animation\(minimumInterval: 1 \/ 20\)\)/);
  assert.match(fullLyrics, /player\.particleVisualEnabled/);
  assert.match(fullLyrics, /accessibilityReduceMotion/);
  assert.match(fullLyrics, /private struct NebulaLyricStage/);
  assert.match(fullLyrics, /private struct MoonSeaLyricStage/);
  assert.match(fullLyrics, /private struct NebulaLyricLine/);
  assert.match(fullLyrics, /private struct MoonSeaLyricLine/);
  assert.match(fullLyrics, /private struct StarWarsLyricsWebView: UIViewRepresentable/);
  assert.match(fullLyrics, /StarWarsLyricsWebView\(\)\s*\.frame\(maxWidth: \.infinity, maxHeight: \.infinity\)/);
  assert.match(fullLyrics, /WKWebViewConfiguration\(\)/);
  assert.match(fullLyrics, /window\.selfRadioConfigure/);
  assert.match(fullLyrics, /window\.selfRadioTick/);
  assert.match(fullLyrics, /deliveredLyrics/);
  assert.match(fullLyrics, /performance\.now\(\)/);
  assert.match(fullLyrics, /rotateX\(62deg\)/);
  assert.match(fullLyrics, /WKScriptMessageHandler/);
  assert.match(fullLyrics, /private struct ImmersiveLyricsSheetBackground/);
  assert.match(fullLyrics, /toolbarBackground\(\.hidden, for: \.navigationBar\)/);
  assert.match(fullLyrics, /StarWarsSheetBackdrop/);
  assert.match(fullLyrics, /Image\("StarWarsGalaxyBackground"\)/);
  assert.match(fullLyrics, /function drawMeteor/);
  assert.match(fullLyrics, /now%18000/);
  assert.doesNotMatch(fullLyrics, /StarWarsLyricStage|StarWarsLyricLine/);
  assert.match(fullLyrics, /overflow-wrap:anywhere/);
  assert.match(fullLyrics, /top:42%/);
  assert.match(fullLyrics, /Array\.from\(line\.text\|\|''\)\.length>18/);
  assert.match(fullLyrics, /crawlPosition/);
  assert.match(fullLyrics, /NebulaPlanet/);
  assert.match(fullLyrics, /Image\("MoonSeaLyricBackground"\)/);
  assert.match(fullLyrics, /for layer in -5\.\.\.5/);
  assert.match(fullLyrics, /canvasSize\.height \* 0\.55 - depth \* 102/);
  assert.match(fullLyrics, /canvasSize\.height \* 0\.49 \+ depth \* 104/);
  assert.match(fullLyrics, /rotation3DEffect\(\.degrees\(depth \* 7\)/);
  assert.match(fullLyrics, /isCurrentLine/);
  assert.match(fullLyrics, /abs\(depth\) < 0\.52/);
  assert.match(fullLyrics, /scaleEffect\(x: 1\.02, y: -0\.54/);
  assert.match(fullLyrics, /Color\(uiColor: player\.artworkAccentColor\)/);
  assert.match(fullLyrics, /player\.seek\(to:/);
});

test('the control row order is playback mode previous play next queue', () => {
  assert.match(
    controls,
    /PlaybackModeButton\(\)[\s\S]*PlayerIconButton\(icon: "backward\.fill"[\s\S]*player\.isPlaying \? "pause\.fill" : "play\.fill"[\s\S]*PlayerIconButton\(icon: "forward\.fill"[\s\S]*PlayerIconButton\(icon: "music\.note\.list"/
  );
  assert.match(playbackModeButton, /player\.cyclePlaybackMode\(\)/);
  assert.match(playbackModeButton, /player\.playbackMode\.symbol/);
  assert.match(playbackModeButton, /player\.playbackMode\.shortTitle/);
  assert.match(models, /var shortTitle: String/);
  assert.match(playerStore, /func toggleShuffle\(\)/);
  assert.match(controls, /playPulse/);
  assert.match(controls, /player\.playbackMotionEnabled/);
});

test('queue sheet uses redesigned playable rows and shuffle state', () => {
  assert.match(queue, /QueueSummaryPill/);
  assert.match(queue, /QueueSongRow/);
  assert.match(queue, /QueuePresentation/);
  assert.match(queue, /QueueNebulaBrowser/);
  assert.match(queue, /拖动星云浏览队列/);
  assert.match(queue, /DragGesture\(minimumDistance: 8\)/);
  assert.match(queue, /NebulaCurrentPlanet/);
  assert.match(queue, /NebulaSongPlanet/);
  assert.match(queue, /播放中/);
  assert.match(queue, /player\.toggleShuffle\(\)/);
  assert.doesNotMatch(queue, /List\s*\{/);
});

test('playback motion is configurable from visual settings and defaults on', () => {
  assert.match(playerStore, /playbackMotionEnabled = UserDefaults\.standard\.object\(forKey: "selfradio\.motion\.playback"\) as\? Bool \?\? true/);
  assert.match(playerStore, /lyricMotionEnabled = UserDefaults\.standard\.object\(forKey: "selfradio\.motion\.lyrics"\) as\? Bool \?\? true/);
  assert.match(visualSettings, /Toggle\("播放页动效", isOn: \$player\.playbackMotionEnabled\)/);
  assert.match(playerStore, /coverGlowEnabled = UserDefaults\.standard\.object\(forKey: "selfradio\.motion\.coverGlow"\) as\? Bool \?\? true/);
  assert.match(visualSettings, /Toggle\("封面主色流光", isOn: \$player\.coverGlowEnabled\)/);
  assert.match(playerStore, /artworkPresentation = PlayerArtworkPresentation\(rawValue: UserDefaults\.standard\.string\(forKey: "selfradio\.player\.artworkPresentation"\) \?\? ""\) \?\? \.cover/);
  assert.match(playerStore, /UserDefaults\.standard\.set\(artworkPresentation\.rawValue, forKey: "selfradio\.player\.artworkPresentation"\)/);
  assert.match(visualSettings, /NavigationLink\(destination: ArtworkStyleGalleryView\(\)\)/);
  assert.match(source, /private struct ArtworkStyleGalleryView/);
  assert.match(source, /ArtworkStylePreview/);
  assert.match(source, /ForEach\(PlayerArtworkPresentation\.allCases\)/);
  assert.doesNotMatch(visualSettings, /黑胶旋转/);
  assert.match(visualSettings, /Toggle\("歌词动效", isOn: \$player\.lyricMotionEnabled\)/);
  assert.match(source, /private struct PlayerMotionBackground/);
});

test('the player offers a focused gallery with poster and classic vinyl presentations', () => {
  assert.match(models, /enum PlayerArtworkPresentation: String, CaseIterable, Identifiable/);
  assert.match(models, /case cover = "封面模式"/);
  assert.match(models, /case vinyl = "黑胶模式"/);
  assert.doesNotMatch(models, /太阳唱片|夕阳余晖|琉璃星球/);
  assert.match(models, /var title: String/);
  assert.match(models, /var subtitle: String/);
  assert.match(source, /private struct VinylArtwork/);
  assert.match(source, /private struct VinylDisc/);
  assert.doesNotMatch(source, /SolarRecord|SunsetOrb|GlassOrb/);
  assert.match(source, /player\.artworkPresentation != \.cover/);
  assert.match(source, /VinylDisc\(\)/);
  assert.match(source, /ArtworkPresentationVisual\(style: player\.artworkPresentation/);
  assert.match(source, /ArtworkView\(url: artworkURL, symbol: "music\.note"\)/);
  assert.match(source, /private var displayAspectRatio: CGFloat/);
  assert.match(source, /TimelineView\(\.animation\(minimumInterval: 1 \/ 20, paused: !shouldSpin\)\)/);
  assert.match(source, /insertion: \.opacity\.combined\(with: \.scale\(scale: 1\.035\)\)/);
  assert.match(source, /removal: \.opacity\.combined\(with: \.scale\(scale: 0\.94\)\)/);
});

test('the player exposes playback motion settings from its upper-right menu', () => {
  assert.match(player, /@State private var showingVisualSettings = false/);
  assert.match(player, /\.sheet\(isPresented: \$showingVisualSettings\) \{[\s\S]{0,100}VisualSettingsView\(\)/);
  assert.match(source, /Label\("播放动效", systemImage: "sparkles"\)/);
  assert.match(source, /navigationTitle\("播放动效"\)/);
  assert.doesNotMatch(source, /title: "柔光动效"/);
});

test('lightweight particles pause in low power, reduced motion and background states', () => {
  assert.match(playerStore, /particleVisualEnabled = UserDefaults\.standard\.object\(forKey: "selfradio\.motion\.particles"\) as\? Bool \?\? true/);
  assert.match(visualSettings, /Toggle\("律动粒子", isOn: \$player\.particleVisualEnabled\)/);
  assert.match(source, /private struct PlayerParticleStage/);
  assert.match(player, /PlayerParticleStage\(\)/);
  assert.match(source, /ProcessInfo\.processInfo\.isLowPowerModeEnabled/);
  assert.match(source, /scenePhase == \.active/);
  assert.match(source, /accessibilityReduceMotion/);
  assert.match(source, /minimumInterval: 1 \/ 20/);
});

test('queue accessibility labels avoid nested string interpolation syntax', () => {
  assert.doesNotMatch(source, /accessibilityLabel\("\\\(isNext \? "/);
  assert.match(source, /accessibilityLabel\(\(isNext \? "下一张，" : ""\) \+ album\.name/);
  assert.match(source, /accessibilityLabel\(\(isNext \? "下一首，" : ""\) \+ song\.title/);
});
