param(
    [string]$ConfigFile = ".\config.psd1"
)

# === CARGAR CONFIGURACIÓN ===
$Config = Import-PowerShellDataFile -Path $ConfigFile

# Extraer variables importantes del config
$Srv_Origen   = $Config.Srv_Origen
$Srv_Process  = $Config.Srv_Process
$PdfSharpDll  = $Config.PdfSharpDll

$logFile      = $Config.logFile
$tempDir      = $Config.tempDir
$tempBakDir   = $Config.tempBakDir

$ftpServer    = $Config.ftpServer
$ftpUser      = $Config.ftpUser
$ftpPass      = $Config.ftpPass
$ftpBasePath  = $Config.ftpBasePath

# Validaciones
if (-not (Test-Path $Srv_Origen)) { Write-Host "ERROR: Origen $Srv_Origen no existe."; exit }
if (-not (Test-Path $tempDir))     { Write-Host "ERROR: tempDir $tempDir no existe."; exit }
if (-not $ftpServer)               { Write-Host "ERROR: ftpServer no definido."; exit }
if (-not $ftpUser -or -not $ftpPass) { Write-Host "ERROR: Credenciales FTP faltantes."; exit }

# === FUNCIONES ===
function Log {
    param([string]$message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $fullMessage = "$timestamp - $message"
    Write-Host $fullMessage
    if ($logFile) {
        $fullMessage | Out-File -FilePath $logFile -Append -Encoding UTF8
    }
}

function Upload-FtpFile {
    param ([string]$localFilePath, [string]$remoteFileName)

    try {
        # Evita doble "/" si ftpBasePath está vacío
        if ($ftpBasePath -and $ftpBasePath.Trim() -ne "") {
            $uri = "ftp://$ftpServer/$ftpBasePath/$remoteFileName"
        } else {
            $uri = "ftp://$ftpServer/$remoteFileName"
        }

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

        Log "[INFO] Subido a FTP: $remoteFileName ($([math]::Round($fileContent.Length / 1KB, 2)) KB)"
    } catch {
        Log "[ERROR] Al subir: $remoteFileName - $_"
    }
}

# === CARGAR PdfSharp ===
Unblock-File -Path $PdfSharpDll -ErrorAction SilentlyContinue
Add-Type -Path $PdfSharpDll

# === PASO 1: COPIAR ARCHIVOS A Srv_Process ===
Log "Copiando archivos de $Srv_Origen a $Srv_Process ..."

$archivos = Get-ChildItem -Path $Srv_Origen | Where-Object { $_.Name -match '^Sup_\d{6}__\d{4}_\d{6}\.pdf$' }

if (-not $archivos) {
    Log "No se encontraron archivos en $Srv_Origen"
    exit
}

# Limpiar carpeta destino
Remove-Item "$Srv_Process\*" -Force -ErrorAction SilentlyContinue

foreach ($archivo in $archivos) {
    Copy-Item $archivo.FullName -Destination $Srv_Process
    Log "Copiado: $($archivo.Name)"
}

# === PASO 2: GENERAR PDF UNICO ===
Log "Generando PDF único con todos los PDFs copiados..."
$fecha = if ($archivos[0].Name -match '^Sup_(\d{6})__') { $matches[1] } else { Get-Date -Format "yyMMdd" }
$outputFile = Join-Path $tempDir "Sup_${fecha}_full.pdf"

$outputDocument = New-Object PdfSharp.Pdf.PdfDocument

foreach ($file in $archivos) {
    Log "Procesando $($file.Name)"
    try {
        $inputDocument = [PdfSharp.Pdf.IO.PdfReader]::Open($file.FullName, [PdfSharp.Pdf.IO.PdfDocumentOpenMode]::Import)
        Log "Número de páginas en $($file.Name): $($inputDocument.PageCount)"
        for ($i = 0; $i -lt $inputDocument.PageCount; $i++) {
            $outputDocument.AddPage($inputDocument.Pages[$i])
        }
    } catch {
        Log "[ERROR] Error procesando $($file.Name): $_"
        continue
    }
}

if ($outputDocument.PageCount -gt 0) {
    $outputDocument.Save($outputFile)
    Log "PDF generado: $outputFile"
} else {
    Log "No se agregaron páginas al PDF final"
}

# === PASO 3: CREAR BACKUP LOCAL ===
$todayFolder = Get-Date -Format "yyyyMMdd"
$backupDayDir = Join-Path -Path $tempBakDir -ChildPath $todayFolder

if (-not (Test-Path $backupDayDir)) { New-Item -Path $backupDayDir -ItemType Directory -Force | Out-Null }

$backupFile = Join-Path $backupDayDir (Split-Path $outputFile -Leaf)
Move-Item -Path $outputFile -Destination $backupFile -Force
Log "Archivo movido a backup: $backupFile"

# === PASO 4: SUBIR A FTP ===
Upload-FtpFile -localFilePath $backupFile -remoteFileName (Split-Path $backupFile -Leaf)

# === PASO 5: LIMPIAR CARPETA DE PROCESO ===
try {
    Remove-Item "$Srv_Process\*" -Force -ErrorAction SilentlyContinue
    Log "[INFO] Carpeta $Srv_Process limpiada correctamente."
} catch {
    Log "[ERROR] No se pudo limpiar carpeta $Srv_Process - $_"
}

# === PASO 6: ELIMINAR BACKUPS MAYORES A 30 DÍAS ===
try {
    $limitDate = (Get-Date).AddDays(-30)
    Get-ChildItem -Path $tempBakDir -Directory | Where-Object { $_.LastWriteTime -lt $limitDate } | ForEach-Object {
        Remove-Item $_.FullName -Recurse -Force
        Log "[INFO] Backup eliminado por antigüedad (>30 días): $($_.FullName)"
    }
} catch {
    Log "[ERROR] No se pudieron limpiar backups viejos - $_"
}

Log "----- FINAL DEL PROCESO -----"
