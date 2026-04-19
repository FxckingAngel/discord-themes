# Anime Adaptive Vencord Wallpaper Engine

This setup keeps the repo theme in CSS and adds a small local-only JavaScript helper for video wallpapers in Vencord.

## What it does

- Uses `anime-adaptive.css` for the full Discord styling layer
- Injects a fullscreen muted looping `<video>` behind Discord when the selected wallpaper is an MP4 or WebM
- Falls back to a normal image/GIF wallpaper when the selected playlist entry is not a video
- Remembers the last selected wallpaper in `localStorage`

## Files

- `anime-adaptive.css`
- `anime-adaptive-wallpaper-engine.js`

## Setup

1. Install [anime-adaptive.css](./anime-adaptive.css) in Vencord Themes.
2. Open [anime-adaptive-wallpaper-engine.js](./anime-adaptive-wallpaper-engine.js) and edit `CONFIG.playlist`.
3. Replace the sample `file:///` paths with your own local MP4/WebM files or direct remote URLs.
4. Paste the script into Discord devtools console, or load it using your own local Vencord script workflow.

## Controls

After the script loads, these helpers are available in the console:

- `KoroneWallpaperEngine.list()`
- `KoroneWallpaperEngine.set(0)`
- `KoroneWallpaperEngine.next()`
- `KoroneWallpaperEngine.prev()`
- `KoroneWallpaperEngine.pause()`
- `KoroneWallpaperEngine.play()`

## Notes

- This is intentionally local-first and fork-safe. It does not require submitting anything to the Silver upstream repo.
- GitHub will not be happy if you try to push very large MP4s into the repo. Keep video files local unless you host them somewhere meant for large media.
- If you want to ask Silver about upstreaming later, ask for permission first because this adds JavaScript behavior and changes the repo from theme-only toward a helper-tool setup.
