@echo off
cd /d "%~dp0"
if not defined GODOT_EXE set "GODOT_EXE=godot"
"%GODOT_EXE%" --path "%CD%" res://toys/movement/movement_toy.tscn
