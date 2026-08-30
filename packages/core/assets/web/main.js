// Doorstep Web Client & Smart Platform Detection

var BASE_URL = '/api/localsend/v2';
var i18n = {};
var sessionId = sessionStorage.getItem('sessionId');
var queryParams = location.search.slice(1).split('&');
var queryPin = null;
var currentFiles = {};

// Parse query params
for (var i = 0; i < queryParams.length; i++) {
  var pair = queryParams[i].split('=');
  if (pair[0] === 'pin') {
    queryPin = decodeURIComponent(pair[1]);
    break;
  }
}

document.getElementById('year').innerText = new Date().getFullYear();

function hideSplashScreen() {
  var splash = document.getElementById('splash-screen');
  if (splash) {
    splash.classList.add('fade-out');
    setTimeout(function () {
      splash.style.display = 'none';
    }, 550);
  }
}

function showPinModal(isRetry) {
  var modal = document.getElementById('pin-modal');
  var input = document.getElementById('pin-input');
  if (modal) {
    modal.classList.add('active');
    if (input) {
      input.value = '';
      input.focus();
      if (isRetry) {
        input.style.borderColor = 'var(--danger)';
      }
    }
  }
}

function hidePinModal() {
  var modal = document.getElementById('pin-modal');
  if (modal) {
    modal.classList.remove('active');
  }
}

function handlePinSubmit(e) {
  if (e) e.preventDefault();
  var pin = document.getElementById('pin-input').value.trim();
  if (!pin) return;
  hidePinModal();
  requestWithPin(pin);
}

function requestWithPin(pin) {
  var url = BASE_URL + '/prepare-download?pin=' + encodeURIComponent(pin);
  makeRequest(url, 'POST', function (response) {
    if (response.status === 401) {
      showPinModal(true);
      return;
    }
    if (response.status === 200) {
      handleSuccess(response);
      return;
    }
    showLandingSection();
  });
}

function firstRequestFiles() {
  var initialUrl = BASE_URL + '/prepare-download';

  if (sessionId) {
    initialUrl += '?sessionId=' + encodeURIComponent(sessionId);
    if (queryPin) {
      initialUrl += '&pin=' + encodeURIComponent(queryPin);
    }
  } else if (queryPin) {
    initialUrl += '?pin=' + encodeURIComponent(queryPin);
  }

  makeRequest(initialUrl, 'POST', function (response) {
    hideSplashScreen();

    if (response.status === 401) {
      showPinModal(false);
      return;
    }

    if (response.status === 200) {
      handleSuccess(response);
      return;
    }

    showLandingSection();
  });
}

function showLandingSection() {
  document.getElementById('transfer-section').style.display = 'none';
  document.getElementById('landing-section').style.display = 'block';
  detectAndConfigureUserPlatform();
  hideSplashScreen();
}

function togglePlatformsAccordion() {
  var acc = document.getElementById('platforms-accordion');
  if (acc) {
    acc.classList.toggle('open');
  }
}

// ── Smart Device & Architecture Detection Engine ─────────────────────────────

function detectAndConfigureUserPlatform() {
  var ua = navigator.userAgent || '';
  var platform = navigator.platform || '';
  var isAndroid = /android/i.test(ua);
  var isIOS = /ipad|iphone|ipod/i.test(ua) || (platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  var isMac = /mac/i.test(platform) && !isIOS;
  var isWindows = /win/i.test(platform) || /windows/i.test(ua);
  var isLinux = /linux/i.test(platform) && !isAndroid;

  var detectedOs = 'Unknown';
  var detectedArch = 'Universal';
  var downloadTitle = 'Get Doorstep for Your Device';
  var downloadSub = 'One click — compatible with your device architecture';
  var btnText = 'Download Doorstep';
  var btnArchTag = 'Universal';
  var downloadUrl = 'https://github.com/javex-12/Doorstep/releases/latest';

  // High-Entropy Client Hints if supported (Chrome 90+, Edge, Android WebView)
  if (navigator.userAgentData && navigator.userAgentData.getHighEntropyValues) {
    navigator.userAgentData.getHighEntropyValues(['architecture', 'bitness', 'platform', 'model'])
      .then(function (hints) {
        applyDetectedPlatform(hints.platform || platform, hints.architecture, hints.bitness, isAndroid, isIOS, isMac, isWindows, isLinux, ua);
      })
      .catch(function () {
        applyDetectedPlatform(platform, '', '', isAndroid, isIOS, isMac, isWindows, isLinux, ua);
      });
  } else {
    applyDetectedPlatform(platform, '', '', isAndroid, isIOS, isMac, isWindows, isLinux, ua);
  }
}

function applyDetectedPlatform(platform, archHint, bitness, isAndroid, isIOS, isMac, isWindows, isLinux, ua) {
  var labelElem = document.getElementById('detected-device-label');
  var titleElem = document.getElementById('detected-download-title');
  var subElem = document.getElementById('detected-download-sub');
  var btnTextElem = document.getElementById('primary-btn-text');
  var btnArchElem = document.getElementById('primary-btn-arch');
  var primaryBtn = document.getElementById('primary-download-btn');

  var repoReleases = 'https://github.com/javex-12/Doorstep/releases/latest';

  if (isAndroid) {
    var is64 = (bitness === '64') || /arm64|aarch64|x86_64/i.test(ua);
    var is32 = (bitness === '32') || /armv7|armeabi/i.test(ua);

    labelElem.innerText = 'Detected: Android Phone';
    titleElem.innerText = 'Doorstep for Android';
    // Using Universal APK as safe default so non-technical users NEVER get architecture failure errors
    subElem.innerText = is32 ? 'Detected 32-bit ARM device — Universal APK ensures 100% compatibility.' : 'Direct APK download compatible with all Android devices.';
    btnTextElem.innerText = 'Download Android APK';
    btnArchElem.innerText = is32 ? 'Universal (All Phones)' : (is64 ? 'Universal / ARM64' : 'Universal APK');
    primaryBtn.href = repoReleases;
    return;
  }

  if (isIOS) {
    labelElem.innerText = 'Detected: iPhone / iPad (iOS)';
    titleElem.innerText = 'Doorstep for iOS';
    subElem.innerText = 'Fast and secure local file transfers on your iPhone and iPad.';
    btnTextElem.innerText = 'Get on App Store / IPA';
    btnArchElem.innerText = 'iOS Package';
    primaryBtn.href = repoReleases;
    return;
  }

  if (isWindows) {
    var isArmWindows = /arm/i.test(archHint) || /arm64/i.test(ua);
    labelElem.innerText = 'Detected: Windows PC';
    titleElem.innerText = 'Doorstep for Windows';
    subElem.innerText = isArmWindows ? 'Detected Windows ARM64 (Surface / Snapdragon laptop)' : 'Standard 64-bit Windows PC Installer (.exe)';
    btnTextElem.innerText = 'Download for Windows';
    btnArchElem.innerText = isArmWindows ? 'ARM64 / MSIX' : 'x64 .exe';
    primaryBtn.href = repoReleases;
    return;
  }

  if (isMac) {
    var isAppleSilicon = /arm/i.test(archHint) || (!/intel/i.test(ua) && screen.width > 0);
    labelElem.innerText = 'Detected: macOS';
    titleElem.innerText = 'Doorstep for Mac';
    subElem.innerText = 'Native local transfer app for macOS (Apple Silicon & Intel).';
    btnTextElem.innerText = 'Download macOS .dmg';
    btnArchElem.innerText = 'Universal DMG';
    primaryBtn.href = repoReleases;
    return;
  }

  if (isLinux) {
    labelElem.innerText = 'Detected: Linux';
    titleElem.innerText = 'Doorstep for Linux';
    subElem.innerText = 'Available as AppImage, .deb, and tar.gz for all distributions.';
    btnTextElem.innerText = 'Download for Linux';
    btnArchElem.innerText = 'AppImage / .deb';
    primaryBtn.href = repoReleases;
    return;
  }

  // Fallback
  labelElem.innerText = 'Select Your Platform';
  titleElem.innerText = 'Download Doorstep';
  subElem.innerText = 'Choose your device platform and architecture below';
  btnTextElem.innerText = 'View All Releases';
  btnArchElem.innerText = 'All Devices';
  primaryBtn.href = repoReleases;
}

function handleSuccess(response) {
  try {
    var data = JSON.parse(response.responseText);
    var files = data.files;
    currentFiles = files;
    sessionId = data.sessionId;
    sessionStorage.setItem('sessionId', sessionId);

    var count = getKeys(files).length;
    document.getElementById('status-text').innerText = (i18n.files || 'AVAILABLE FILES') + ' (' + count + ')';
    document.getElementById('hero-desc').innerText = 'The sender is ready. Click any file below to download directly over your local network.';
    document.getElementById('transfer-section').style.display = 'block';
    document.getElementById('landing-section').style.display = 'none';

    handleFilesDisplay(files, sessionId);
    hideSplashScreen();
  } catch (err) {
    showLandingSection();
  }
}

function getFileIconSvg(fileName) {
  var ext = (fileName.split('.').pop() || '').toLowerCase();
  if (['png', 'jpg', 'jpeg', 'gif', 'svg', 'webp', 'bmp'].indexOf(ext) !== -1) {
    return '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="3" width="18" height="18" rx="2"/><circle cx="8.5" cy="8.5" r="1.5"/><path d="M21 15l-5-5L5 21"/></svg>';
  }
  if (['mp4', 'mkv', 'webm', 'mov', 'avi'].indexOf(ext) !== -1) {
    return '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polygon points="23 7 16 12 23 17 23 7"/><rect x="1" y="5" width="15" height="14" rx="2" ry="2"/></svg>';
  }
  if (['mp3', 'wav', 'ogg', 'flac', 'm4a', 'aac'].indexOf(ext) !== -1) {
    return '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M9 18V5l12-2v13"/><circle cx="6" cy="18" r="3"/><circle cx="18" cy="16" r="3"/></svg>';
  }
  if (['zip', 'tar', 'gz', '7z', 'rar'].indexOf(ext) !== -1) {
    return '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="21 8 21 21 3 21 3 8"/><rect x="1" y="3" width="22" height="5"/><line x1="10" y1="12" x2="14" y2="12"/></svg>';
  }
  if (['pdf', 'doc', 'docx', 'txt', 'md', 'epub'].indexOf(ext) !== -1) {
    return '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/></svg>';
  }
  return '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M13 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V9z"/><polyline points="13 2 13 9 20 9"/></svg>';
}

function handleFilesDisplay(files, sessionId) {
  var html = '';
  var fileKeys = getKeys(files);

  for (var i = 0; i < fileKeys.length; i++) {
    var key = fileKeys[i];
    var file = files[key];
    var ext = (file.fileName.split('.').pop() || 'FILE').toUpperCase();
    var downloadUrl = BASE_URL + '/download?sessionId=' + encodeURIComponent(sessionId) + '&fileId=' + encodeURIComponent(key);

    html += '<a class="file-card" href="' + downloadUrl + '" download="' + escapeHtml(file.fileName) + '">' +
        '<div class="file-icon-box">' + getFileIconSvg(file.fileName) + '</div>' +
        '<div class="file-info">' +
            '<div class="file-name" title="' + escapeHtml(file.fileName) + '">' + escapeHtml(file.fileName) + '</div>' +
            '<div class="file-meta">' +
                '<span class="file-ext-badge">' + escapeHtml(ext) + '</span>' +
                '<span>' + formatBytes(file.size) + '</span>' +
            '</div>' +
        '</div>' +
        '<div class="download-action-icon" title="Download">' +
            '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">' +
                '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path>' +
                '<polyline points="7 10 12 15 17 10"></polyline>' +
                '<line x1="12" y1="15" x2="12" y2="3"></line>' +
            '</svg>' +
        '</div>' +
    '</a>';
  }

  if (fileKeys.length === 1) {
    document.getElementById('single-file').innerHTML = html;
    document.getElementById('file-list').innerHTML = '';
  } else {
    document.getElementById('file-list').innerHTML = html;
    document.getElementById('single-file').innerHTML = '';
  }
}

function escapeHtml(text) {
  if (text === null || text === undefined) return '';
  var map = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#039;' };
  return String(text).replace(/[&<>"']/g, function (m) { return map[m]; });
}

function formatBytes(bytes) {
  if (!bytes || bytes === 0) return '0 B';
  if (bytes < 1024) return bytes + ' B';
  if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
  if (bytes < 1024 * 1024 * 1024) return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
  return (bytes / (1024 * 1024 * 1024)).toFixed(2) + ' GB';
}

function getKeys(obj) {
  var keys = [];
  for (var key in obj) {
    if (Object.prototype.hasOwnProperty.call(obj, key)) {
      keys.push(key);
    }
  }
  return keys;
}

function makeRequest(url, method, callback) {
  var xhr = new XMLHttpRequest();
  xhr.open(method, url, true);
  xhr.timeout = 3000;
  xhr.onreadystatechange = function () {
    if (xhr.readyState === 4) {
      callback(xhr);
    }
  };
  xhr.ontimeout = function () {
    callback({ status: 408 });
  };
  xhr.onerror = function () {
    callback({ status: 500 });
  };
  xhr.send();
}

function init() {
  firstRequestFiles();
}

init();
