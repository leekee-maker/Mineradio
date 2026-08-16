'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..', 'ios', 'SelfRadioIOS', 'SelfRadioIOS');
const rootView = fs.readFileSync(path.join(root, 'RootView.swift'), 'utf8');
const models = fs.readFileSync(path.join(root, 'Models.swift'), 'utf8');
const playerStore = fs.readFileSync(path.join(root, 'PlayerStore.swift'), 'utf8');
const platformService = fs.readFileSync(path.join(root, 'PlatformService.swift'), 'utf8');

test('home renders cached recommendations first and refreshes them in background', () => {
  assert.match(models, /struct HomeFeed:\s*Codable/);
  assert.match(platformService, /enum HomeFeedCache/);
  assert.match(platformService, /static func load\(\) -> HomeFeed/);
  assert.match(platformService, /static func save\(_ feed: HomeFeed\)/);
  assert.match(rootView, /@State private var feed = HomeFeedCache\.load\(\)/);
  assert.match(rootView, /HomeFeedCache\.save\(freshFeed\)/);
  assert.doesNotMatch(rootView, /正在同步 PC 推荐/);
});

test('bottom navigation is a fixed edge-to-edge dock instead of a floating capsule', () => {
  const start = rootView.indexOf('private struct BottomNavigation');
  const end = rootView.indexOf('private struct HomeView');
  const dock = rootView.slice(start, end);
  assert.match(dock, /background\(\.bar\)/);
  assert.match(dock, /ignoresSafeArea\(edges:\s*\.bottom\)/);
  assert.doesNotMatch(dock, /RoundedRectangle\(cornerRadius:\s*26\)/);
  assert.doesNotMatch(dock, /\.shadow\(/);
});

test('playlist detail exposes simple playlist and per-track actions', () => {
  assert.match(models, /struct MusicPlaylist:[^{]*Codable/);
  assert.match(playerStore, /var favoritePlaylists: \[MusicPlaylist\]/);
  assert.match(playerStore, /func toggleFavoritePlaylist\(/);
  assert.match(playerStore, /func enqueue\(/);
  assert.match(playerStore, /func playNext\(/);
  assert.match(rootView, /Label\("播放全部", systemImage: "play\.fill"\)/);
  assert.match(rootView, /收藏歌单|取消收藏/);
  assert.match(rootView, /下一首播放/);
  assert.match(rootView, /加入播放队列/);
  assert.match(rootView, /我的喜欢/);
});

test('middle dock item is a lightweight searchable music catalog', () => {
  assert.match(rootView, /case home, catalog, profile, player/);
  assert.match(rootView, /static let menuCases: \[AppTab\] = \[\.home, \.catalog, \.profile\]/);
  assert.match(rootView, /case \.catalog: NavigationStack \{ CatalogView/);
  assert.match(rootView, /private struct CatalogView/);
  for (const label of ['分类', '歌手', '专辑', '推荐歌单', '全部歌曲']) {
    assert.match(rootView, new RegExp(label));
  }
  assert.match(rootView, /SearchView\(initialQuery:/);
});

test('bottom dock uses the approved Chinese product labels', () => {
  assert.match(rootView, /case \.home: "首页"/);
  assert.match(rootView, /case \.catalog: "曲库"/);
  assert.match(rootView, /case \.profile: "我的"/);
});

test('mini player shows circular playback progress and a next action', () => {
  const start = rootView.indexOf('private struct MiniPlayerView');
  const end = rootView.indexOf('private struct PlayerView');
  const miniPlayer = rootView.slice(start, end);
  assert.match(miniPlayer, /trim\(from: 0, to: max\(0, min\(1, player\.progress\)\)\)/);
  assert.match(miniPlayer, /player\.toggle\(\)/);
  assert.match(miniPlayer, /player\.next\(\)/);
  assert.match(miniPlayer, /accessibilityLabel\("下一首"\)/);
});

test('mini player can collapse into a draggable right-edge playback bubble', () => {
  const start = rootView.indexOf('private struct FloatingMiniPlayerBubble');
  const end = rootView.indexOf('private struct PlayerView');
  const bubble = rootView.slice(start, end);
  assert.match(rootView, /@AppStorage\("selfradio\.miniPlayer\.collapsed"\)/);
  assert.match(rootView, /player\.current != nil && !miniPlayerCollapsed/);
  assert.match(rootView, /FloatingMiniPlayerBubble\(/);
  assert.match(rootView, /accessibilityLabel\("收起为悬浮球"\)/);
  assert.match(bubble, /DragGesture\(minimumDistance: 3\)/);
  assert.match(bubble, /position\(x: proxy\.size\.width - 42/);
  assert.match(bubble, /storedYFraction = Double\(finalY \/ proxy\.size\.height\)/);
  assert.match(bubble, /accessibilityLabel\("展开迷你播放器"\)/);
  assert.match(bubble, /player\.toggle\(\)/);
  assert.match(bubble, /artworkIsRotating/);
  assert.match(bubble, /\.linear\(duration: 8\)\.repeatForever/);
  assert.doesNotMatch(bubble, /offset\(x: -3, y: 3\)/);
});

test('home playlist cards reserve two title lines for equal heights', () => {
  const start = rootView.indexOf('private struct HomeView');
  const end = rootView.indexOf('private struct SectionHeader');
  const homeView = rootView.slice(start, end);
  assert.match(homeView, /Text\(playlist\.name\)[\s\S]*?lineLimit\(2, reservesSpace: true\)/);
});

test('home feed defensively deduplicates playlists across cached and fresh sections', () => {
  assert.match(platformService, /private func deduplicatedHomeSections\(_ sections: \[HomeSection\]\)/);
  assert.match(platformService, /feed\.sections = deduplicatedHomeSections\(feed\.sections\)/);
  assert.match(platformService, /sections = deduplicatedHomeSections\(sections\)/);
});

test('profile is content-first with quick access, recent listening and playlists', () => {
  const start = rootView.indexOf('private struct ProfileView');
  const end = rootView.indexOf('private struct ProfileQuickAccess');
  const profile = rootView.slice(start, end);
  assert.match(profile, /Text\("我的"\)/);
  assert.match(profile, /ProfileQuickAccess/);
  assert.match(profile, /Text\("最近常听"\)/);
  assert.match(profile, /player\.recentSongs\.prefix\(3\)/);
  assert.match(profile, /Text\("我的歌单"\)/);
  assert.match(profile, /player\.favoritePlaylists\.prefix\(2\)/);
  assert.doesNotMatch(profile, /NavigationLink\(destination: PlatformAccountsView\(\)\)\s*\{\s*PlatformConnectionSummary/);
});
