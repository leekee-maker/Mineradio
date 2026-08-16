'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const rootView = fs.readFileSync(
  path.resolve(__dirname, '..', 'ios', 'SelfRadioIOS', 'SelfRadioIOS', 'RootView.swift'),
  'utf8',
);
const platformService = fs.readFileSync(
  path.resolve(__dirname, '..', 'ios', 'SelfRadioIOS', 'SelfRadioIOS', 'PlatformService.swift'),
  'utf8',
);
const models = fs.readFileSync(
  path.resolve(__dirname, '..', 'ios', 'SelfRadioIOS', 'SelfRadioIOS', 'Models.swift'),
  'utf8',
);
const server = fs.readFileSync(path.resolve(__dirname, '..', 'server.js'), 'utf8');

function section(start, end) {
  return rootView.slice(rootView.indexOf(start), rootView.indexOf(end));
}

test('home begins with search and removes the oversized greeting header', () => {
  const home = section('private struct HomeView', 'private struct SectionHeader');
  assert.match(home, /HomeSearchEntry\(/);
  assert.doesNotMatch(home, /Text\("SelfRadio"\)|\bgreeting\b|今天想听点什么/);
});

test('search screen exposes compact suggestions, platform filters and multi-list hot searches', () => {
  const search = section('private struct SearchView', 'private struct FlowSuggestions');
  assert.match(search, /搜索历史/);
  assert.match(search, /搜索发现/);
  assert.match(search, /MusicProvider\.allCases/);
  assert.match(search, /热搜榜/);
  assert.match(search, /SearchShortcutGrid/);
  assert.match(search, /SearchSuggestionStrip/);
  assert.match(search, /showDeferredContent/);
  assert.match(search, /LazyVStack\(alignment: \.leading, spacing: 16\)/);
  assert.match(search, /HotSearchPanel/);
  assert.match(search, /SearchHotList/);
  assert.match(search, /newSongs/);
  assert.match(search, /sleepSongs/);
  assert.match(search, /prefix\(8\)/);
  assert.match(rootView, /case newSongs = "新歌"/);
  assert.match(rootView, /case sleep = "助眠"/);
  assert.match(rootView, /ForEach\(SearchHotList\.allCases\)/);
  assert.doesNotMatch(search, /ScrollView\(\.horizontal[\s\S]{0,240}HotSearch/);
  assert.doesNotMatch(search, /\.task\s*\{[\s\S]{0,160}searchFocused\s*=\s*true/);
  assert.match(rootView, /if\s+!hidesBottomNavigation\s*\{\s*BottomNavigation/);
});

test('iOS normalizes insecure artwork URLs before AsyncImage loads them', () => {
  assert.match(platformService, /replacingOccurrences\(of:\s*"http:\/\/",\s*with:\s*"https:\/\/"/);
});

test('search can open a reusable artist music universe', () => {
  assert.match(server, /\/api\/artist\/universe/);
  assert.match(platformService, /func artistUniverse\(for name: String/);
  assert.match(models, /struct MusicArtistUniverse/);
  assert.match(rootView, /ArtistUniverseView\(artistName: universeArtistName\)/);
  assert.match(rootView, /struct NebulaUniverseView/);
  assert.match(rootView, /DragGesture\(minimumDistance: 8\)/);
  assert.match(rootView, /Picker\("宇宙查看方式"/);
});

test('artist universe loads album summaries first and fetches songs on demand', () => {
  assert.match(server, /handleNeteaseArtistUniverse\(id, limit, includeSongs\)/);
  assert.match(server, /url\.searchParams\.get\('details'\) !== '0'/);
  assert.match(platformService, /api\/artist\/universe/);
  assert.match(platformService, /details.*value: "0"/);
  assert.match(platformService, /func albumSongs\(for albumID:/);
  assert.match(rootView, /MagnificationGesture\(\)/);
  assert.match(rootView, /可双指缩放/);
});
