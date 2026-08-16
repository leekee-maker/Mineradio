'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const appRoot = path.resolve(__dirname, '..');
const interactions = fs.readFileSync(path.join(appRoot, 'public/js/modules/04-shelf/05-card-interactions.js'), 'utf8');
const keyboard = fs.readFileSync(path.join(appRoot, 'public/js/modules/04-shelf/06-keyboard-camera-events.js'), 'utf8');
const shortcuts = fs.readFileSync(path.join(appRoot, 'public/js/modules/10-shell/01-viewport-resize-shortcuts.js'), 'utf8');

test('shelf wheel navigation is rate limited and remains one item per accepted gesture step', () => {
  assert.match(interactions, /function\s+consumeShelfWheelStep\s*\(/);
  assert.match(interactions, /SHELF_WHEEL_STEP_INTERVAL_MS\s*=\s*(?:1[8-9]\d|2\d\d)/);
  assert.match(interactions, /var\s+wheelStep\s*=\s*consumeShelfWheelStep\(e\)/);
  assert.match(interactions, /scrollBy\(wheelStep\)/);
});

test('arrow keys navigate an active shelf before the global volume shortcuts', () => {
  assert.match(keyboard, /function\s+handleShelfArrowNavigation\s*\(e\)/);
  assert.match(keyboard, /hasOpenContent\(\)[^]*?getContentList\(\)[^]*?\.next\(\)/);
  assert.match(keyboard, /shelfPinnedOpen[^]*?shelfManager\.next\(\)/);
  assert.match(shortcuts, /if\s*\(typeof handleShelfArrowNavigation[^]*?handleShelfArrowNavigation\(e\)\)\s*return;/);
});

test('Enter activates the centered playlist primary play action while the shelf is pinned', () => {
  assert.match(keyboard, /function\s+handleShelfEnterAction\s*\(e\)/);
  assert.match(keyboard, /shelfPinnedOpen[^]*?getCenterIdx\(\)[^]*?playPlaylistAt\(centerIdx\)/);
  assert.match(shortcuts, /if\s*\(typeof handleShelfEnterAction[^]*?handleShelfEnterAction\(e\)\)\s*return;/);
});
