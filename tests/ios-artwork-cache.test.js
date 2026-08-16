'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const source = fs.readFileSync(
  path.resolve(__dirname, '..', 'ios', 'SelfRadioIOS', 'SelfRadioIOS', 'RootView.swift'),
  'utf8',
);

test('artwork view reuses memory and disk images instead of flashing on repeated network loads', () => {
  const start = source.indexOf('private struct ArtworkView');
  const end = source.indexOf('private struct EmptyState');
  const artwork = source.slice(start, end);

  assert.match(source, /actor ArtworkImageCache/);
  assert.match(source, /NSCache<NSURL, UIImage>/);
  assert.match(source, /cachesDirectory/);
  assert.match(source, /inFlight/);
  assert.match(artwork, /ArtworkImageCache\.shared\.image/);
  assert.doesNotMatch(artwork, /AsyncImage/);
});

test('artwork cache downsamples remote covers and keeps nebula rendering bounded', () => {
  assert.match(source, /import ImageIO/);
  assert.match(source, /CGImageSourceCreateThumbnailAtIndex/);
  assert.match(source, /maxPixelSize = 320/);
  assert.match(source, /totalCostLimit = 40 \* 1024 \* 1024/);
  assert.match(source, /albums\.prefix\(14\)/);
  assert.match(source, /for index in 0..<96/);
  assert.match(source, /struct NebulaMiniPlayerBadge/);
});
