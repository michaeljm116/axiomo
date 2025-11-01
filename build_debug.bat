@echo off

:: This creates a build that is similar to a release build, but it's debuggable.
:: There is no hot reloading and no separate game library.
:: add these in teh future -strict-style -vet
set OUT_DIR=build\debug

if not exist %OUT_DIR% mkdir %OUT_DIR%

odin build src\main_release -debug -subsystem:windows -out:%OUT_DIR%\axiomo_debug.exe
rcedit-x64.exe %OUT_DIR%\axiomo_debug.exe --set-icon assets/bird.ico
IF %ERRORLEVEL% NEQ 0 exit /b 1

xcopy /y /e /i assets %OUT_DIR%\assets > nul
IF %ERRORLEVEL% NEQ 0 exit /b 1

echo Debug build created in %OUT_DIR%