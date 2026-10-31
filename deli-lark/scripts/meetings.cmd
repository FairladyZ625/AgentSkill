@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0lark_meeting_sync.ps1" %*
exit /b %ERRORLEVEL%
