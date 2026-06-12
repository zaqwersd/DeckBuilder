@echo off
setlocal

set "PROJECT_DIR=%~dp0.."
set "GODOT=%GODOT_EXE%"
if "%GODOT%"=="" set "GODOT=godot"

if "%~1"=="" (
  echo Usage: export_card_compendium.bat ^<blade^|common^> [output.png]
  exit /b 1
)

set "CATEGORY=%~1"
set "OUT=%~2"
if "%OUT%"=="" set "OUT=%PROJECT_DIR%\exports\card_compendium_%CATEGORY%.png"

pushd "%PROJECT_DIR%"
"%GODOT%" --display-driver windows --rendering-driver opengl3 --rendering-method gl_compatibility --resolution 64x64 "tools/export_card_compendium.tscn" -- --category %CATEGORY% --output "%OUT%"
set "ERR=%ERRORLEVEL%"
popd
exit /b %ERR%
exit /b %ERRORLEVEL%
