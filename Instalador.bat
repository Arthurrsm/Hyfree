@echo off
set "params=%*"
cd /d "%~dp0"

:: Verifica se é admin, se não for, pede elevação passando o caminho correto
fltmc >nul 2>&1 || (
    powershell -Command "Start-Process -FilePath '%0' -Verb RunAs"
    exit /b
)

:: Executa o PowerShell garantindo que ele encontre o script na mesma pasta
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
pause