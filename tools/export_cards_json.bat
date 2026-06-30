@echo off
setlocal

set "PROJECT_DIR=%~dp0.."
set "GODOT=%GODOT_EXE%"
if "%GODOT%"=="" set "GODOT=godot"

set "OUT=%~1"
if "%OUT%"=="" set "OUT=%PROJECT_DIR%\exports\cards.json"

set "CATEGORY=%~2"
if "%CATEGORY%"=="" set "CATEGORY=all"

pushd "%PROJECT_DIR%"
"%GODOT%" --headless --path "%PROJECT_DIR%" "tools/export_cards_json.tscn" -- --output "%OUT%" --category %CATEGORY%
set "ERR=%ERRORLEVEL%"
popd
exit /b %ERR%
