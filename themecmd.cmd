@echo off
setlocal

set "subcmd=%~1"

if "%subcmd%"=="" goto run_generate
if /I "%subcmd%"=="generatereadme" goto run_generate_with_shift
if /I "%subcmd%"=="png-url" goto run_png_url
if /I "%subcmd%"=="help" goto show_help
if /I "%subcmd%"=="-h" goto show_help
if /I "%subcmd%"=="--help" goto show_help

echo Unknown command: %subcmd%
goto show_help

:run_generate_with_shift
if "%~2"=="" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\generate-readme.ps1"
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\generate-readme.ps1" %2 %3 %4 %5 %6 %7 %8 %9
)
exit /b %errorlevel%

:run_generate
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\generate-readme.ps1"
exit /b %errorlevel%

:run_png_url
if "%~2"=="" (
  echo Usage: themecmd.cmd png-url "path\\to\\image.png"
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\generate-readme.ps1" -PredictPngRawUrl "%~2"
exit /b %errorlevel%

:show_help
echo themecmd usage:
echo   themecmd.cmd generatereadme [options]
echo   themecmd.cmd png-url "path\\to\\image.png"
echo.
echo Examples:
echo   themecmd.cmd generatereadme
echo   themecmd.cmd generatereadme -NoAuthorPrompt
echo   themecmd.cmd png-url "Silver Themes\\Legoshi\\legoshi.png"
exit /b 1
