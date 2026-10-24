@echo off
rem Starts the A Studio build runner (see runner.ps1). Close its window to stop it.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0runner.ps1"
