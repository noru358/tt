@echo off
setlocal
cd /d "%~dp0"
if not defined GODOT_EXE if defined GODOT_BIN set "GODOT_EXE=%GODOT_BIN%"
if not defined GODOT_EXE set "GODOT_EXE=godot"
if exist ".godot\global_script_class_cache.cfg" goto launch
"%GODOT_EXE%" --headless --editor --import --quit --path "%CD%"
if errorlevel 1 exit /b 1
:launch
"%GODOT_EXE%" --path "%CD%" %*
