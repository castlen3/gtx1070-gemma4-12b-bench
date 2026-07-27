@echo off
setlocal

REM Gemma 4 12B Q4_K_M on GTX 1070 8GB
REM Edit only the two paths below for a new machine.

set "LLAMA_DIR=C:\llama.cpp"
set "MODEL=D:\models\gemma-4-12B-it-Q4_K_M.gguf"

REM Default: stable / long-context profile
set "NGL=40"
set "UBATCH=256"
set "CTX=32768"
set "PORT=8081"

REM For short prompts / slightly faster decode, try:
REM set "NGL=42"
REM set "UBATCH=64"

set "SERVER=%LLAMA_DIR%\llama-server.exe"

if not exist "%SERVER%" (
    echo [FAIL] llama-server.exe not found:
    echo        %SERVER%
    echo Edit LLAMA_DIR at the top of this file.
    pause
    exit /b 1
)

if not exist "%MODEL%" (
    echo [FAIL] Model not found:
    echo        %MODEL%
    echo Edit MODEL at the top of this file.
    pause
    exit /b 1
)

echo Checking port %PORT%...
netstat -ano | findstr ":%PORT% " >nul
if %errorlevel% equ 0 (
    echo [FAIL] Port %PORT% is already in use.
    pause
    exit /b 1
)

echo.
echo GTX 1070 Gemma 4 12B profile
echo ----------------------------------------
echo Model : %MODEL%
echo Context: %CTX%
echo NGL    : %NGL%
echo ubatch : %UBATCH%
echo Port   : %PORT%
echo ----------------------------------------
echo.

"%SERVER%" ^
  -m "%MODEL%" ^
  --host 0.0.0.0 ^
  --port %PORT% ^
  -c %CTX% ^
  -ngl %NGL% ^
  -fa on ^
  -ctk q8_0 ^
  -ctv q8_0 ^
  -b 512 ^
  -ub %UBATCH% ^
  --metrics

pause
endlocal
