@echo off
rem Connects Roblox Studio to this folder with Rojo.
rem   1. Double-click this file (leave the window open while you work).
rem   2. In Studio: Plugins tab > Rojo > Connect.
rem Edits to the files here are sent to Studio live. Scripts are owned by the files:
rem edit them here (or let Claude edit them), not inside Studio.
cd /d "%~dp0"
echo Starting Rojo for isle-roblox...
echo In Studio: Plugins tab ^> Rojo ^> Connect   (localhost : 34872)
echo Leave this window open while you work. Close it to stop syncing.
echo.
"%~dp0.tools\rojo.exe" serve default.project.json
pause
