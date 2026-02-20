@echo off
:: Build (and optionally run, debug, or attach) the game.
set OUT_DIR=build\debug
if not exist %OUT_DIR% mkdir %OUT_DIR%
odin build src\main -debug -subsystem:console -extra-linker-flags:"-DEFAULTLIB:ucrt.lib -DEFAULTLIB:msvcrt.lib -NODEFAULTLIB:libucrt.lib -NODEFAULTLIB:libcmt.lib" -out:%OUT_DIR%\axiomo_debug.exe
::odin build src\main -debug -subsystem:windows -extra-linker-flags:"-DEFAULTLIB:ucrt.lib -DEFAULTLIB:msvcrt.lib -NODEFAULTLIB:libucrt.lib -NODEFAULTLIB:libcmt.lib" -out:%OUT_DIR%\axiomo_debug.exe
build\rcedit-x64.exe %OUT_DIR%\axiomo_debug.exe --set-icon assets/bird.ico
IF %ERRORLEVEL% NEQ 0 exit /b 1
xcopy /y /e /i assets %OUT_DIR%\assets > nul
IF %ERRORLEVEL% NEQ 0 exit /b 1
echo Debug build created in %OUT_DIR%

:: ---- Copy Embree and TBB DLLs only if missing from debug folder ----
:: The script will use the EMBREE_DIR environment variable if present.
:: Otherwise it will use the directory containing this script (project root).
set "EMBREE_DLLS=embree4.dll tbbmalloc.dll tbb12.dll"

if defined EMBREE_DIR (
    set "EMBREE_SRC=%EMBREE_DIR%"
) else (
    :: %~dp0 is the directory of this script (ends with a backslash).
    set "EMBREE_SRC=%~dp0"
)

echo Looking for Embree DLLs in "%EMBREE_SRC%"

for %%F in (%EMBREE_DLLS%) do (
    if exist "%OUT_DIR%\%%F" (
        echo Skipping %%F — already present in %OUT_DIR%
    ) else (
        if exist "%EMBREE_SRC%%%F" (
            copy /y "%EMBREE_SRC%%%F" "%OUT_DIR%\" > nul
            if errorlevel 1 (
                echo Error: failed to copy %%F from "%EMBREE_SRC%" to "%OUT_DIR%"
                exit /b 1
            ) else (
                echo Copied %%F to %OUT_DIR%
            )
        ) else (
            echo Warning: %%F not found in "%EMBREE_SRC%"
        )
    )
)
:: ---- End Embree copy block ----

if "%~1"=="" (
    echo Usage: %~nx0 [run^|rad^|attach]
    exit /b 0
)
:: ---- New: Zed-friendly run mode ----
if "%~1"=="run_zed" (
    echo [Zed] Starting debug build in current terminal...
    pushd %OUT_DIR%
    axiomo_debug.exe
    popd
    echo [Zed] Debug session ended. Press any key to close...
    pause >nul
    exit /b 0
)

if "%~1"=="run" (
    echo Running axiomo_debug.exe...
    pushd %OUT_DIR%
    start "" axiomo_debug.exe
    popd
    exit /b 0
)

set "RADDBG=c:dev/raddbg/raddbg.exe"

if "%~1"=="rad" (
    echo Launching new RAD Debugger session for axiomo_reload.exe...
    "c:/dev/raddbg/raddbg.exe" "%OUT_DIR%\axiomo_debug.exe"
    popd
    exit /b 0
)

if "%~1"=="rad_console" (
    echo Building debug with console subsystem for RAD output...
    odin build src\main -debug -subsystem:console -extra-linker-flags:"-DEFAULTLIB:ucrt.lib -DEFAULTLIB:msvcrt.lib -NODEFAULTLIB:libucrt.lib -NODEFAULTLIB:libcmt.lib" -out:%OUT_DIR%\axiomo_debug_console.exe
    :: Copy assets, dlls, etc. same as before...
    echo Launching RAD Debugger with console-enabled exe...
    "%RADDBG%" "%OUT_DIR%\axiomo_debug_console.exe"
    exit /b 0
)