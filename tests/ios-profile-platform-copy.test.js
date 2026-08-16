'use strict';

const assert = require('assert');
const fs = require('fs');
const path = require('path');

const source = fs.readFileSync(
  path.join(__dirname, '..', 'ios', 'SelfRadioIOS', 'SelfRadioIOS', 'RootView.swift'),
  'utf8',
);

const profile = source.slice(
  source.indexOf('private struct ProfileView'),
  source.indexOf('private struct ProfileQuickAccess'),
);
const platform = source.slice(
  source.indexOf('private struct PlatformAccountsView'),
  source.indexOf('private struct PlaybackSettingsView'),
);

assert.doesNotMatch(profile, /NavigationLink\(destination: PlatformAccountsView\(\)\)\s*\{\s*PlatformConnectionSummary/);
assert.doesNotMatch(profile, /网易云[\s\S]{0,80}QQ音乐[\s\S]{0,80}汽水/);
assert.doesNotMatch(profile, /ProfileQuickAccess\([^\n]*title: "收藏歌单"/);
assert.match(profile, /HStack\(spacing: 12\)[\s\S]*title: "我的喜欢"[\s\S]*title: "最近播放"/);
assert.match(profile, /favoritePlaylists\.prefix\(5\)/);
assert.match(source, /Text\(playlist\.name\)[\s\S]{0,160}\.lineLimit\(1\)[\s\S]{0,80}\.truncationMode\(\.tail\)/);
assert.match(source, /Text\("我的收藏"\)/);
assert.doesNotMatch(source, /Mineradio 收藏/);
assert.match(platform, /连接后可同步收藏、歌单和播放内容。/);
assert.doesNotMatch(platform, /播放凭证|服务端|音源/);
assert.match(platform, /已连接 · 可播放/);
assert.match(platform, /Button\("退出登录", action: logout\)/);
assert.match(platform, /accounts\.logout\(provider: \.qq\)/);
assert.match(platform, /accounts\.logout\(provider: \.netease\)/);
assert.match(platform, /accounts\.logout\(provider: \.qishui\)/);

console.log('[OK] profile removes duplicate platform summary and platform copy avoids technical wording.');
