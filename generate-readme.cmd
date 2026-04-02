@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\generate-readme.ps1" %*
