'use strict';

const assert = require('assert');
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const source = fs.readFileSync(path.join(__dirname, '..', 'server.js'), 'utf8');
const start = source.indexOf('function actualAudioQuality(');
const end = source.indexOf('\nfunction qualityCandidatesFrom(', start);
assert(start >= 0 && end > start, 'actualAudioQuality must remain testable');
const actualAudioQuality = vm.runInNewContext('(' + source.slice(start, end).trim() + ')');

assert.deepStrictEqual(
  JSON.parse(JSON.stringify(actualAudioQuality({ magic: 'mp3-id3' }, 320000, 'hires'))),
  { level: 'exhigh', label: '320K', codec: 'mp3' },
  'a Hi-Res request returning MP3 must be reported as actual 320K MP3'
);
assert.deepStrictEqual(
  JSON.parse(JSON.stringify(actualAudioQuality({ magic: 'flac' }, 1411000, 'lossless'))),
  { level: 'lossless', label: '无损', codec: 'flac' },
  'verified FLAC may be reported as lossless'
);
assert.deepStrictEqual(
  JSON.parse(JSON.stringify(actualAudioQuality({ magic: 'mpeg-frame' }, 128000, 'lossless'))),
  { level: 'standard', label: '128K', codec: 'mp3' },
  'a lossless request returning 128K MPEG must be downgraded visibly'
);
assert.deepStrictEqual(
  JSON.parse(JSON.stringify(actualAudioQuality({ magic: 'flac', sampleRate: 44100, bitDepth: 16 }, 947855, 'hires'))),
  { level: 'lossless', label: '无损', codec: 'flac' },
  '16-bit/44.1kHz FLAC must not be marketed as Hi-Res'
);
assert.deepStrictEqual(
  JSON.parse(JSON.stringify(actualAudioQuality({ magic: 'flac', sampleRate: 96000, bitDepth: 24 }, 2300000, 'hires'))),
  { level: 'hires', label: 'Hi-Res', codec: 'flac' },
  'verified 24-bit/96kHz FLAC may be reported as Hi-Res'
);

console.log('audio quality detection tests passed');
