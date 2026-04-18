param(
  [string]$Name = "",
  [string]$Author = "",
  [string]$Version = "",
  [string]$Description = "",
  [string]$Folder = "",
  [string]$FileName = ""
)

$ErrorActionPreference = "Stop"

function Get-RepoRoot {
  return (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

$repoRoot = Get-RepoRoot
$themeFolders = @(Get-ChildItem -LiteralPath $repoRoot -Directory | Where-Object { $_.Name -like "* Themes" } | Select-Object -ExpandProperty Name | Sort-Object)

if ([string]::IsNullOrWhiteSpace($Name)) {
  $Name = (Read-Host "Theme name").Trim()
  if ([string]::IsNullOrWhiteSpace($Name)) {
    [Console]::Error.WriteLine("Error: Theme name is required.")
    exit 1
  }
}

if ([string]::IsNullOrWhiteSpace($Author)) {
  $Author = (Read-Host "Author").Trim()
  if ([string]::IsNullOrWhiteSpace($Author)) {
    [Console]::Error.WriteLine("Error: Author is required.")
    exit 1
  }
}

if ([string]::IsNullOrWhiteSpace($Version)) {
  $inputVersion = (Read-Host "Version [1.0.0]").Trim()
  $Version = if ([string]::IsNullOrWhiteSpace($inputVersion)) { "1.0.0" } else { $inputVersion }
}

if ([string]::IsNullOrWhiteSpace($Description)) {
  $Description = (Read-Host "Description").Trim()
}

if ([string]::IsNullOrWhiteSpace($Folder)) {
  if ($themeFolders.Count -gt 0) {
    Write-Host ""
    Write-Host "Available theme folders:"
    for ($i = 0; $i -lt $themeFolders.Count; $i++) {
      Write-Host "  $($i + 1)) $($themeFolders[$i])"
    }
    Write-Host "  N) New folder"

    while ($true) {
      $choice = (Read-Host "Pick folder (1-$($themeFolders.Count) or N)").Trim()
      if ($choice -match "^[nN]$") {
        $Folder = (Read-Host "New folder name (e.g. 'My Themes')").Trim()
        break
      } elseif ($choice -match "^\d+$") {
        $idx = [int]$choice
        if ($idx -ge 1 -and $idx -le $themeFolders.Count) {
          $Folder = $themeFolders[$idx - 1]
          break
        }
      }
      Write-Host "Invalid selection."
    }
  } else {
    $Folder = (Read-Host "Theme folder name (e.g. 'My Themes')").Trim()
  }

  if ([string]::IsNullOrWhiteSpace($Folder)) {
    [Console]::Error.WriteLine("Error: Folder is required.")
    exit 1
  }
}

if ([string]::IsNullOrWhiteSpace($FileName)) {
  $defaultFileName = ($Name.ToLower() -replace "[^a-z0-9]+", "-").Trim("-") + ".css"
  $inputFileName = (Read-Host "CSS filename [$defaultFileName]").Trim()
  $FileName = if ([string]::IsNullOrWhiteSpace($inputFileName)) { $defaultFileName } else { $inputFileName }
}

if (-not $FileName.EndsWith(".css")) {
  $FileName += ".css"
}

$folderPath = Join-Path $repoRoot $Folder
$outputPath = Join-Path $folderPath $FileName

if (Test-Path -LiteralPath $outputPath) {
  [Console]::Error.WriteLine("Error: File already exists: $Folder/$FileName")
  exit 1
}

if (-not (Test-Path -LiteralPath $folderPath)) {
  New-Item -ItemType Directory -Path $folderPath | Out-Null
  Write-Output "Created folder: $Folder"
}

$template = "/**
 * @name $Name
 * @author $Author
 * @version $Version
 * @description $Description
 */

@import url(`"https://clearvision.github.io/ClearVision-v7/main.css`");

/* Optional: add a Google Font below
   @import url('https://fonts.googleapis.com/css2?family=YOUR+FONT&display=swap'); */

:root {
  /* === Colors === */
  --main-color: #5865F2;
  --hover-color: #6B77F3;
  --success-color: #57F287;
  --danger-color: #ED4245;
  --warning-color: #FEE75C;
  --online-color: #57F287;
  --idle-color: #FEE75C;
  --dnd-color: #ED4245;
  --streaming-color: #593695;
  --offline-color: #80848E;
  --invisible-color: #80848E;

  /* === Background === */
  --background-shading: 100%;
  --background-image: url(`"https://i.imgur.com/YOUR_IMAGE.jpg`");
  --background-position: center;
  --background-size: cover;
  --background-repeat: no-repeat;
  --background-attachment: fixed;
  --background-brightness: 0.6;
  --background-contrast: 1;
  --background-saturation: 1;
  --background-grayscale: 0%;
  --background-invert: 0%;
  --background-blur: 0px;
  --transparency: 0.9;

  /* === User popout === */
  --user-popout-image: var(--background-image);
  --user-popout-position: center;
  --user-popout-size: cover;
  --user-popout-blur: 5px;
  --user-popout-brightness: 0.5;

  /* === Fonts === */
  --main-font: `"gg sans`", `"Noto Sans`", sans-serif;
  --code-font: `"Consolas`", `"gg mono`", monospace;
  --font-primary: var(--main-font);
  --font-display: var(--main-font);

  /* === Home icon === */
  --home-icon: url(`"https://i.imgur.com/YOUR_ICON.png`");
  --home-position: center;
  --home-size: 100%;
}

/* === Dark theme overrides === */
.theme-dark {
  --text-normal: #DCDDDE;
  --text-muted: #8E9297;
  --header-primary: #FFFFFF;
  --header-secondary: #B9BBBE;
}

/* === Light theme overrides === */
.theme-light {
  --text-normal: #2E3338;
  --text-muted: #747F8D;
  --header-primary: #060607;
  --header-secondary: #4F5660;
}

/* === Scrollbar === */
::-webkit-scrollbar {
  width: 8px !important;
}

::-webkit-scrollbar-track {
  background: transparent !important;
}

::-webkit-scrollbar-thumb {
  background: rgba(88, 101, 242, 0.3) !important;
  border-radius: 4px !important;
}

::-webkit-scrollbar-thumb:hover {
  background: rgba(88, 101, 242, 0.5) !important;
}

/* === Add your custom styles below === */
"

$utf8Bom = New-Object System.Text.UTF8Encoding($true)
[System.IO.File]::WriteAllText($outputPath, $template, $utf8Bom)

Write-Output "Created: $Folder/$FileName"
Write-Output "Next steps:"
Write-Output "  1. Edit $Folder/$FileName - swap in your colors, background URL, and styles"
Write-Output "  2. Run '.\themecmd.cmd' to regenerate README.md"
