# Anime Adaptive Vencord Wallpaper Engine

This setup keeps the repo theme in CSS, uses repo-hosted wallpaper assets, and adds a small optional JavaScript helper for local Vencord video wallpapers plus a Wallpaper Engine-style clock overlay.

## What it does

- Uses `anime-adaptive.css` for the full Discord styling layer
- Uses repo-hosted GIF/JPG wallpaper assets from the Anime Adaptive wallpaper folder
- Injects a fullscreen muted looping `<video>` behind Discord when the selected wallpaper is an MP4 or WebM
- Falls back to a normal image/GIF wallpaper when the selected playlist entry is not a video
- Remembers the last selected wallpaper in `localStorage`
- Renders a live date/time overlay so the setup feels closer to Wallpaper Engine
- Can optionally react to live audio by adjusting video brightness, saturation, blur, and scale

## Files

- `anime-adaptive.css`
- `anime-adaptive-wallpaper-engine.js`

## Setup

1. Keep shared GIF/JPG wallpaper assets in `Korone Themes/Anime Adaptive/wallpapers/` in the main repo.
2. Install [anime-adaptive.css](./anime-adaptive.css) in Vencord Themes.
3. Open [anime-adaptive-wallpaper-engine.js](./anime-adaptive-wallpaper-engine.js) and edit `CONFIG.playlist`.
4. Replace the sample `file:///` paths with your own local MP4/WebM files. Keep large video files local unless you intentionally host them elsewhere.
5. If your wallpaper asset path differs, update `CONFIG.wallpaperWikiBaseUrl` so the fallback GIF/JPG links match the repo layout you use.
6. Paste the script into Discord devtools console, or load it using your own local Vencord script workflow.

## Controls

After the script loads, these helpers are available in the console:

- `KoroneWallpaperEngine.list()`
- `KoroneWallpaperEngine.set(0)`
- `KoroneWallpaperEngine.next()`
- `KoroneWallpaperEngine.prev()`
- `KoroneWallpaperEngine.pause()`
- `KoroneWallpaperEngine.play()`
- `KoroneWallpaperEngine.enableClock()`
- `KoroneWallpaperEngine.disableClock()`
- `KoroneWallpaperEngine.refreshClock()`
- `KoroneWallpaperEngine.enableAudioReactiveFromMic()`
- `KoroneWallpaperEngine.enableAudioReactiveFromSelector("audio, video")`
- `KoroneWallpaperEngine.disableAudioReactive()`

## Wallpaper Hosting

For upstream-ready CSS variants, point wallpaper URLs at the main repo raw host instead of a personal fork. The helper now assumes a base like:

`https://raw.githubusercontent.com/Silverfox0338/discord-themes/main/Korone%20Themes/Anime%20Adaptive/wallpapers`

That keeps the preset CSS variants aligned with the repo validation rules.

## Date And Time Overlay

The helper now includes a clock/date widget by default. You can tune it in `CONFIG.clock`:

- `enabled`
- `showSeconds`
- `use24Hour`
- `showWeekday`
- `locale`
- `timeZone`
- `label`

This is visual-only, similar to a Wallpaper Engine scene layer. It uses your system locale by default unless you override it.

## Audio-Reactive Mode

This is not full Wallpaper Engine audio capture. What works reliably in browser JS is:

- microphone or line-in capture with `KoroneWallpaperEngine.enableAudioReactiveFromMic()`
- attaching to a specific page media element with `KoroneWallpaperEngine.enableAudioReactiveFromSelector(...)`

What does not work as a guaranteed one-click feature here:

- automatic global Windows audio capture for anything playing on the PC
- deep native audio visualizer plugins like Wallpaper Engine has

If your Windows audio setup exposes Stereo Mix or another loopback input, the mic mode can still behave a lot like system-audio reactivity.

## Notes

- This is intentionally local-first and fork-safe. It does not require submitting anything to the Silver upstream repo.
- GitHub will not be happy if you try to push very large MP4s into the repo. Keep video files local unless you host them somewhere meant for large media.
- Silverfox0338 replied on April 19, 2026 in issue #31 that you can open a branch and send a PR with very detailed setup instructions, so this helper should be documented carefully if you want to upstream it.
