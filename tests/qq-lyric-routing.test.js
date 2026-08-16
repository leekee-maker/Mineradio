'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const source = fs.readFileSync(path.resolve(__dirname, '..', 'server.js'), 'utf8');

test('QQ lyric lookup sends a numeric song ID only when it is actually numeric', () => {
  const start = source.indexOf('function normalizeQQSongId');
  const end = source.indexOf('\nasync function handleQQLyric', start);
  const body = source.slice(start, end);
  assert.match(body, /const raw = String\(id \|\| ''\)\.trim\(\)/);
  assert.match(body, /\/\^\\d\+\$\/\.test\(raw\)/);
  assert.doesNotMatch(body, /replace\(\/\\D\/g/);
});
