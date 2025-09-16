param (
    [string]$sourcePath = "\\srvfs06\MileniumPdfSuplementos\test",
    [string]$destinationPath = "E:\Satelites\portada-impresa\temp",
    [string]$logFile = "E:\Satelites\portada-impresa\process_log.txt"
)

# Fecha y prefijo del día de la semana
$today = Get-Date -Format "ddMMyy"
$dayOfWeek = switch ((Get-Date).DayOfWeek) {
    "Monday"    { "Lun_" }
    "Tuesday"   { "Mar_" }
    "Wednesday" { "Mie_" }
    "Thursday"  { "Jue_" }
    "Friday"    { "Vie_" }
    "Saturday"  { "Sab_" }
    "Sunday"    { "Dom_" }
}
$todayPrefix = "$dayOfWeek$today"

# Crear directorio destino si no existe
if (-not (Test-Path $destinationPath)) {
    New-Item -Path $destinationPath -ItemType Directory | Out-Null
}

# Función para escribir en el log
function Write-Log {
    param ([string]$message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $fullMessage = "$timestamp - $message"
    Write-Host $fullMessage
    $fullMessage | Out-File -FilePath $logFile -Append -Encoding UTF8
}

# Inicio proceso
Write-Log "----- INICIO DEL PROCESO -----"
Write-Log "Iniciando búsqueda de archivos en $sourcePath"

# Buscar archivos PDF que coincidan con los patrones
$files = Get-ChildItem -Path $sourcePath -File -Filter "*.pdf" | Where-Object {
    $_.Name -ilike "$todayPrefix*__0110A*$today.pdf" -or
    $_.Name -ilike "$todayPrefix*__0112A*$today.pdf" -or
    $_.Name -ilike "$todayPrefix*__0116A*$today.pdf" -or
    $_.Name -ilike "$todayPrefix*__0124A*$today.pdf" -or
    $_.Name -ilike "Ova_$today*__0112_$today.pdf"
}

if ($files.Count -eq 0) {
    Write-Log "No se encontraron archivos que coincidan con los patrones."
    Write-Log "----- FIN DEL PROCESO (Sin archivos) -----"
    exit
}

# Copiar archivos al destino
foreach ($file in $files) {
    Write-Log "Copiando archivo: $($file.Name)"
    Copy-Item -Path $file.FullName -Destination $destinationPath -Force
}

# Renombrar archivos en el destino
Get-ChildItem -Path $destinationPath -Filter "*.pdf" | ForEach-Object {
    $newName = ""

    # Caso 1: portada_impresa.pdf
    if (
        $_.Name -ilike "$todayPrefix*__0110A*$today.pdf" -or
        $_.Name -ilike "$todayPrefix*__0112A*$today.pdf" -or
        $_.Name -ilike "$todayPrefix*__0116A*$today.pdf" -or
        $_.Name -ilike "$todayPrefix*__0124A*$today.pdf"
    ) {
        $newName = "portada_impresa.pdf"
    }
    # Caso 2: portada_impresaova.pdf
    elseif ($_.Name -ilike "Ova_$today*__0112_*$today.pdf") {
        $newName = "portada_impresaova.pdf"
    }

    if ($newName -ne "") {
        $destinationFile = Join-Path -Path $_.DirectoryName -ChildPath $newName

        if (Test-Path $destinationFile) {
            Write-Log "Eliminando archivo existente: $destinationFile"
            Remove-Item -Path $destinationFile -Force
        }

        Write-Log "Renombrando $($_.Name) a $newName"
        Rename-Item -Path $_.FullName -NewName $newName -Force
    }
}

Write-Log "Archivos renombrados correctamente..."
Write-Log "----- FIN DEL PROCESO -----"