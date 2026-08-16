function isFreeCameraControlCode(code) {
  return /^(KeyW|KeyA|KeyS|KeyD|KeyQ|KeyE|Space|ShiftLeft|ShiftRight|ControlLeft|ControlRight)$/.test(code);
}
function consumeFreeCameraKeyEvent(e, isDown) {
  if (isTypingTarget(e.target)) return false;
  if (isDown && e.code === 'KeyR') {
    e.preventDefault();
    e.stopImmediatePropagation();
    if (e.repeat) return true;
    toggleFreeCamera();
    return true;
  }
  if (!freeCamera || !freeCamera.active) return false;
  if (isDown && e.code === 'KeyK') {
    e.preventDefault();
    e.stopImmediatePropagation();
    resetFreeCameraToDefault();
    return true;
  }
  if (!isFreeCameraControlCode(e.code)) return false;
  e.preventDefault();
  e.stopImmediatePropagation();
  freeCamera.keys = freeCamera.keys || {};
  freeCamera.keys[e.code] = !!isDown;
  markRenderInteraction('free-camera-key', 900);
  return true;
}
function isPlaybackSpaceKey(e) {
  return !!(
    e &&
    e.code === 'Space' &&
    !e.ctrlKey &&
    !e.altKey &&
    !e.shiftKey &&
    !e.metaKey &&
    !(freeCamera && freeCamera.active) &&
    !isTypingTarget(e.target)
  );
}
function handleShelfArrowNavigation(e) {
  if (!e || (e.code !== 'ArrowUp' && e.code !== 'ArrowDown')) return false;
  if (e.ctrlKey || e.altKey || e.shiftKey || e.metaKey || isTypingTarget(e.target)) return false;
  if (!shelfManager || !shelfManager.getMode || shelfManager.getMode() === 'off') return false;
  var forward = e.code === 'ArrowDown';
  var contentOpen = shelfManager.hasOpenContent && shelfManager.hasOpenContent();
  if (contentOpen) {
    var cl = shelfManager.getContentList && shelfManager.getContentList();
    if (!cl) return false;
    e.preventDefault();
    e.stopImmediatePropagation();
    if (!e.repeat) {
      if (forward) cl.next();
      else cl.prev();
    }
    return true;
  }
  if (!shelfPinnedOpen) return false;
  e.preventDefault();
  e.stopImmediatePropagation();
  if (!e.repeat) {
    if (forward) shelfManager.next();
    else shelfManager.prev();
  }
  return true;
}
function handleShelfEnterAction(e) {
  if (!e || (e.code !== 'Enter' && e.code !== 'NumpadEnter')) return false;
  if (e.ctrlKey || e.altKey || e.shiftKey || e.metaKey || isTypingTarget(e.target)) return false;
  if (!shelfPinnedOpen || !shelfManager || !shelfManager.playPlaylistAt) return false;
  if (shelfManager.hasOpenContent && shelfManager.hasOpenContent()) return false;
  var centerIdx = shelfManager.getCenterIdx();
  var card = shelfManager.getCardAt && shelfManager.getCardAt(centerIdx);
  if (!card || !card.item || card.item.type !== 'playlist') return false;
  e.preventDefault();
  e.stopImmediatePropagation();
  if (!e.repeat) shelfManager.playPlaylistAt(centerIdx);
  return true;
}
document.addEventListener('keydown', function (e) {
  consumeFreeCameraKeyEvent(e, true);
}, true);
document.addEventListener('keyup', function (e) {
  consumeFreeCameraKeyEvent(e, false);
}, true);
document.addEventListener('keydown', function (e) {
  if (isTypingTarget(e.target)) return;
  if (isPlaybackSpaceKey(e)) return;
  markRenderInteraction('keyboard', 700);
  if (e.code === 'KeyK') {
    e.preventDefault();
    if (freeCamera && (freeCamera.active || freeCamera.locked)) resetFreeCameraToDefault();
    else {
      recenterCamera();
      showToast('镜头已回正');
    }
    return;
  }
  if (e.code === 'KeyR') {
    if (e.repeat) return;
    e.preventDefault();
    toggleFreeCamera();
    return;
  }
  if (freeCamera && freeCamera.active) {
    if (/^(KeyW|KeyA|KeyS|KeyD|KeyQ|KeyE|Space|ShiftLeft|ShiftRight|ControlLeft|ControlRight)$/.test(e.code)) {
      e.preventDefault();
      e.stopImmediatePropagation();
      freeCamera.keys[e.code] = true;
      return;
    }
  }
  if (!shelfManager) return;
  if (handleShelfEnterAction(e)) return;
  if (handleShelfArrowNavigation(e)) return;
  if (e.code === 'BracketRight' || e.code === 'PageDown') shelfManager.next();
  else if (e.code === 'BracketLeft' || e.code === 'PageUp') shelfManager.prev();
});
document.addEventListener('keyup', function (e) {
  if (!freeCamera || !freeCamera.keys) return;
  if (/^(KeyW|KeyA|KeyS|KeyD|KeyQ|KeyE|Space|ShiftLeft|ShiftRight|ControlLeft|ControlRight)$/.test(e.code)) {
    freeCamera.keys[e.code] = false;
  }
});
window.addEventListener('blur', function () {
  if (freeCamera && freeCamera.keys) freeCamera.keys = {};
});

// ============================================================
//  API 助手
