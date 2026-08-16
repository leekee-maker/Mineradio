'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const source = fs.readFileSync(path.resolve(__dirname, '..', 'ios/SelfRadioIOS/SelfRadioIOS/RootView.swift'), 'utf8');
const splash = source.slice(source.indexOf('private struct LaunchSplashView'), source.indexOf('private struct SoftGlowBackground'));

test('iOS app shows a lightweight launch splash then fades into home', () => {
  assert.match(source, /@State private var showingLaunchSplash = true/);
  assert.match(source, /if showingLaunchSplash\s*\{\s*LaunchSplashView\(\)/);
  assert.match(source, /return reduceMotion \? 650_000_000 : 2_050_000_000/);
  assert.match(source, /Task\.sleep\(nanoseconds: launchSplashHoldDuration\)/);
  assert.match(source, /withAnimation\(\.easeOut\(duration: reduceMotion \? 0\.15 : 0\.35\)\)/);
});

test('launch splash uses dynamic 2.5D artwork and respects reduced motion', () => {
  assert.match(splash, /Image\("LaunchSplashFusionDynamic"\)/);
  assert.match(splash, /\.scaledToFill\(\)/);
  assert.match(splash, /\.rotation3DEffect\(/);
  assert.match(splash, /centerPulsed/);
  assert.match(splash, /LaunchSpectrumPulse\(animates: !reduceMotion\)/);
  assert.match(splash, /interpolatingSpring\(stiffness: 210, damping: 8\)\.repeatForever\(autoreverses: true\)/);
  assert.match(splash, /LaunchLoadingRing\(animates: !reduceMotion\)/);
  assert.match(splash, /repeatForever\(autoreverses: false\)/);
  assert.match(splash, /rotation = 360/);
  assert.match(splash, /accessibilityLabel\("随心听，你的私人音乐现场"\)/);
  assert.match(splash, /accessibilityReduceMotion/);
  assert.doesNotMatch(splash, /正在|加载|连接|ProgressView/);
});
