@echo off
:: -------------------------------------
:: Ejecutar ren_economia.ps1 desde BAT
:: -------------------------------------

:: Ruta del script PowerShell
set "PS_SCRIPT=E:\Satelites\renombre-economia\ren_economia.ps1"

:: Ejecutar el script con PowerShell, sin restricciones y sin perfil de usuario
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%"

exit /b
