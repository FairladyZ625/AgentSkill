@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0lark_doc_grab.ps1" %*
exit /b %ERRORLEVEL%
