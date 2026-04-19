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

  const CONFIG = {
    autoStart: true,
    defaultIndex: 0,
    volume: 0,
    muted: true,
    rememberLastWallpaper: true,
    addBodyClass: true,
    playlist: [
      {
        id: "azure-gif-fallback",
        label: "Azure Blade GIF fallback",
        type: "image",
        source: "https://raw.githubusercontent.com/FxckingAngel/discord-themes/main/Korone%20Themes/Anime%20Adaptive/wallpapers/azure-blade-moewalls-com.gif"
      },
      {
        id: "local-bus-stop-mp4",
        label: "Local bus stop MP4",
        type: "video",
        source: "file:///C:/Users/notal/Documents/Korone%20Themes/discord-themes/Korone%20Themes/Anime%20Adaptive/wallpapers/anime-girl-waiting-for-bus-wallpaperwaifu-com.mp4",
        fallbackImage: "https://raw.githubusercontent.com/FxckingAngel/discord-themes/main/Korone%20Themes/Anime%20Adaptive/wallpapers/azure-blade-moewalls-com.gif"
      },
      {
        id: "local-samurai-mp4",
        label: "Local samurai MP4",
        type: "video",
        source: "file:///C:/Users/notal/Documents/Korone%20Themes/discord-themes/Korone%20Themes/Anime%20Adaptive/wallpapers/samurai-anime-girl-with-sword-and-cyber-arm-wallpaperwaifu-com.mp4",
        fallbackImage: "https://raw.githubusercontent.com/FxckingAngel/discord-themes/main/Korone%20Themes/Anime%20Adaptive/wallpapers/azure-blade-moewalls-com.gif"
      }
    ]
  };

  const state = {
    index: CONFIG.defaultIndex,
    video: null,
    root: null
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

  function setThemeWallpaper(urlValue) {
    document.body.classList.remove("korone-video-wallpaper-active");
    document.documentElement.style.setProperty("--korone-static-wallpaper", `url("${urlValue}")`);
    document.documentElement.style.setProperty("--korone-active-wallpaper", `url("${urlValue}")`);
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
    video.src = entry.source;

    video.addEventListener("canplay", () => {
      if (CONFIG.addBodyClass) {
        document.body.classList.add("korone-video-wallpaper-active");
      }
      if (entry.fallbackImage) {
        document.documentElement.style.setProperty("--korone-static-wallpaper", `url("${entry.fallbackImage}")`);
      }
      document.documentElement.style.setProperty("--korone-active-wallpaper", "none");
      void video.play().catch(() => {});
    });

    video.addEventListener("error", () => {
      console.warn("[KoroneWallpaperEngine] Video failed to load:", entry.source);
    });

    root.replaceChildren(video);
    state.video = video;
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
      source: entry.source
    }));
  }

  window.KoroneWallpaperEngine = {
    apply,
    next,
    prev,
    pause,
    play,
    set,
    list,
    config: CONFIG
  };

  state.index = loadSavedIndex();
  ensureRoot();

  if (CONFIG.autoStart) {
    apply(state.index);
  }

  console.info("[KoroneWallpaperEngine] Ready. Try KoroneWallpaperEngine.list() or KoroneWallpaperEngine.next()");
})();
