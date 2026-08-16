'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const source = fs.readFileSync(path.resolve(__dirname, '..', 'server.js'), 'utf8');

function namedFunctionSource(text, name) {
  const declaration = new RegExp(`(?:async\\s+)?function\\s+${name}\\s*\\(`).exec(text);
  if (!declaration) return '';
  const bodyStart = text.indexOf('{', declaration.index + declaration[0].length);
  if (bodyStart < 0) return '';
  let depth = 0;
  let quote = '';
  let escaped = false;
  for (let index = bodyStart; index < text.length; index += 1) {
    const character = text[index];
    if (quote) {
      if (escaped) escaped = false;
      else if (character === '\\') escaped = true;
      else if (character === quote) quote = '';
      continue;
    }
    if (character === '"' || character === "'" || character === '`') {
      quote = character;
      continue;
    }
    if (character === '{') depth += 1;
    if (character === '}') {
      depth -= 1;
      if (depth === 0) return text.slice(declaration.index, index + 1);
    }
  }
  return '';
}

test('daily recommendation mapper preserves every valid upstream song in order', () => {
  const mapperSource = namedFunctionSource(source, 'mapDailyRecommendationSongs');
  assert.ok(mapperSource, 'expected mapDailyRecommendationSongs()');
  const mapper = vm.runInNewContext(`(${mapperSource})`, {
    mapSongRecord(song) {
      return song && song.valid === false ? null : {
        id: song && song.id,
        name: song && song.name,
      };
    },
  });
  const upstream = Array.from({ length: 37 }, (_, index) => ({
    id: String(index + 1),
    name: `daily-${index + 1}`,
  }));
  const mapped = mapper(upstream);
  assert.equal(mapped.length, 37);
  assert.deepEqual(
    Array.from(mapped, song => String(song.id)),
    upstream.map(song => song.id),
  );
});

test('discover home returns the complete mapped daily list without a fixed song cap', () => {
  const discoverSource = namedFunctionSource(source, 'handleDiscoverHome');
  assert.ok(discoverSource, 'expected handleDiscoverHome()');
  assert.match(discoverSource, /dailySongs\s*=\s*mapDailyRecommendationSongs\(raw\)/);
  assert.doesNotMatch(discoverSource, /dailySongs[\s\S]{0,300}\.slice\s*\(\s*0\s*,\s*(?:8|12)\s*\)/);
  assert.match(discoverSource, /dailySongs:\s*featuredSongs/);
  assert.match(discoverSource, /dailySongTotal:\s*featuredSongs\.length/);
  assert.match(discoverSource, /dailySongsComplete:\s*true/);
});

test('discover home does not request or return recommended podcasts', () => {
  const discoverSource = namedFunctionSource(source, 'handleDiscoverHome');
  assert.doesNotMatch(discoverSource, /\bdj_hot\s*\(/);
  assert.match(discoverSource, /podcasts:\s*\[\]/);
});

test('discover home aggregates QQ hot playlists and exposes cross-platform trending songs', () => {
  const publicSource = namedFunctionSource(source, 'fetchDiscoverPublicSections');
  const discoverSource = namedFunctionSource(source, 'handleDiscoverHome');
  assert.match(publicSource, /fetchQQHotPlaylists\(/);
  assert.match(publicSource, /qqHotPlaylists/);
  assert.match(discoverSource, /trendingSongs:\s*publicContent\.trendingSongs/);
});

test('discover home removes duplicate playlists across sections', () => {
  const dedupeSource = namedFunctionSource(source, 'deduplicateDiscoverSections');
  const discoverSource = namedFunctionSource(source, 'handleDiscoverHome');
  assert.ok(dedupeSource, 'expected deduplicateDiscoverSections()');
  const dedupe = vm.runInNewContext(`(${dedupeSource})`);
  const sections = dedupe([
    { id: 'for-you', playlists: [{ provider: 'netease', id: '1' }, { provider: 'qq', id: '1' }] },
    { id: 'hot', playlists: [{ provider: 'netease', id: '1' }, { provider: 'qq', id: '2' }] },
  ]);
  assert.deepEqual(Array.from(sections, section => Array.from(section.playlists, item => `${item.provider}:${item.id}`)), [
    ['netease:1', 'qq:1'],
    ['qq:2'],
  ]);
  assert.match(discoverSource, /deduplicateDiscoverSections\(sections\)/);
});

test('discover home keeps a broader chart catalog and returns secure NetEase covers', () => {
  const publicSource = namedFunctionSource(source, 'fetchDiscoverPublicSections');
  const mapperSource = namedFunctionSource(source, 'mapDiscoverPlaylist');
  assert.match(publicSource, /\.slice\(0,\s*12\)/);
  assert.match(publicSource, /charts:\s*charts\.slice\(0,\s*18\)/);

  const mapper = vm.runInNewContext(`(${mapperSource})`, {
    normalizeCoverUrl(value) {
      return String(value || '').replace(/^http:\/\//i, 'https://');
    },
  });
  const playlist = mapper({
    id: 'chart-1',
    name: '网易云热歌榜',
    coverImgUrl: 'http://p1.music.126.net/chart.jpg',
  }, '官方榜单');
  assert.equal(playlist.cover, 'https://p1.music.126.net/chart.jpg');
});

test('QQ charts expose only tracks confirmed playable for the current account', () => {
  const selectorSource = namedFunctionSource(source, 'selectPlayableQQTracks');
  const toplistSource = namedFunctionSource(source, 'handleQQToplistTracks');
  const playlistSource = namedFunctionSource(source, 'handleQQPlaylistTracks');
  assert.ok(selectorSource, 'expected selectPlayableQQTracks()');
  const selector = vm.runInNewContext(`(${selectorSource})`);
  const selected = selector([
    { id: 'playable', name: '可播歌曲' },
    { id: 'blocked', name: '版权受限' },
    { id: 'placeholder', name: '异常加载中' },
  ], new Set(['playable', 'placeholder']));
  assert.deepEqual(Array.from(selected, song => song.id), ['playable']);
  assert.match(toplistSource, /await\s+filterPlayableQQTracks\(tracks\)/);
  assert.match(playlistSource, /await\s+filterPlayableQQTracks\(tracks\)/);
});
