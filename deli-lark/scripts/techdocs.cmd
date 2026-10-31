@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0deli_techdocs.ps1" %*
exit /b %ERRORLEVEL%
