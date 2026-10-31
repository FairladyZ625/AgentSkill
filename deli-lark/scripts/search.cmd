@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0deli_search.ps1" %*
exit /b %ERRORLEVEL%
