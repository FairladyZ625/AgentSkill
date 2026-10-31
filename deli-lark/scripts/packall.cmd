@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0deli_packall.ps1" %*
exit /b %ERRORLEVEL%
