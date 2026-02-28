@echo off
:: test.bat - Run Odin tests with the same linker flags as build_debug.bat
:: Usage: test.bat [all | axiom | game | extensions]

set OUT_DIR=build\test
if not exist %OUT_DIR% mkdir %OUT_DIR%

echo ==============================================
echo Running Odin tests with Box2D-friendly flags...
echo ==============================================

:: Core game tests (src/test)
echo.
echo [1/3] Testing game code (src/test)...
odin test src\test ^
    -debug ^
    -define:ODIN_TEST_THREADS=1 ^
    -extra-linker-flags:"-DEFAULTLIB:ucrt.lib -DEFAULTLIB:msvcrt.lib -NODEFAULTLIB:libucrt.lib -NODEFAULTLIB:libcmt.lib" ^
    -out:%OUT_DIR%\game_tests.exe

IF %ERRORLEVEL% NEQ 0 (
    echo Game tests FAILED!
    exit /b 1
) else (
    echo Game tests PASSED.
)

:: Axiom engine tests (src/axiom/test)
echo.
echo [2/3] Testing Axiom engine (src/axiom/test)...
odin test src\axiom\test ^
    -debug ^
    -define:ODIN_TEST_THREADS=1 ^
    -extra-linker-flags:"-DEFAULTLIB:ucrt.lib -DEFAULTLIB:msvcrt.lib -NODEFAULTLIB:libucrt.lib -NODEFAULTLIB:libcmt.lib" ^
    -out:%OUT_DIR%\axiom_tests.exe

IF %ERRORLEVEL% NEQ 0 (
    echo Axiom tests FAILED!
    exit /b 1
) else (
    echo Axiom tests PASSED.
)

:: Extensions tests (src/axiom/extensions/tests)
echo.
echo [3/3] Testing extensions (src/axiom/extensions/tests)...
odin test src\axiom\extensions\tests ^
    -debug ^
    -define:ODIN_TEST_THREADS=1 ^
    -extra-linker-flags:"-DEFAULTLIB:ucrt.lib -DEFAULTLIB:msvcrt.lib -NODEFAULTLIB:libucrt.lib -NODEFAULTLIB:libcmt.lib" ^
    -out:%OUT_DIR%\extensions_tests.exe

IF %ERRORLEVEL% NEQ 0 (
    echo Extensions tests FAILED!
    exit /b 1
) else (
    echo Extensions tests PASSED.
)

:: Optional: copy Embree/TBB DLLs if your tests need them (rare, but safe)
echo.
echo Copying Embree/TBB DLLs if missing...
set "EMBREE_DLLS=embree4.dll tbbmalloc.dll tbb12.dll"

if defined EMBREE_DIR (
    set "EMBREE_SRC=%EMBREE_DIR%"
) else (
    set "EMBREE_SRC=%~dp0"
)

for %%F in (%EMBREE_DLLS%) do (
    if not exist "%OUT_DIR%\%%F" (
        if exist "%EMBREE_SRC%%%F" (
            copy /y "%EMBREE_SRC%%%F" "%OUT_DIR%\" > nul
            echo Copied %%F
        ) else (
            echo Warning: %%F not found in "%EMBREE_SRC%"
        )
    )
)

echo.
echo All tests complete. Check output above for PASS/FAIL.
pause
