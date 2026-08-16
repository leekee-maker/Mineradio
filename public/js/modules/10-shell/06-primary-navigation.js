'use strict';

var primaryNavigationHideTimer = null;

function setPrimaryNavigationRevealed(revealed) {
  var navigation = document.getElementById('primary-navigation');
  if (navigation) navigation.classList.toggle('revealed', !!revealed);
}

function updatePrimaryNavigationAutoHide(event) {
  var navigation = document.getElementById('primary-navigation');
  if (!navigation || document.body.classList.contains('splash-active')) return;
  var rect = navigation.getBoundingClientRect();
  var inRevealZone = event.clientY <= 72 && event.clientX <= Math.max(430, rect.right + 12);
  var insideNavigation = event.clientX >= rect.left && event.clientX <= rect.right && event.clientY >= rect.top && event.clientY <= rect.bottom;
  if (inRevealZone || insideNavigation) {
    clearTimeout(primaryNavigationHideTimer);
    primaryNavigationHideTimer = null;
    setPrimaryNavigationRevealed(true);
    return;
  }
  if (!primaryNavigationHideTimer) {
    primaryNavigationHideTimer = setTimeout(function () {
      primaryNavigationHideTimer = null;
      setPrimaryNavigationRevealed(false);
    }, 520);
  }
}

document.addEventListener('pointermove', updatePrimaryNavigationAutoHide, { passive: true });
document.addEventListener('pointerleave', function () { setPrimaryNavigationRevealed(false); }, { passive: true });

function setPrimaryNavigationActive(key) {
  var items = document.querySelectorAll('#primary-navigation [data-nav-key]');
  for (var i = 0; i < items.length; i++) {
    var selected = items[i].getAttribute('data-nav-key') === key;
    items[i].classList.toggle('active', selected);
    items[i].setAttribute('aria-current', selected ? 'page' : 'false');
  }
}

function openPrimaryNavigation(key) {
  document.body.classList.toggle('primary-search-active', key === 'search');
  if (key !== 'library') {
    if (typeof setPlaylistPanelPinned === 'function') setPlaylistPanelPinned(false, true);
    if (typeof togglePlaylistPanel === 'function') togglePlaylistPanel(false);
    if (typeof setPeek === 'function') setPeek(document.getElementById('playlist-panel'), false, 'pl');
    if (typeof setFocusZone === 'function') setFocusZone(null, true);
  }
  if (key !== 'search') {
    var searchInput = document.getElementById('search-input');
    if (searchInput && document.activeElement === searchInput) searchInput.blur();
    if (typeof setPeek === 'function') setPeek(document.getElementById('search-area'), false, 'search');
  }
  setPrimaryNavigationActive(key);
  if (key === 'home') {
    if (typeof toggleFxPanel === 'function') toggleFxPanel(false);
    if (typeof goHome === 'function') goHome();
    return;
  }
  if (key === 'search') {
    if (typeof toggleFxPanel === 'function') toggleFxPanel(false);
    if (typeof goHome === 'function') goHome();
    requestAnimationFrame(function () {
      var input = document.getElementById('search-input');
      if (input) input.focus();
    });
    return;
  }
  if (key === 'library') {
    if (typeof openHomeDashboardLibrary === 'function') openHomeDashboardLibrary();
    return;
  }
  if (key === 'settings') {
    if (typeof applyDiyMode === 'function' && typeof isDiyMode === 'function' && !isDiyMode()) {
      applyDiyMode(true, { animate: false });
    }
    if (typeof toggleFxPanel === 'function') toggleFxPanel(true);
  }
}
