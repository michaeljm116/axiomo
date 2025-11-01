:: This script creates an optimized release build.
:: add these in the future -strict-style -vet -no-bounds-check -o:speed -subsystem:windows
@echo off

set OUT_DIR=build\release

if not exist %OUT_DIR% mkdir %OUT_DIR%

odin build src\main_release -no-bounds-check -o:speed -subsystem:windows -out:%OUT_DIR%\beekillingsinn.exe
IF %ERRORLEVEL% NEQ 0 exit /b 1

xcopy /y /e /i assets %OUT_DIR%\assets > nul
IF %ERRORLEVEL% NEQ 0 exit /b 1

echo Release build created in %OUT_DIR%