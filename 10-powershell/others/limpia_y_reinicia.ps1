# === Manejo de logs (máximo 2 archivos) ===
$LogDir = "C:\Temp"
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir | Out-Null
}

# Listar logs existentes ordenados por fecha de creación
$Logs = Get-ChildItem -Path $LogDir -Filter "maintenance_*.log" | Sort-Object CreationTime -Descending

# Si hay más de 2, eliminar los más antiguos
if ($Logs.Count -gt 2) {
    $Logs | Select-Object -Skip 2 | Remove-Item -Force
}

# Crear nuevo log con timestamp
$LogPath = Join-Path $LogDir ("maintenance_{0}.log" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))

# Iniciar transcript
Start-Transcript -Path $LogPath -Append


# Verificar si el script se ejecuta con privilegios de administrador
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Output "NO ESTÁS COMO ADMIN"
    Write-Output "Por favor, ejecuta como Administrador para limpiar todas las ubicaciones."
    exit 
} else {
    Write-Output "Estás ejecutando como ADMIN."
}

# Eliminar archivos y carpetas en TEMP (usuario)
Write-Output "Eliminando archivos en %TEMP%..."
$TempPath = $env:TEMP
if (Test-Path $TempPath) {
    Remove-Item -Path "$TempPath\*" -Recurse -Force -ErrorAction SilentlyContinue
} else {
    Write-Output "No se encontró la carpeta TEMP del usuario."
}

# Eliminar archivos y carpetas en TEMP (Windows)
Write-Output "Eliminando archivos en C:\Windows\Temp..."
$WinTempPath = "C:\Windows\Temp"
if (Test-Path $WinTempPath) {
    Remove-Item -Path "$WinTempPath\*" -Recurse -Force -ErrorAction SilentlyContinue
} else {
    Write-Output "No se encontró la carpeta C:\Windows\Temp."
}

# Vaciar Papelera
Write-Output "Vaciando la Papelera de Reciclaje..."
try {
    Clear-RecycleBin -Force -ErrorAction Stop
    Write-Output "Papelera de Reciclaje vaciada correctamente."
} catch {
    Write-Output "Error al vaciar la Papelera: $_"
}

Write-Output "Limpieza completada"
Write-Output "Se procede a actualizar los paquetes de la PC"

# Ejecutar Winget
$WingetPath = "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe"
if (Get-Command winget -ErrorAction SilentlyContinue) {
    Write-Output "Usando winget desde el PATH..."
    winget upgrade --all --include-unknown --accept-package-agreements --accept-source-agreements
} elseif (Test-Path $WingetPath) {
    Write-Output "Usando winget desde ruta completa..."
    & $WingetPath upgrade --all --include-unknown --accept-package-agreements --accept-source-agreements
} else {
    Write-Output "No se encontró winget instalado en este equipo."
}

Write-Output "Procedemos a reiniciar la PC"

# === Cierre del log ===
Stop-Transcript

Restart-Computer -Force

# Para saber si estas administrador
# if (([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
#     Write-Output "Estás ejecutando PowerShell como Administrador."
# } else {
#     Write-Output "No estás ejecutando PowerShell como Administrador."
# }
#
# Otra opcion: Enabled (Admin) | "Disabled" (No Admin)
# whoami /priv | findstr "SeDebugPrivilege"