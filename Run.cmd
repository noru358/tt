@echo off
if defined GODOT_BIN (
  start "Gate 1" "%GODOT_BIN%" --path "%~dp0."
  exit /b
)
where godot.exe >nul 2>nul
if not errorlevel 1 (
  start "Gate 1" godot.exe --path "%~dp0."
  exit /b
)
echo Set GODOT_BIN to your Godot 4.6 executable, or open project.godot in Godot 4.6.
pause
