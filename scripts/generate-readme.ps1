param(
  [string]$OutputPath = "README.md",
  [string]$MetadataPath = "theme-authors.json"
)

$ErrorActionPreference = "Stop"

function Get-RepoRoot {
  return (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

function To-RelativePath {
  param(
    [string]$Root,
    [string]$Path
  )

  $resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
  $resolvedPath = (Resolve-Path -LiteralPath $Path).Path

  if (-not $resolvedRoot.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
    $resolvedRoot += [System.IO.Path]::DirectorySeparatorChar
  }

  $rootUri = New-Object System.Uri($resolvedRoot)
  $fileUri = New-Object System.Uri($resolvedPath)
  $relativeUri = $rootUri.MakeRelativeUri($fileUri)

  return ([System.Uri]::UnescapeDataString($relativeUri.ToString())).Replace('\', '/')
}

function Get-MetadataValue {
  param(
    [string]$Raw,
    [string]$Key
  )

  $pattern = "(?mi)^\s*\*\s*@${Key}\s+(.*)\s*$"
  $match = [regex]::Match($Raw, $pattern)
  if ($match.Success) {
    return $match.Groups[1].Value.Trim()
  }

  return ""
}

function Escape-TableCell {
  param(
    [string]$Value
  )

  if ([string]::IsNullOrWhiteSpace($Value)) {
    return "-"
  }

  $singleLine = ($Value -replace "\r?\n", " ").Trim()
  return $singleLine.Replace("|", "\|")
}

function Get-LinkPath {
  param(
    [string]$RelativePath
  )

  $segments = $RelativePath -split "/"
  $encoded = foreach ($segment in $segments) {
    [System.Uri]::EscapeDataString($segment)
  }

  return ($encoded -join "/")
}

function Get-GitOutput {
  param(
    [string[]]$CommandArgs
  )

  try {
    $output = & git @CommandArgs 2>$null
    if ($LASTEXITCODE -ne 0) {
      return ""
    }

    if ($null -eq $output) {
      return ""
    }

    return ($output -join [Environment]::NewLine).Trim()
  } catch {
    return ""
  }
}

function Get-BranchName {
  $originHead = Get-GitOutput -CommandArgs @("symbolic-ref", "refs/remotes/origin/HEAD")
  if (-not [string]::IsNullOrWhiteSpace($originHead) -and $originHead -match "^refs/remotes/origin/(.+)$") {
    return $matches[1]
  }

  $currentBranch = Get-GitOutput -CommandArgs @("rev-parse", "--abbrev-ref", "HEAD")
  if (-not [string]::IsNullOrWhiteSpace($currentBranch) -and $currentBranch -ne "HEAD") {
    return $currentBranch
  }

  return "main"
}

function Get-GitHubRawBaseUrl {
  $origin = Get-GitOutput -CommandArgs @("remote", "get-url", "origin")
  if ([string]::IsNullOrWhiteSpace($origin)) {
    return ""
  }

  $normalized = $origin.Trim()
  if ($normalized.EndsWith(".git")) {
    $normalized = $normalized.Substring(0, $normalized.Length - 4)
  }

  $owner = ""
  $repo = ""

  if ($normalized -match "^https?://github\.com/([^/]+)/([^/]+)$") {
    $owner = $matches[1]
    $repo = $matches[2]
  } elseif ($normalized -match "^git@github\.com:([^/]+)/([^/]+)$") {
    $owner = $matches[1]
    $repo = $matches[2]
  } else {
    return ""
  }

  if ([string]::IsNullOrWhiteSpace($owner) -or [string]::IsNullOrWhiteSpace($repo)) {
    return ""
  }

  $branch = Get-BranchName
  return "https://raw.githubusercontent.com/$owner/$repo/$branch"
}

function Get-MainFolder {
  param(
    [string]$RelativePath
  )

  $parts = $RelativePath -split "/"
  if ($parts.Length -gt 1) {
    return $parts[0]
  }

  return ""
}

function Get-ObjectPropertyValue {
  param(
    $Object,
    [string]$Name
  )

  if ($null -eq $Object) {
    return $null
  }

  if ($Object -is [System.Collections.IDictionary]) {
    if ($Object.Contains($Name)) {
      return $Object[$Name]
    }

    return $null
  }

  $property = $Object.PSObject.Properties[$Name]
  if ($null -ne $property) {
    return $property.Value
  }

  return $null
}

function Convert-ToDictionary {
  param(
    $Object
  )

  $dictionary = @{}

  if ($null -eq $Object) {
    return $dictionary
  }

  if ($Object -is [System.Collections.IDictionary]) {
    foreach ($key in $Object.Keys) {
      $dictionary[[string]$key] = $Object[$key]
    }

    return $dictionary
  }

  foreach ($property in $Object.PSObject.Properties) {
    $dictionary[$property.Name] = $property.Value
  }

  return $dictionary
}

function Read-AuthorMetadata {
  param(
    [string]$RepoRoot,
    [string]$MetadataPath
  )

  $resolvedPath = if ([System.IO.Path]::IsPathRooted($MetadataPath)) {
    $MetadataPath
  } else {
    Join-Path $RepoRoot $MetadataPath
  }

  $result = [PSCustomObject]@{
    Path          = $resolvedPath
    SchemaVersion = $null
    FolderMap     = @{}
    IsLoaded      = $false
  }

  if (-not (Test-Path -LiteralPath $resolvedPath)) {
    Write-Warning "Author metadata file not found: $resolvedPath"
    return $result
  }

  try {
    $rawJson = Get-Content -LiteralPath $resolvedPath -Raw
    $json = $rawJson | ConvertFrom-Json
  } catch {
    Write-Warning "Failed to parse author metadata '$resolvedPath': $($_.Exception.Message)"
    return $result
  }

  $result.SchemaVersion = Get-ObjectPropertyValue -Object $json -Name "schemaVersion"
  $folders = Get-ObjectPropertyValue -Object $json -Name "folders"
  $result.FolderMap = Convert-ToDictionary -Object $folders
  $result.IsLoaded = $true

  return $result
}

function Resolve-AuthorFromMetadata {
  param(
    [string]$MainFolder,
    [hashtable]$FolderMap
  )

  if ([string]::IsNullOrWhiteSpace($MainFolder)) {
    return ""
  }

  if (-not $FolderMap.ContainsKey($MainFolder)) {
    return ""
  }

  $folderEntry = $FolderMap[$MainFolder]
  if ($null -eq $folderEntry) {
    return ""
  }

  $authorsValue = Get-ObjectPropertyValue -Object $folderEntry -Name "authors"
  if ($null -ne $authorsValue) {
    $authors = [System.Collections.Generic.List[string]]::new()

    if ($authorsValue -is [string]) {
      $candidate = $authorsValue.Trim()
      if (-not [string]::IsNullOrWhiteSpace($candidate)) {
        $authors.Add($candidate)
      }
    } elseif ($authorsValue -is [System.Collections.IEnumerable]) {
      foreach ($item in $authorsValue) {
        if ($null -eq $item) { continue }

        $candidate = ([string]$item).Trim()
        if (-not [string]::IsNullOrWhiteSpace($candidate)) {
          $authors.Add($candidate)
        }
      }
    }

    if ($authors.Count -gt 0) {
      return ($authors -join ", ")
    }
  }

  $authorValue = Get-ObjectPropertyValue -Object $folderEntry -Name "author"
  if ($null -ne $authorValue) {
    $authorText = ([string]$authorValue).Trim()
    if (-not [string]::IsNullOrWhiteSpace($authorText)) {
      return $authorText
    }
  }

  return ""
}

$repoRoot = Get-RepoRoot
$outputFile = if ([System.IO.Path]::IsPathRooted($OutputPath)) {
  $OutputPath
} else {
  Join-Path $repoRoot $OutputPath
}
$authorMetadata = Read-AuthorMetadata -RepoRoot $repoRoot -MetadataPath $MetadataPath
$rawBaseUrl = Get-GitHubRawBaseUrl

$cssFiles = Get-ChildItem -Path $repoRoot -Recurse -File -Filter "*.css" | Sort-Object FullName
$themes = [System.Collections.Generic.List[object]]::new()
$fallbackByFolder = @{}

foreach ($file in $cssFiles) {
  $raw = Get-Content -LiteralPath $file.FullName -Raw
  $relativePath = To-RelativePath -Root $repoRoot -Path $file.FullName
  $mainFolder = Get-MainFolder -RelativePath $relativePath

  $name = Get-MetadataValue -Raw $raw -Key "name"
  if ([string]::IsNullOrWhiteSpace($name)) {
    $name = $file.BaseName
  }

  $authorFromFolder = Resolve-AuthorFromMetadata -MainFolder $mainFolder -FolderMap $authorMetadata.FolderMap
  $authorFromHeader = Get-MetadataValue -Raw $raw -Key "author"
  $hasFolderMapping = $authorMetadata.FolderMap.ContainsKey($mainFolder)

  $usedFallback = $false
  $fallbackReason = ""

  if (-not [string]::IsNullOrWhiteSpace($authorFromFolder)) {
    $author = $authorFromFolder
  } elseif (-not [string]::IsNullOrWhiteSpace($authorFromHeader)) {
    $author = $authorFromHeader
    $usedFallback = $true
    if ($hasFolderMapping) {
      $fallbackReason = "Folder mapping exists but has no usable author/authors value."
    } else {
      $fallbackReason = "No folder mapping found; used CSS @author fallback."
    }
  } else {
    $author = "Unknown"
    $usedFallback = $true
    if ($hasFolderMapping) {
      $fallbackReason = "Folder mapping exists but has no usable author/authors value, and CSS @author is missing."
    } else {
      $fallbackReason = "No folder mapping found and CSS @author is missing."
    }
  }

  if (
    $usedFallback -and
    -not [string]::IsNullOrWhiteSpace($mainFolder) -and
    -not $fallbackByFolder.ContainsKey($mainFolder)
  ) {
    $fallbackByFolder[$mainFolder] = [PSCustomObject]@{
      Folder         = $mainFolder
      FallbackAuthor = $author
      Reason         = $fallbackReason
    }
  }

  $theme = [PSCustomObject]@{
    Name        = $name
    Author      = $author
    Version     = Get-MetadataValue -Raw $raw -Key "version"
    Description = Get-MetadataValue -Raw $raw -Key "description"
    Path        = $relativePath
    LinkPath    = Get-LinkPath -RelativePath $relativePath
    RawUrl      = if ([string]::IsNullOrWhiteSpace($rawBaseUrl)) { "" } else { "$rawBaseUrl/$(Get-LinkPath -RelativePath $relativePath)" }
    MainFolder  = $mainFolder
    UsedFallback = $usedFallback
  }

  $themes.Add($theme)
}

$readmeLines = [System.Collections.Generic.List[string]]::new()
$sortedThemes = $themes | Sort-Object Author, Name
$authorGroups = $sortedThemes | Group-Object Author
$fallbackFolders = @($fallbackByFolder.Values | Sort-Object Folder)

$readmeLines.Add("# discord-themes")
$readmeLines.Add("")
$readmeLines.Add("## Themes")
$readmeLines.Add("")
$readmeLines.Add("| Theme | Author | Version | Description | Raw URL/Online Theme URL |")
$readmeLines.Add("| --- | --- | --- | --- | --- |")

foreach ($theme in $sortedThemes) {
  $themeName = Escape-TableCell -Value $theme.Name
  $themeAuthor = Escape-TableCell -Value $theme.Author
  $themeVersion = Escape-TableCell -Value $theme.Version
  $themeDescription = Escape-TableCell -Value $theme.Description
  $rawLink = if ([string]::IsNullOrWhiteSpace($theme.RawUrl)) { "-" } else { "[Raw URL]($($theme.RawUrl))" }
  $localLink = "[Online Theme URL]($($theme.LinkPath))"
  $combinedLinks = "$rawLink / $localLink"

  $readmeLines.Add("| $themeName | $themeAuthor | $themeVersion | $themeDescription | $combinedLinks |")
}

$readmeLines.Add("")
$readmeLines.Add("## Authors")

foreach ($group in $authorGroups) {
  $author = if ([string]::IsNullOrWhiteSpace($group.Name)) { "Unknown" } else { $group.Name }
  $readmeLines.Add("")
  $readmeLines.Add("### $author")
  $readmeLines.Add("")
  $readmeLines.Add("| Theme | Version | Description | Raw URL/Online Theme URL |")
  $readmeLines.Add("| --- | --- | --- | --- |")

  $groupThemes = @($group.Group | Sort-Object Name)
  foreach ($theme in $groupThemes) {
    $themeName = Escape-TableCell -Value $theme.Name
    $themeVersion = Escape-TableCell -Value $theme.Version
    $themeDescription = Escape-TableCell -Value $theme.Description
    $rawLink = if ([string]::IsNullOrWhiteSpace($theme.RawUrl)) { "-" } else { "[Raw URL]($($theme.RawUrl))" }
    $localLink = "[Online Theme URL]($($theme.LinkPath))"
    $combinedLinks = "$rawLink / $localLink"

    $readmeLines.Add("| $themeName | $themeVersion | $themeDescription | $combinedLinks |")
  }

  $readmeLines.Add("")
  $readmeLines.Add("Total themes: $($groupThemes.Count)")
}

$readmeLines.Add("")
$readmeLines.Add("## Missing Folder Mappings")
$readmeLines.Add("")

if ($fallbackFolders.Count -eq 0) {
  $readmeLines.Add("None. All folders resolved authors from theme-authors.json.")
} else {
  $readmeLines.Add("| Folder | Fallback Author | Reason |")
  $readmeLines.Add("| --- | --- | --- |")

  foreach ($entry in $fallbackFolders) {
    $folder = Escape-TableCell -Value $entry.Folder
    $fallbackAuthor = Escape-TableCell -Value $entry.FallbackAuthor
    $reason = Escape-TableCell -Value $entry.Reason

    $readmeLines.Add("| $folder | $fallbackAuthor | $reason |")
  }
}

$content = ($readmeLines -join [Environment]::NewLine)
Set-Content -LiteralPath $outputFile -Value $content -Encoding utf8

Write-Output "README generated at $outputFile"
Write-Output "CSS files processed: $($themes.Count)"
Write-Output "Metadata file: $($authorMetadata.Path)"
Write-Output "Folders using fallback author resolution: $($fallbackFolders.Count)"
