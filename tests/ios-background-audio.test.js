'use strict';

const assert = require('assert');
const path = require('path');
const { spawnSync } = require('child_process');

const appPath = process.env.SELFRADIO_IOS_APP || '/private/tmp/SelfRadioDerived/Build/Products/Debug-iphoneos/SelfRadioIOS.app';
const plistPath = path.join(appPath, 'Info.plist');
const result = spawnSync('plutil', ['-extract', 'UIBackgroundModes', 'json', '-o', '-', plistPath], { encoding: 'utf8' });

assert.strictEqual(result.status, 0, 'built iOS app must declare UIBackgroundModes');
const modes = JSON.parse(result.stdout || '[]');
assert(Array.isArray(modes) && modes.includes('audio'), 'built iOS app must keep audio playback active in background');

console.log('iOS background audio capability test passed');
