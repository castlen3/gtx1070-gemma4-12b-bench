@echo off
REM Gemma 4 12B Q4_K_M — Performance Mode (ngl=42, ub=64)
REM decode ~11.3 tok/s, VRAM ~7788 MiB | port 0.0.0.0:8081

echo Checking port 8081...
netstat -ano | findstr ":8081 " >nul
if %errorlevel% equ 0 (
    echo [FAIL] Port 8081 is already in use. Close the other server first.
    pause
    exit /b 1
)
echo Port 8081 is free. Starting...

C:\Users\castlen3\llama.cpp\b9500-cuda124\llama-server.exe ^
  -m "F:/MODELS/lmstudio-community/gemma-4-12B-it-GGUF/gemma-4-12B-it-Q4_K_M.gguf" ^
  --host 0.0.0.0 ^
  --port 8081 ^
  -c 32768 ^
  -ngl 42 ^
  -fa on ^
  -ctk q8_0 ^
  -ctv q8_0 ^
  -b 512 ^
  -ub 64 ^
  --metrics

pause
