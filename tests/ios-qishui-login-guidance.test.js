'use strict';

const assert = require('assert');
const fs = require('fs');
const path = require('path');

const source = fs.readFileSync(
  path.join(__dirname, '..', 'ios', 'SelfRadioIOS', 'SelfRadioIOS', 'QQLoginView.swift'),
  'utf8'
);

assert.match(source, /请使用另一台设备的抖音 App 扫码确认/);
assert.match(source, /请在另一台设备或抖音扫码页从相册识别/);
assert.doesNotMatch(source, /请使用汽水音乐 App 扫码/);
assert.doesNotMatch(source, /汽水音乐扫码页从相册识别/);

console.log('[OK] iOS Qishui login names the upstream Douyin scanner correctly.');
