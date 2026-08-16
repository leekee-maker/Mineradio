'use strict';

const assert = require('assert');
const fs = require('fs');
const path = require('path');

const platform = fs.readFileSync(
  path.join(__dirname, '..', 'ios', 'SelfRadioIOS', 'SelfRadioIOS', 'PlatformService.swift'),
  'utf8',
);
const login = fs.readFileSync(
  path.join(__dirname, '..', 'ios', 'SelfRadioIOS', 'SelfRadioIOS', 'QQLoginView.swift'),
  'utf8',
);

assert.match(platform, /private func proxiedPlaybackURL\(_ raw: String, provider: MusicProvider\) throws -> URL\?/);
assert.match(platform, /guard provider == \.qishui else \{ return nil \}/);
assert.match(platform, /baseURL\.appending\(path: "api\/audio"\)/);
assert.match(platform, /\.init\(name: "url", value: raw\)/);
assert.match(platform, /let playbackURL = try proxiedPlaybackURL\(raw, provider: song\.provider\) \?\? directURL/);
assert.match(platform, /let webSession = root\?\["webSession"\] as\? Bool \?\? root\?\["cookieReady"\] as\? Bool \?\? false/);
assert.match(platform, /已连接 · 仅推荐\/匹配/);
assert.match(login, /请使用另一台设备的抖音 App 扫码确认/);
assert.match(login, /二维码已保存，请在另一台设备或抖音扫码页从相册识别/);

console.log('[OK] iOS Qishui uses backend audio proxy and explicit low-frequency login guidance.');
