@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0lark_wiki_sync.ps1" %*
exit /b %ERRORLEVEL%
