# Syncs accent colors in anime-adaptive.css from a wallpaper image (static or GIF first frame).
# Run after you change the GIF/JPG so UI colors match the scene. Pure CSS cannot read pixels at runtime.
param(
  [Parameter(Mandatory = $true)]
  [string]$WallpaperPath,
  [string]$CssPath = "",
  [string]$BackgroundFileName = "",
  [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($CssPath)) {
  $base = $PSScriptRoot
  if ([string]::IsNullOrWhiteSpace($base)) {
    $base = Split-Path -LiteralPath $MyInvocation.MyCommand.Path -Parent
  }
  $CssPath = Join-Path $base "anime-adaptive.css"
}

if (-not (Test-Path -LiteralPath $CssPath)) {
  throw "CSS not found: $CssPath"
}
if (-not (Test-Path -LiteralPath $WallpaperPath)) {
  throw "Wallpaper not found: $WallpaperPath"
}

Add-Type -AssemblyName System.Drawing

function Clamp([int]$v) {
  return [Math]::Max(0, [Math]::Min(255, $v))
}

function ToHex([int]$r, [int]$g, [int]$b) {
  return ("#{0:X2}{1:X2}{2:X2}" -f $r, $g, $b)
}

function Lighten([int]$r, [int]$g, [int]$b, [double]$t) {
  return [pscustomobject]@{
    R = Clamp([int]($r + (255 - $r) * $t))
    G = Clamp([int]($g + (255 - $g) * $t))
    B = Clamp([int]($b + (255 - $b) * $t))
  }
}

function Darken([int]$r, [int]$g, [int]$b, [double]$t) {
  return [pscustomobject]@{
    R = Clamp([int]($r * (1 - $t)))
    G = Clamp([int]($g * (1 - $t)))
    B = Clamp([int]($b * (1 - $t)))
  }
}

$resolved = (Resolve-Path -LiteralPath $WallpaperPath).Path
$img = [System.Drawing.Image]::FromFile($resolved)
try {
  $bmp = New-Object System.Drawing.Bitmap $img
  try {
    $w = $bmp.Width
    $h = $bmp.Height
    $x0 = [int]($w * 0.15)
    $y0 = [int]($h * 0.15)
    $x1 = [int]($w * 0.85)
    $y1 = [int]($h * 0.85)
    $sr = 0
    $sg = 0
    $sb = 0
    $n = 0
    for ($x = $x0; $x -lt $x1; $x += 6) {
      for ($y = $y0; $y -lt $y1; $y += 6) {
        $c = $bmp.GetPixel($x, $y)
        $sr += [int]$c.R
        $sg += [int]$c.G
        $sb += [int]$c.B
        $n++
      }
    }
    $ar = [int]($sr / $n)
    $ag = [int]($sg / $n)
    $ab = [int]($sb / $n)
  }
  finally {
    $bmp.Dispose()
  }
}
finally {
  $img.Dispose()
}

$lum = 0.2126 * $ar + 0.7152 * $ag + 0.0722 * $ab
$main = Lighten $ar $ag $ab 0.08
$hover = Lighten $ar $ag $ab 0.22
$deep = Darken $ar $ag $ab 0.35
$mutedR = Clamp([int](($ar + 110) / 2))
$mutedG = Clamp([int](($ag + 110) / 2))
$mutedB = Clamp([int](($ab + 130) / 2))

$mainHex = ToHex $main.R $main.G $main.B
$hoverHex = ToHex $hover.R $hover.G $hover.B
# Keep Discord-semantic status colors readable; wallpaper drives accents only.
$dangerHex = "#ED4245"
$successHex = "#57F287"
$warningHex = "#FEE75C"

$hue = [int]([System.Drawing.Color]::FromArgb($ar, $ag, $ab).GetHue())
$sat = [int]([System.Drawing.Color]::FromArgb($ar, $ag, $ab).GetSaturation() * 100)
$bright = [int]([System.Drawing.Color]::FromArgb($ar, $ag, $ab).GetBrightness() * 100)

$overlayAlpha = if ($lum -lt 70) { "0.42" } else { "0.32" }
$bgBrightness = if ($lum -lt 75) { "0.52" } else { "0.58" }

$bgFile = $BackgroundFileName.Trim()
if ([string]::IsNullOrWhiteSpace($bgFile)) {
  $bgFile = [System.IO.Path]::GetFileName($resolved)
}

$newBlock = @"
  --accent-r: $ar;
  --accent-g: $ag;
  --accent-b: $ab;
  --main-color: $mainHex;
  --hover-color: $hoverHex;
  --danger-color: $dangerHex;
  --success-color: $successHex;
  --warning-color: $warningHex;
  --online-color: $successHex;
  --idle-color: $warningHex;
  --dnd-color: $dangerHex;
  --streaming-color: $hoverHex;
  --offline-color: #80848E;
  --invisible-color: #80848E;
  --text-link: $hoverHex;
  --channel-unread: #F2F5FF;
  --channel-color: $(ToHex $mutedR $mutedG $mutedB);
  --channel-text-selected: #FFFFFF;
  --muted-color: #8E9AB8;
  --accent-hue: $hue;
  --accent-saturation: $($sat)%;
  --accent-brightness: $($bright)%;
  --accent-glow: rgba($ar, $ag, $ab, 0.38);
  --deep-surface: $(ToHex $deep.R $deep.G $deep.B);
  --background-overlay: rgba($ar, $ag, $ab, $overlayAlpha);
  --background-brightness: $bgBrightness;
"@

$raw = [System.IO.File]::ReadAllText($CssPath)
if ($raw.Length -gt 0 -and [int][char]$raw[0] -eq 0xFEFF) {
  $raw = $raw.Substring(1)
}

# Do not consume leading whitespace before the start marker (keeps newline after --background-image).
$pattern = '(?s)/\* <ANIME_ACCENT_AUTO_START> \*/\s*.*?\s*/\* <ANIME_ACCENT_AUTO_END> \*/'
if ($raw -notmatch $pattern) {
  throw "Could not find ANIME_ACCENT_AUTO markers in: $CssPath"
}

$replacement = "/* <ANIME_ACCENT_AUTO_START> */`r`n$newBlock`r`n  /* <ANIME_ACCENT_AUTO_END> */"
$rx = New-Object System.Text.RegularExpressions.Regex($pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
$updated = $rx.Replace($raw, $replacement, 1)

$bgUrlLine = '  --background-image: url("./wallpapers/' + ($bgFile -replace '\\', '/') + '");'
$bgRx = New-Object System.Text.RegularExpressions.Regex(
  '^\s*--background-image:\s*url\("\./wallpapers/[^"]+"\);\s*$',
  [System.Text.RegularExpressions.RegexOptions]::Multiline
)
$updated = $bgRx.Replace($updated, $bgUrlLine, 1)

if ($updated.Contains('");/* <ANIME_ACCENT_AUTO_START>')) {
  $updated = $updated.Replace(
    '");/* <ANIME_ACCENT_AUTO_START>',
    ('");' + [Environment]::NewLine + [Environment]::NewLine + '  /* <ANIME_ACCENT_AUTO_START>')
  )
}

if ($WhatIf) {
  Write-Output $newBlock
  Write-Output "--- background line ---"
  Write-Output $bgUrlLine
  exit 0
}

$utf8Bom = New-Object System.Text.UTF8Encoding($true)
[System.IO.File]::WriteAllText($CssPath, $updated, $utf8Bom)
Write-Output "Updated accents from: $resolved"
Write-Output "Background set to: wallpapers\$bgFile"
