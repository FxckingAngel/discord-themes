# themecmd quick guide

## What it does
`themecmd.cmd` is a CMD wrapper for `scripts/generate-readme.ps1`.
It helps you:
- generate `README.md` from theme metadata
- run a health check (`doctor`) for theme folders and headers
- build a GitHub raw URL for a PNG in this repo (`png-url`)

The wrapper prefers `pwsh` when available and falls back to `powershell`.

## Quick commands
Run from repo root:

```bat
themecmd.cmd
themecmd.cmd -NoAuthorPrompt
themecmd.cmd generatereadme -NoAuthorPrompt
themecmd.cmd generatereadme -OutputPath "README.md" -MetadataPath "theme-authors.json"
themecmd.cmd doctor
themecmd.cmd doctor -MetadataPath "theme-authors.json"
themecmd.cmd png-url "Silver Themes\Legoshi\legoshi.png"
themecmd.cmd help
```

## Command reference
`themecmd.cmd [generatereadme] [options]`
- default action
- forwards options to `generate-readme.ps1`
- examples: `-NoAuthorPrompt`, `-OutputPath`, `-MetadataPath`

`themecmd.cmd doctor [options]`
- runs `generate-readme.ps1 -Doctor`
- checks theme roots, css headers, and folder mappings
- prints `PASS`, `WARN`, or `FAIL`

`themecmd.cmd png-url "path\to\image.png"`
- returns a `raw.githubusercontent.com` URL
- path must be inside this repo

`themecmd.cmd help`
- prints usage and examples

## Exit codes
- `0` success
- `1` failure or invalid command/usage

## How option forwarding works
- if no subcommand is provided, it runs `generatereadme`
- if first arg starts with `-`, it is treated as `generatereadme` options
- unknown commands print help and return exit code `1`

## Common issues
`Error: Path must be inside the repo root.`
- use a path relative to this repo
- example: `"Silver Themes\Legoshi\legoshi.png"`

`Unknown command: ...`
- run `themecmd.cmd help` for valid commands

`Doctor status: WARN`
- usually means missing `@name`, `@author`, `@version`, or `@description`
- or folder mapping drift in `theme-authors.json`
