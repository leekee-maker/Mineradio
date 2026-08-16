'use strict';

const assert = require('assert');
const fs = require('fs');
const path = require('path');

const source = fs.readFileSync(path.join(__dirname, '..', 'desktop', 'main.js'), 'utf8');
const start = source.indexOf('function setMainWindowFullscreenResizeGuard');
const end = source.indexOf('\nfunction getSenderWindow', start);
const guard = source.slice(start, end);
const toggleStart = source.indexOf('function toggleFullscreen');
const toggleEnd = source.indexOf('\nfunction overlayUrl', toggleStart);
const toggle = source.slice(toggleStart, toggleEnd);

assert(start >= 0 && end > start, 'fullscreen resize guard must exist');
assert(/process\.platform === 'darwin'/.test(guard), 'macOS must have a dedicated fullscreen guard');
assert(/if \(!win\.isResizable\(\)\) win\.setResizable\(true\)/.test(guard), 'macOS window must remain resizable before native fullscreen');
assert(guard.indexOf("process.platform === 'darwin'") < guard.indexOf('const shouldResize = !fullscreen'), 'macOS must return before the Windows resize lock');
assert(toggleStart >= 0 && toggleEnd > toggleStart, 'fullscreen toggle must exist');
assert(/process\.platform === 'darwin'/.test(toggle), 'macOS must have a dedicated fullscreen toggle');
assert(/win\.setSimpleFullScreen\(true\)/.test(toggle), 'transparent frameless macOS windows must use simple fullscreen');

console.log('[OK] macOS transparent window uses simple fullscreen.');
