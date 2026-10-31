@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0lark_pack_export.ps1" %*
exit /b %ERRORLEVEL%
