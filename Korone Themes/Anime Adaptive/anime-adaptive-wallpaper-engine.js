/*
 * Anime Adaptive Wallpaper Engine helper for Vencord / Discord desktop.
 *
 * Usage:
 * 1. Copy this file somewhere easy to edit.
 * 2. Update CONFIG.playlist with your MP4 / WebM URLs or local file:/// paths.
 * 3. Paste the file into the Discord devtools console, or inject it through your own local Vencord workflow.
 * 4. Install anime-adaptive.css at the same time for the overlay/theme styling.
 *
 * The script is intentionally local-only. It does not depend on the Silver repo.
 */

(() => {
  const STORAGE_KEY = "korone-wallpaper-engine";
  const ROOT_ID = "korone-wallpaper-engine-root";
  const CLOCK_ID = "korone-wallpaper-engine-clock";
  const WIKI_WALLPAPER_BASE = "https://raw.githubusercontent.com/Silverfox0338/discord-themes/main/Korone%20Themes/Anime%20Adaptive/wallpapers";

  const CONFIG = {
    autoStart: true,
    defaultIndex: 0,
    volume: 0,
    muted: true,
    rememberLastWallpaper: true,
    addBodyClass: true,
    wallpaperWikiBaseUrl: WIKI_WALLPAPER_BASE,
    clock: {
      enabled: true,
      showSeconds: false,
      use24Hour: false,
      showWeekday: true,
      locale: undefined,
      timeZone: undefined,
      label: "Wallpaper Engine Mode"
    },
    audioReactive: {
      enabled: false,
      fftSize: 256,
      smoothingTimeConstant: 0.82,
      minScale: 1.015,
      maxScale: 1.045,
      minBrightness: 0.68,
      maxBrightness: 0.95,
      maxSaturationBoost: 0.3,
      maxBlurPx: 1.8
    },
    playlist: [
      {
        id: "azure-gif-fallback",
        label: "Azure Blade wiki GIF",
        type: "image",
        source: "wiki:/azure-blade-moewalls-com.gif"
      },
      {
        id: "local-bus-stop-mp4",
        label: "Local bus stop MP4",
        type: "video",
        source: "file:///C:/Users/notal/Documents/Korone%20Themes/discord-themes/Korone%20Themes/Anime%20Adaptive/wallpapers/anime-girl-waiting-for-bus-wallpaperwaifu-com.mp4",
        fallbackImage: "wiki:/azure-blade-moewalls-com.gif"
      },
      {
        id: "local-samurai-mp4",
        label: "Local samurai MP4",
        type: "video",
        source: "file:///C:/Users/notal/Documents/Korone%20Themes/discord-themes/Korone%20Themes/Anime%20Adaptive/wallpapers/samurai-anime-girl-with-sword-and-cyber-arm-wallpaperwaifu-com.mp4",
        fallbackImage: "wiki:/azure-blade-moewalls-com.gif"
      }
    ]
  };

  const state = {
    index: CONFIG.defaultIndex,
    video: null,
    root: null,
    audioContext: null,
    analyser: null,
    audioSource: null,
    audioData: null,
    audioAnimationFrame: 0,
    audioLevel: 0,
    clockTimer: 0
  };

  function loadSavedIndex() {
    if (!CONFIG.rememberLastWallpaper) return CONFIG.defaultIndex;
    try {
      const saved = JSON.parse(localStorage.getItem(STORAGE_KEY) || "{}");
      return Number.isInteger(saved.index) ? saved.index : CONFIG.defaultIndex;
    } catch {
      return CONFIG.defaultIndex;
    }
  }

  function saveIndex(index) {
    if (!CONFIG.rememberLastWallpaper) return;
    localStorage.setItem(STORAGE_KEY, JSON.stringify({ index }));
  }

  function getEntry(index) {
    return CONFIG.playlist[((index % CONFIG.playlist.length) + CONFIG.playlist.length) % CONFIG.playlist.length];
  }

  function resolveSource(urlValue) {
    if (typeof urlValue !== "string") return urlValue;
    if (!urlValue.startsWith("wiki:/")) return urlValue;
    const trimmedBase = CONFIG.wallpaperWikiBaseUrl.replace(/\/+$/, "");
    return `${trimmedBase}/${urlValue.slice("wiki:/".length)}`;
  }

  function ensureRoot() {
    let root = document.getElementById(ROOT_ID);
    if (!root) {
      root = document.createElement("div");
      root.id = ROOT_ID;
      document.body.prepend(root);
    }
    state.root = root;
    return root;
  }

  function destroyVideo() {
    if (state.video) {
      state.video.pause();
      state.video.removeAttribute("src");
      state.video.load();
      state.video.remove();
      state.video = null;
    }
  }

  function ensureClock() {
    if (!CONFIG.clock.enabled) return null;

    const root = ensureRoot();
    let clock = document.getElementById(CLOCK_ID);
    if (!clock) {
      clock = document.createElement("div");
      clock.id = CLOCK_ID;
      clock.innerHTML = `
        <div class="korone-clock-label"></div>
        <div class="korone-clock-time"></div>
        <div class="korone-clock-date"></div>
      `;
      root.append(clock);
    }
    return clock;
  }

  function clearClockTimer() {
    if (state.clockTimer) {
      clearInterval(state.clockTimer);
      state.clockTimer = 0;
    }
  }

  function getClockFormatOptions(baseOptions) {
    return {
      ...baseOptions,
      hour12: !CONFIG.clock.use24Hour,
      timeZone: CONFIG.clock.timeZone
    };
  }

  function renderClock() {
    if (!CONFIG.clock.enabled) {
      const existingClock = document.getElementById(CLOCK_ID);
      existingClock?.remove();
      clearClockTimer();
      return;
    }

    const clock = ensureClock();
    if (!clock) return;

    const now = new Date();
    const timeFormatter = new Intl.DateTimeFormat(
      CONFIG.clock.locale,
      getClockFormatOptions({
        hour: "numeric",
        minute: "2-digit",
        second: CONFIG.clock.showSeconds ? "2-digit" : undefined
      })
    );
    const dateFormatter = new Intl.DateTimeFormat(
      CONFIG.clock.locale,
      {
        weekday: CONFIG.clock.showWeekday ? "long" : undefined,
        month: "long",
        day: "numeric",
        year: "numeric",
        timeZone: CONFIG.clock.timeZone
      }
    );

    clock.querySelector(".korone-clock-label").textContent = CONFIG.clock.label || "";
    clock.querySelector(".korone-clock-time").textContent = timeFormatter.format(now);
    clock.querySelector(".korone-clock-date").textContent = dateFormatter.format(now);
  }

  function startClock() {
    clearClockTimer();
    renderClock();

    if (!CONFIG.clock.enabled) return;

    const intervalMs = CONFIG.clock.showSeconds ? 1000 : 15000;
    state.clockTimer = window.setInterval(renderClock, intervalMs);
  }

  function cleanupAudioReactive() {
    if (state.audioAnimationFrame) {
      cancelAnimationFrame(state.audioAnimationFrame);
      state.audioAnimationFrame = 0;
    }

    if (state.audioSource) {
      try {
        state.audioSource.disconnect();
      } catch {}
      state.audioSource = null;
    }

    if (state.audioContext) {
      void state.audioContext.close().catch(() => {});
      state.audioContext = null;
    }

    state.analyser = null;
    state.audioData = null;
    state.audioLevel = 0;
    document.documentElement.style.removeProperty("--korone-video-brightness");
    document.documentElement.style.removeProperty("--korone-video-saturation");
    document.documentElement.style.removeProperty("--korone-video-blur");
  }

  function renderAudioReactiveFrame() {
    if (!state.analyser || !state.audioData) return;

    state.analyser.getByteFrequencyData(state.audioData);

    let sum = 0;
    for (let i = 0; i < state.audioData.length; i += 1) {
      sum += state.audioData[i];
    }

    const average = sum / state.audioData.length / 255;
    state.audioLevel = average;

    const brightness = CONFIG.audioReactive.minBrightness + ((CONFIG.audioReactive.maxBrightness - CONFIG.audioReactive.minBrightness) * average);
    const saturation = 1 + (CONFIG.audioReactive.maxSaturationBoost * average);
    const blur = CONFIG.audioReactive.maxBlurPx * (1 - average);
    const scale = CONFIG.audioReactive.minScale + ((CONFIG.audioReactive.maxScale - CONFIG.audioReactive.minScale) * average);

    document.documentElement.style.setProperty("--korone-video-brightness", brightness.toFixed(3));
    document.documentElement.style.setProperty("--korone-video-saturation", saturation.toFixed(3));
    document.documentElement.style.setProperty("--korone-video-blur", `${blur.toFixed(3)}px`);

    if (state.video) {
      state.video.style.transform = `scale(${scale.toFixed(4)})`;
    }

    state.audioAnimationFrame = requestAnimationFrame(renderAudioReactiveFrame);
  }

  async function enableAudioReactiveFromStream(stream) {
    cleanupAudioReactive();

    const AudioContextCtor = window.AudioContext || window.webkitAudioContext;
    if (!AudioContextCtor) {
      throw new Error("Web Audio API is not available in this Discord build.");
    }

    const audioContext = new AudioContextCtor();
    const analyser = audioContext.createAnalyser();
    analyser.fftSize = CONFIG.audioReactive.fftSize;
    analyser.smoothingTimeConstant = CONFIG.audioReactive.smoothingTimeConstant;

    const source = audioContext.createMediaStreamSource(stream);
    source.connect(analyser);

    state.audioContext = audioContext;
    state.analyser = analyser;
    state.audioSource = source;
    state.audioData = new Uint8Array(analyser.frequencyBinCount);

    renderAudioReactiveFrame();
    return true;
  }

  async function enableAudioReactiveFromMic() {
    const stream = await navigator.mediaDevices.getUserMedia({
      audio: {
        echoCancellation: false,
        noiseSuppression: false,
        autoGainControl: false
      }
    });

    CONFIG.audioReactive.enabled = true;
    return enableAudioReactiveFromStream(stream);
  }

  async function enableAudioReactiveFromSelector(selector) {
    const media = document.querySelector(selector);
    if (!(media instanceof HTMLMediaElement)) {
      throw new Error(`No HTMLMediaElement found for selector: ${selector}`);
    }

    const capturedStream = typeof media.captureStream === "function"
      ? media.captureStream()
      : typeof media.mozCaptureStream === "function"
        ? media.mozCaptureStream()
        : null;

    if (!capturedStream) {
      throw new Error("captureStream() is not available on the selected media element.");
    }

    CONFIG.audioReactive.enabled = true;
    return enableAudioReactiveFromStream(capturedStream);
  }

  function disableAudioReactive() {
    CONFIG.audioReactive.enabled = false;
    cleanupAudioReactive();
    if (state.video) {
      state.video.style.transform = `scale(${CONFIG.audioReactive.minScale})`;
    }
  }

  function setThemeWallpaper(urlValue) {
    document.body.classList.remove("korone-video-wallpaper-active");
    const resolvedUrl = resolveSource(urlValue);
    document.documentElement.style.setProperty("--korone-static-wallpaper", `url("${resolvedUrl}")`);
    document.documentElement.style.setProperty("--korone-active-wallpaper", `url("${resolvedUrl}")`);
    startClock();
  }

  function mountVideo(entry) {
    const root = ensureRoot();
    destroyVideo();

    const video = document.createElement("video");
    video.autoplay = true;
    video.loop = true;
    video.muted = CONFIG.muted;
    video.defaultMuted = CONFIG.muted;
    video.volume = CONFIG.volume;
    video.playsInline = true;
    video.preload = "auto";
    video.src = resolveSource(entry.source);

    video.addEventListener("canplay", () => {
      if (CONFIG.addBodyClass) {
        document.body.classList.add("korone-video-wallpaper-active");
      }
      if (entry.fallbackImage) {
        document.documentElement.style.setProperty("--korone-static-wallpaper", `url("${resolveSource(entry.fallbackImage)}")`);
      }
      document.documentElement.style.setProperty("--korone-active-wallpaper", "none");
      video.style.transform = `scale(${CONFIG.audioReactive.minScale})`;
      void video.play().catch(() => {});
    });

    video.addEventListener("error", () => {
      console.warn("[KoroneWallpaperEngine] Video failed to load:", entry.source);
    });

    root.replaceChildren(video);
    state.video = video;
    if (CONFIG.clock.enabled) {
      root.append(ensureClock());
      startClock();
    }
  }

  function apply(index) {
    if (!CONFIG.playlist.length) {
      console.warn("[KoroneWallpaperEngine] Playlist is empty.");
      return null;
    }

    state.index = ((index % CONFIG.playlist.length) + CONFIG.playlist.length) % CONFIG.playlist.length;
    saveIndex(state.index);

    const entry = getEntry(state.index);
    if (!entry) return null;

    if (entry.type === "video") {
      mountVideo(entry);
    } else {
      destroyVideo();
      ensureRoot().replaceChildren();
      setThemeWallpaper(entry.source);
    }

    console.info(`[KoroneWallpaperEngine] Active wallpaper: ${entry.label}`);
    return entry;
  }

  function next() {
    return apply(state.index + 1);
  }

  function prev() {
    return apply(state.index - 1);
  }

  function pause() {
    state.video?.pause();
  }

  function play() {
    void state.video?.play().catch(() => {});
  }

  function set(index) {
    return apply(index);
  }

  function list() {
    return CONFIG.playlist.map((entry, index) => ({
      index,
      id: entry.id,
      label: entry.label,
      type: entry.type,
      source: resolveSource(entry.source)
    }));
  }

  function getAudioLevel() {
    return state.audioLevel;
  }

  function enableClock() {
    CONFIG.clock.enabled = true;
    startClock();
  }

  function disableClock() {
    CONFIG.clock.enabled = false;
    renderClock();
  }

  function refreshClock() {
    renderClock();
  }

  window.KoroneWallpaperEngine = {
    apply,
    next,
    prev,
    pause,
    play,
    set,
    list,
    getAudioLevel,
    enableClock,
    disableClock,
    refreshClock,
    enableAudioReactiveFromMic,
    enableAudioReactiveFromSelector,
    disableAudioReactive,
    config: CONFIG
  };

  state.index = loadSavedIndex();
  ensureRoot();
  startClock();

  if (CONFIG.autoStart) {
    apply(state.index);
  }

  console.info("[KoroneWallpaperEngine] Ready. Try KoroneWallpaperEngine.list() or KoroneWallpaperEngine.next()");
})();
