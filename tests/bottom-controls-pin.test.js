'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const read = (file) => fs.readFileSync(path.join(root, file), 'utf8');

test('desktop playback controls expose a persistent one-click pin preference', () => {
  const html = read('public/index.html');
  const css = read('public/css/index.css');
  const runtime = read('public/js/modules/01-scene/04-bottom-controls-cursor.js');

  assert.match(html, /id="controls-hide-btn"[^>]*title="固定播放控制条"[^>]*aria-pressed="true"/);
  assert.match(css, /body\.desktop-shell:not\(\.immersive-mode\)\s+#controls-hide-btn\s*\{[^}]*display:\s*flex\s*!important/);
  assert.match(runtime, /classList\.toggle\('active',\s*!controlsAutoHide\)/);
  assert.match(runtime, /setAttribute\('aria-pressed',\s*String\(!controlsAutoHide\)\)/);
  assert.match(runtime, /saveBooleanPreference\(CONTROLS_AUTO_HIDE_STORE_KEY,\s*controlsAutoHide\)/);
});
