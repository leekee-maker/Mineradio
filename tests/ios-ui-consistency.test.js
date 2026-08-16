'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const source = fs.readFileSync(path.resolve(__dirname, '..', 'ios/SelfRadioIOS/SelfRadioIOS/RootView.swift'), 'utf8');

function section(start, end) {
  return source.slice(source.indexOf(start), source.indexOf(end));
}

test('iOS pages share the profile page typography and spacing tokens', () => {
  assert.match(source, /private enum AppMetrics/);
  assert.match(source, /static let pageSpacing: CGFloat = 26/);
  assert.match(source, /static let groupRadius: CGFloat = 16/);
  assert.match(source, /static let rowHeight: CGFloat = 56/);
  assert.match(source, /private enum AppFont/);
  assert.match(source, /static let pageTitle = Font\.system\(size: 17, weight: \.semibold\)/);
  assert.match(source, /static let rowTitle = Font\.system\(size: 15, weight: \.medium\)/);
});

test('non-player pages avoid oversized page typography', () => {
  const nonPlayer = section('private struct HomeView', 'private struct PlayerView');
  assert.doesNotMatch(nonPlayer, /\.font\(\.system\(size: 36/);
  assert.doesNotMatch(nonPlayer, /\.font\(\.title2/);
  assert.doesNotMatch(nonPlayer, /\.font\(\.title3/);
});

test('shared rows use the same compact row dimensions as profile rows', () => {
  const rows = section('private struct PlaylistRow', 'private struct ArtworkView');
  assert.match(rows, /frame\(minHeight: AppMetrics\.rowHeight\)/);
  assert.match(rows, /RoundedRectangle\(cornerRadius: AppMetrics\.groupRadius\)/);
  assert.match(rows, /Text\(playlist\.name\)\.font\(AppFont\.rowTitle\)/);
  assert.match(rows, /Text\(song\.title\)\.font\(AppFont\.rowTitle\)/);
});
