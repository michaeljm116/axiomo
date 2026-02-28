@echo off
:: test.bat - Runs Odin tests (single-threaded) with Box2D flags
:: Usage: test.bat [rad]  (rad opens in RAD Debugger after build)

set OUT_DIR=build\test
if not exist %OUT_DIR% mkdir %OUT_DIR%

echo ==============================================
echo Running game tests (src/test)...
echo ==============================================

odin test src/test ^
    -debug ^
    -define:ODIN_TEST_THREADS=1 ^
    -extra-linker-flags:"-DEFAULTLIB:ucrt.lib -DEFAULTLIB:msvcrt.lib -NODEFAULTLIB:libucrt.lib -NODEFAULTLIB:libcmt.lib"

IF %ERRORLEVEL% NEQ 0 (
    echo Tests FAILED!
    exit /b 1
)

echo All tests passed!

:: If you want RAD debuggable exe too, build one separately
if "%~1"=="rad" (
    echo Building debuggable test exe for RAD...
    odin build src/test ^
        -debug ^
        -define:ODIN_TEST_THREADS=1 ^
        -extra-linker-flags:"-DEFAULTLIB:ucrt.lib -DEFAULTLIB:msvcrt.lib -NODEFAULTLIB:libucrt.lib -NODEFAULTLIB:libcmt.lib" ^
        -out:%OUT_DIR%\test.exe ^
        -subsystem:console

    "c:/dev/raddbg/raddbg.exe" "%OUT_DIR%\test.exe"
)

pausexit /b 0xit /b 1