# ==== Configuración FTP ====
$ftpServer = "172.29.0.164"
$ftpUser = "publicadortareas"
$ftpPass = "u5nfg98"
$ftpBasePath = "/printed-home"
$ftpFolder = Get-Date -Format "yyyyMMdd"
$ftpFullPath = "$ftpBasePath/$ftpFolder"

# Carpeta temporal local que se va a subir
$tempDir = "E:\Satelites\portada-impresa\temp"

# Carpeta de respaldo
$tempBakDir = "E:\Satelites\portada-impresa\temp-bak"

# Archivo de log
$logFile = "E:\Satelites\portada-impresa\ftp_upload_log.txt"

# Función para escribir logs
function Log {
    param([string]$message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $fullMessage = "$timestamp - $message"
    Write-Host $fullMessage
    $fullMessage | Out-File -FilePath $logFile -Append -Encoding UTF8
}

# Función para crear directorio en FTP
function Create-FtpDirectory {
    param ([string]$ftpDir)
    $uri = "ftp://$ftpServer$ftpDir/"
    try {
        $ftpRequest = [System.Net.FtpWebRequest]::Create($uri)
        $ftpRequest.Method = [System.Net.WebRequestMethods+Ftp]::MakeDirectory
        $ftpRequest.Credentials = New-Object System.Net.NetworkCredential($ftpUser, $ftpPass)
        $ftpRequest.UsePassive = $true
        $ftpRequest.UseBinary = $true
        $ftpRequest.KeepAlive = $false
        $response = $ftpRequest.GetResponse()
        $response.Close()
        Log "[INFO] Carpeta FTP creada: $ftpDir"
    } catch {
        if ($_.Exception.Message -match "550") {
            Log "[INFO] Carpeta FTP ya existe: $ftpDir"
        } else {
            Log "[ERROR] No se pudo crear carpeta FTP: $ftpDir - $_"
        }
    }
}

# Función para subir archivo a FTP
function Upload-FtpFile {
    param ([string]$localFilePath, [string]$remoteFileName)
    try {
        $uri = "ftp://$ftpServer$ftpFullPath/$remoteFileName"
        $ftpRequest = [System.Net.FtpWebRequest]::Create($uri)
        $ftpRequest.Method = [System.Net.WebRequestMethods+Ftp]::UploadFile
        $ftpRequest.Credentials = New-Object System.Net.NetworkCredential($ftpUser, $ftpPass)
        $ftpRequest.UsePassive = $true
        $ftpRequest.UseBinary = $true
        $ftpRequest.KeepAlive = $false

        $fileContent = [System.IO.File]::ReadAllBytes($localFilePath)
        $ftpRequest.ContentLength = $fileContent.Length
        $requestStream = $ftpRequest.GetRequestStream()
        $requestStream.Write($fileContent, 0, $fileContent.Length)
        $requestStream.Close()
        $response = $ftpRequest.GetResponse()
        $response.Close()
        Log "Subido a FTP: $remoteFileName ($([math]::Round($fileContent.Length / 1KB, 2)) KB)"
    } catch {
        Log "ERROR al subir: $remoteFileName - $_"
    }
}

# === INICIO DEL PROCESO ===

# Verificar carpeta temporal
if (-not (Test-Path $tempDir)) {
    Log "ERROR: La carpeta temporal $tempDir no existe."
    exit
}

# Obtener archivos a subir
$files = Get-ChildItem -Path $tempDir -File
Log "Archivos encontrados para subir: $($files.Count)"

if ($files.Count -eq 0) {
    Log "ADVERTENCIA: No se encontraron archivos en $tempDir."
    exit
}

# Crear carpeta en FTP y Subir archivos
Create-FtpDirectory -ftpDir $ftpFullPath
foreach ($file in $files) {
    Upload-FtpFile -localFilePath $file.FullName -remoteFileName $file.Name
}

# Crea la carpeta de backups con cada día: "\temp-bak\todayFolder"
$backupDayDir = Join-Path -Path $tempBakDir -ChildPath $todayFolder

if (-not (Test-Path $backupDayDir)) {
    try {
        New-Item -Path $backupDayDir -ItemType Directory -Force | Out-Null
        Write-Log "[INFO] Carpeta de backup creada: $backupDayDir"
    } catch {
        Write-Log "ERROR al crear carpeta de backup: $_"
        exit
    }
}


# Mover archivos a backup
foreach ($file in $files) {
    $sourcePath = $file.FullName
    $destPath = Join-Path -Path $backupDayDir -ChildPath $file.Name

    if (Test-Path $sourcePath) {
        try {
            Move-Item -Path $sourcePath -Destination $destPath -Force
            Write-Log "Archivo movido a backup: $($file.Name)"
        } catch {
            Write-Log "ERROR al copiar archivo $($file.Name) a backup: $_"
        }
    } else {
        Write-Log "El archivo ya no existe: $sourcePath"
    }
}

Write-Log "Proceso completo: subida + backup terminado."
Write-Log "----- FINAL DEL PROCESO -----"