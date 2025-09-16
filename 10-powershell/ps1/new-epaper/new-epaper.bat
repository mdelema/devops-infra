@echo off
ECHO Running ePaper Processing Script...
powershell -ExecutionPolicy Bypass -File "E:\Satelites\pdfs-unicos\procesar-PDFs.ps1"
IF %ERRORLEVEL% NEQ 0 (
    ECHO Error: PowerShell script failed with exit code %ERRORLEVEL%
    EXIT /B %ERRORLEVEL%
)
ECHO PowerShell script completed successfully.
EXIT /B 0