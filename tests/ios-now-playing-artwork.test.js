'use strict';

const assert = require('assert');
const fs = require('fs');
const path = require('path');

const source = fs.readFileSync(
  path.join(__dirname, '..', 'ios', 'SelfRadioIOS', 'SelfRadioIOS', 'PlayerStore.swift'),
  'utf8',
);

assert.match(
  source,
  /MPMediaItemPropertyArtwork/,
  'lock-screen Now Playing metadata must publish the loaded song artwork',
);
assert.match(
  source,
  /song\.artworkURL/,
  'Now Playing artwork must load from the current song artwork URL',
);
assert.match(
  source,
  /guard\s+current\?\.id\s*==\s*songID/,
  'late artwork responses must not replace the cover of a newer song',
);
assert.match(
  source,
  /nonisolated\s+private\s+static\s+func\s+makeNowPlayingArtwork/,
  'MediaPlayer may request artwork off the main actor, so its callback factory must be nonisolated',
);
assert.match(
  source,
  /\{\s*@Sendable\s+_\s+in\s+image\s*\}/,
  'the system artwork request callback must be explicitly Sendable',
);

console.log('iOS Now Playing artwork contract test passed');
