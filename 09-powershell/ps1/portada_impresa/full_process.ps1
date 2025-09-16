# Bandera para indicar si se está escribiendo el correo
$script:isSendingEmail = $false

# Validar archivo de configuración
if (-not (Test-Path -Path "$PSScriptRoot\config.psd1")) {
    Write-Host "ERROR: El archivo de configuración config.psd1 no se encuentra en $PSScriptRoot"
    exit
}
try {
    $config = Import-PowerShellDataFile -Path "$PSScriptRoot\config.psd1" -ErrorAction Stop
}
catch {
    Write-Host "ERROR: No se pudo cargar el archivo de configuración - $($_.Exception.Message)"
    exit
}

# Validar variables de configuración
$requiredConfig = @('sourcePath', 'destinationPath', 'backupPath', 'logFile', 'dailyLog', 'ftpServer', 'ftpUser', 'ftpPass', 'ftpBasePath', 'magickPath', 'smtpServer', 'emailFrom', 'emailTo')
foreach ($key in $requiredConfig) {
    if (-not $config.ContainsKey($key) -or [string]::IsNullOrEmpty($config.$key)) {
        Write-Host "ERROR: La clave de configuración '$key' no está definida o está vacía en config.psd1"
        exit
    }
}

# Variables desde config
$sourcePath         = $config.sourcePath
$destinationPath    = $config.destinationPath
$backupPath         = $config.backupPath
$logFile            = $config.logFile
$dailyLogFile       = $config.dailyLog
$ftpServer          = $config.ftpServer
$ftpUser            = $config.ftpUser
$ftpPass            = $config.ftpPass
$ftpBasePath        = $config.ftpBasePath
$magickPath         = $config.magickPath
$smtpServer         = $config.smtpServer
$emailFrom          = $config.emailFrom
$emailTo            = $config.emailTo

# Fecha y prefijo del día de la semana
$today = Get-Date -Format "ddMMyy"
$todayFolder = (Get-Date).ToString("yyyy-MM-dd")
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

# Crear carpeta de backup al inicio
$backupDayDir = Join-Path -Path $backupPath -ChildPath $todayFolder
if (-not (Test-Path $backupDayDir)) {
    try {
        New-Item -Path $backupDayDir -ItemType Directory -Force | Out-Null
        Write-Host "Carpeta de backup creada: $backupDayDir"
    } catch {
        Write-Host "ERROR: No se pudo crear la carpeta de backup: $backupDayDir - $($_.Exception.Message)"
        exit
    }
}

# Definir dailyLog en la carpeta de backup
$dailyLog = Join-Path -Path $backupDayDir -ChildPath $dailyLogFile

# Crear archivo dailyLog si no existe
try {
    if (-not (Test-Path $dailyLog)) {
        New-Item -Path $dailyLog -ItemType File -Force | Out-Null
        Write-Host "Archivo de log diario creado: $dailyLog"
    }
} catch {
    Write-Host "ERROR: No se pudo crear el archivo de log diario $dailyLog - $($_.Exception.Message)"
    exit
}

# Verificar permisos de escritura en la carpeta de backup
try {
    $testFile = Join-Path -Path $backupDayDir -ChildPath "test_permissions.txt"
    [System.IO.File]::WriteAllText($testFile, "Test")
    Remove-Item -Path $testFile -Force -Confirm:$false
} catch {
    Write-Host "ERROR: No se tienen permisos de escritura en $backupDayDir - $($_.Exception.Message)"
    exit
}

# Variable para rastrear el estado del proceso
$processSuccessful = $true

# Crear directorio destino si no existe
if (-not (Test-Path $destinationPath)) {
    New-Item -Path $destinationPath -ItemType Directory | Out-Null
}

# Función para escribir en el log
function Write-DualLog {
    param ([string]$message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $fullMessage = "$timestamp - $message"
    Write-Host $fullMessage
    try {
        Add-Content -Path $logFile -Value $fullMessage -Encoding UTF8 -ErrorAction Stop
    } catch {
        Write-Host "ERROR: No se pudo escribir en el log completo $logFile - $($_.Exception.Message)"
        $script:processSuccessful = $false
    }
    if (-not $script:isSendingEmail) {
        try {
            Add-Content -Path $dailyLog -Value $fullMessage -Encoding UTF8 -ErrorAction Stop
        } catch {
            Write-Host "ERROR: No se pudo escribir en el log diario $dailyLog - $($_.Exception.Message)"
            Add-Content -Path $logFile -Value "ERROR: No se pudo escribir en el log diario $dailyLog - $($_.Exception.Message)" -Encoding UTF8
            $script:processSuccessful = $false
        }
    }
}

# Función para enviar notificación por correo
function Send-NotificationEmail {
    param ([bool]$success, [string]$backupDir)
    $script:isSendingEmail = $true
    $smtpClient = New-Object System.Net.Mail.SmtpClient
    $smtpClient.Host = $smtpServer
    $mailMessage = New-Object System.Net.Mail.MailMessage
    $mailMessage.From = $emailFrom
    $mailMessage.To.Add($emailTo)
    $mailMessage.Subject = if ($success) { "Portada Impresa - [EXITOSO]" } else { "Portada Impresa - [FALLO]" }
    $mailMessage.Body = @"
    Ejecucion del dia:  $(Get-Date -Format 'dd-MM-yyyy HH:mm')
    Proceso:    Portada_Impresa
    Estado:     $(if ($success) { "Exitoso - Buen trabajo" } else { "Fallido - Por favor, revisar" })

    Detalles:   Ver LOG adjunto para mas informacion.
"@

    # Adjuntar solo el archivo daily_log.txt
    $attachments = @()
    if (Test-Path $backupDir) {
        $logFilePath = Join-Path -Path $backupDir -ChildPath $config.dailyLog
        if (Test-Path $logFilePath) {
            try {
                $attachment = New-Object System.Net.Mail.Attachment($logFilePath)
                $mailMessage.Attachments.Add($attachment)
                $attachments += $attachment
                Write-DualLog "Adjuntando archivo daily_log.txt al correo "
            } catch {
                Write-DualLog "ERROR al adjuntar archivo daily_log.txt: $($_.Exception.Message)"
                $script:processSuccessful = $false
            }
        } else {
            Write-DualLog "ADVERTENCIA: No se encontró el archivo de log diario $logFilePath para adjuntar."
            $script:processSuccessful = $false
        }
    } else {
        Write-DualLog "ADVERTENCIA: No se encontró la carpeta de backup $backupDir."
        $script:processSuccessful = $false
    }

    try {
        $smtpClient.Send($mailMessage)
        Write-DualLog "Correo enviado correctamente a $emailTo"
    } catch {
        Write-DualLog "ERROR al enviar correo: $($_.Exception.Message)"
        $script:processSuccessful = $false
    } finally {
        foreach ($attachment in $attachments) {
            $attachment.Dispose()
        }
        $mailMessage.Dispose()
        $script:isSendingEmail = $false
    }
}

# Inicio proceso
Write-DualLog "----- INICIO DEL PROCESO -----"
Write-DualLog "Buscando archivos en $sourcePath"

# Buscar archivos PDF que coincidan con los patrones
$files = Get-ChildItem -Path $sourcePath -File -Filter "*.pdf" | Where-Object {
    $_.Name -match "^($todayPrefix.*__(0110A|0112A|0116A|0124A).*$today\.pdf|Ova_$today.*__0112_.*$today\.pdf)$"
}

if ($files.Count -eq 0) {
    Write-DualLog "No se encontraron archivos que coincidan con los patrones."
    Write-DualLog "----- FIN DEL PROCESO (Sin archivos) -----"
    Send-NotificationEmail -success $false -backupDir $backupDayDir
    exit
}

# Copiar archivos al destino
foreach ($file in $files) {
    Write-DualLog "Copiando archivo: $($file.Name)"
    try {
        Copy-Item -Path $file.FullName -Destination $destinationPath -Force -ErrorAction Stop
    } catch {
        Write-DualLog "ERROR al copiar archivo $($file.Name): $($_.Exception.Message)"
        $processSuccessful = $false
    }
}

# Renombrar archivos en el destino
$matchingFiles = Get-ChildItem -Path $destinationPath -Filter "*.pdf" | Where-Object {
    $_.Name -in @("portada_impresa.pdf", "portada_impresaova.pdf")
}
if ($matchingFiles.Count -gt 0) {
    Write-DualLog "ADVERTENCIA: Se encontraron archivos con nombres de destino ($($matchingFiles.Name -join ', ')). Se sobrescribirán."
}

Get-ChildItem -Path $destinationPath -Filter "*.pdf" | ForEach-Object {
    $newName = ""
    if ($_.Name -match "^$todayPrefix.*__(0110A|0112A|0116A|0124A).*$today\.pdf$") {
        $newName = "portada_impresa.pdf"
    }
    elseif ($_.Name -match "^Ova_$today.*__0112_.*$today\.pdf$") {
        $newName = "portada_impresaova.pdf"
    }

    if ($newName -ne "") {
        $destinationFile = Join-Path -Path $destinationPath -ChildPath $newName
        if (Test-Path $destinationFile -PathType Leaf) {
            Write-DualLog "Eliminando archivo existente: $destinationFile"
            try {
                Remove-Item -Path $destinationFile -Force -Confirm:$false -ErrorAction Stop
            } catch {
                Write-DualLog "ERROR al eliminar archivo existente $destinationFile : $($_.Exception.Message)"
                $script:processSuccessful = $false
            }
        } elseif (Test-Path $destinationFile) {
            Write-DualLog "ERROR: $destinationFile no es un archivo válido, es una carpeta."
            $script:processSuccessful = $false
            continue
        }
        Write-DualLog "Renombrando $($_.Name) a $newName"
        try {
            Rename-Item -Path $_.FullName -NewName $newName -Force -ErrorAction Stop
        } catch {
            Write-DualLog "ERROR al renombrar $($_.Name): $($_.Exception.Message)"
            $script:processSuccessful = $false
        }
    }
}

Write-DualLog "Archivos renombrados correctamente. Iniciando conversion a JPG..."

# Validación del ejecutable magick.exe
if (-not (Test-Path $magickPath)) {
    Write-DualLog "ERROR: El ejecutable de ImageMagick no se encuentra en $magickPath"
    $processSuccessful = $false
    Send-NotificationEmail -success $false -backupDir $backupDayDir
    exit
}

# Convertir PDFs a JPG
$pdfFiles = Get-ChildItem -Path $destinationPath -Filter "*.pdf"
foreach ($pdf in $pdfFiles) {
    $inputPdfPath = $pdf.FullName
    $outputJpgPath = Join-Path $destinationPath ($pdf.BaseName + ".jpg")
    Write-DualLog "Copiando de $($pdf.Name) a $($pdf.BaseName).jpg"
    try {
        & "$magickPath" -density 150 "$inputPdfPath" -background white -alpha remove -alpha off -colorspace sRGB -quality 100 "$outputJpgPath"
    } catch {
        Write-DualLog "ERROR al convertir $inputPdfPath - $($_.Exception.Message)"
        $processSuccessful = $false
        continue
    }
}

Start-Sleep -Seconds 2

# ========= INICIO PROCESO FTP ========= #

$ftpFolder = Get-Date -Format "yyyyMMdd"
$ftpFullPath = "$ftpBasePath/$ftpFolder"

# Función para crear directorio en FTP
function Create-FtpDirectory {
    param ([string]$ftpDir)
    try {
        $testUri = "ftp://$ftpServer/"
        $testRequest = [System.Net.FtpWebRequest]::Create($testUri)
        $testRequest.Method = [System.Net.WebRequestMethods+Ftp]::ListDirectory
        $testRequest.Credentials = New-Object System.Net.NetworkCredential($ftpUser, $ftpPass)
        $testRequest.UsePassive = $true
        $testRequest.UseBinary = $true
        $testRequest.KeepAlive = $false
        $response = $testRequest.GetResponse()
        $response.Close()
    } catch {
        Write-DualLog "ERROR: No se pudo conectar al servidor FTP $ftpServer - $($_.Exception.Message)"
        $script:processSuccessful = $false
        Send-NotificationEmail -success $false -backupDir $backupDayDir
        exit
    }
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
        Write-DualLog "[INFO] Carpeta FTP creada: $ftpDir"
    } catch {
        if ($_.Exception.Message -match "550") {
            Write-DualLog "[INFO] Carpeta FTP ya existe: $ftpDir"
        } else {
            Write-DualLog "ERROR al crear carpeta FTP: $ftpDir - $($_.Exception.Message)"
            $script:processSuccessful = $false
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
        Write-DualLog "Subido a FTP: $remoteFileName ($([math]::Round($fileContent.Length / 1KB, 2)) KB)"
    } catch {
        Write-DualLog "ERROR al subir: $remoteFileName - $($_.Exception.Message)"
        $script:processSuccessful = $false
    }
}

# Verificar carpeta temporal
if (-not (Test-Path $destinationPath)) {
    Write-DualLog "ERROR: La carpeta temporal $destinationPath no existe."
    $processSuccessful = $false
    Send-NotificationEmail -success $false -backupDir $backupDayDir
    exit
}

# Obtener archivos a subir (excluyendo daily_log.txt)
$files = Get-ChildItem -Path $destinationPath -File | Where-Object { $_.Name -ne $config.dailyLog }
Write-DualLog "Archivos encontrados para subir: $($files.Count)"

if ($files.Count -eq 0) {
    Write-DualLog "ADVERTENCIA: No se encontraron archivos en $destinationPath."
    $processSuccessful = $false
    Send-NotificationEmail -success $false -backupDir $backupDayDir
    exit
}

# Crear carpeta en FTP y Subir archivos
Create-FtpDirectory -ftpDir $ftpFullPath
foreach ($file in $files) {
    Upload-FtpFile -localFilePath $file.FullName -remoteFileName $file.Name
}

# Mover archivos a backup
foreach ($file in $files) {
    $sourceFilePath = $file.FullName
    $destPath = Join-Path -Path $backupDayDir -ChildPath $file.Name
    if (Test-Path $sourceFilePath) {
        try {
            Move-Item -Path $sourceFilePath -Destination $destPath -Force -ErrorAction Stop
        } catch {
            Write-DualLog "ERROR al mover archivo $($file.Name) a backup: $($_.Exception.Message)"
            $processSuccessful = $false
        }
    } else {
        Write-DualLog "El archivo ya no existe: $sourceFilePath"
        $processSuccessful = $false
    }
}

Write-DualLog "Se mueven los $($files.Count) archivos a $backupDayDir"

# Enviar notificación por correo
Write-DualLog "Enviando notificacion por correo"
Write-DualLog "Proceso completo: envio por FTP + backup + notificacion por correo."
Write-DualLog "----- FINAL DEL PROCESO -----"
Send-NotificationEmail -success $processSuccessful -backupDir $backupDayDir

# Mensajes finales del log
Write-DualLog "----- FINAL DEL PROCESO -----"

# Limpieza opcional del backup antiguo
Get-ChildItem -Path $backupPath -Directory | Where-Object {
    $_.LastWriteTime -lt (Get-Date).AddDays(-30)
} | ForEach-Object {
    try {
        Remove-Item -Path $_.FullName -Recurse -Force -Confirm:$false -ErrorAction Stop
        Write-DualLog "[INFO] Carpeta de backup eliminada por antigüedad: $($_.Name)"
    } catch {
        Write-DualLog "ERROR al eliminar carpeta de backup $($_.Name): $($_.Exception.Message)"
    }
}