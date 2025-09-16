# ==============================================
# Script: epaper_process.ps1
# Descripcion: Procesa archivos para el epaper de: Paula, Paula Casa, Tu Casa Aqui, SabadoShow y Suplementos ANP. Los sube v铆a FTP y env铆a notificaci贸n por correo
# Autor: mdelema
# Fecha de ejecuci贸n: Autom谩tica diaria
# ==============================================

# Bandera para indicar si se esta escribiendo el correo
$script:isSendingEmail = $false

# Variable para rastrear el estado global del proceso
$script:processSuccessful = $true

# La conexion FTP se prueba solo una vez
$script:ftpConnectionTested = $false

# Diccionario para rastrear el estado por proceso
$script:processStatus = @{
    "Revista-Paula"      = $true
    "Revista-Paula-Casa" = $true
    "Revista-Tu-Casa-Aqui" = $true
    "Revista-Sabado-Show" = $true
    "Suplemento-ANP"     = $true
}

# Diccionario para rastrear publicaciones procesadas
$script:processedPublications = @{
    "Revista-Paula"      = $false
    "Revista-Paula-Casa" = $false
    "Revista-Tu-Casa-Aqui" = $false
    "Revista-Sabado-Show" = $false
    "Suplemento-ANP"     = $false
}

# Cargar configuraci贸n
$configPath = Join-Path $PSScriptRoot "config.psd1"
if (-not (Test-Path $configPath -PathType Leaf)) {
    Write-Host "ERROR: No se encontr贸 el archivo de configuraci贸n en $configPath"
    exit 1
}
try {
    $config = Import-PowerShellDataFile -Path $configPath
} catch {
    Write-Host "ERROR: No se pudo cargar el archivo de configuracion desde '$configPath': $($_.Exception.Message)"
    exit 1
}

# Verificar claves necesarias
$requiredKeys = @(
    "origen", "origenPaula", "origenPaulaCasa", "origenTuCasaAqui", "origenSabadoShow", "origenSupANP",
    "processPaula", "processPaulaCasa", "processTuCasaAqui", "processSabadoShow", "processSupANP",
    "logDir", "ftpServer", "ftpUser", "ftpPass", "ftpBasePath", "ftpSubPathPaula", "ftpSubPathPaulaCasa",
    "ftpSubPathTuCasaAqui", "ftpSubPathSabadoShow", "ftpSubPathSupANP", "smtpServer", "emailFrom", "emailTo", "tempBakBase", "months"
)
foreach ($key in $requiredKeys) {
    if (-not $config.ContainsKey($key)) {
        Write-Host "ERROR: La clave '$key' no esta definida en el archivo de configuracion."
        exit 1
    }
}

# Rutas y configuraciones
$origen = $config.origen
$origenPaula = $config.origenPaula
$origenPaulaCasa = $config.origenPaulaCasa
$origenTuCasaAqui = $config.origenTuCasaAqui
$origenSabadoShow = $config.origenSabadoShow
$origenSupANP = $config.origenSupANP
$processPaula = $config.processPaula
$processPaulaCasa = $config.processPaulaCasa
$processTuCasaAqui = $config.processTuCasaAqui
$processSabadoShow = $config.processSabadoShow
$processSupANP = $config.processSupANP
$sourceApplicationCss = $config.sourceApplicationCss
$logDir = $config.logDir
$ftpServer = $config.ftpServer.TrimEnd("/")
$ftpUser = $config.ftpUser
$ftpPass = $config.ftpPass
$ftpBasePath = $config.ftpBasePath.Trim("/")
$ftpSubPathPaula = $config.ftpSubPathPaula
$ftpSubPathPaulaCasa = $config.ftpSubPathPaulaCasa
$ftpSubPathTuCasaAqui = $config.ftpSubPathTuCasaAqui
$ftpSubPathSabadoShow = $config.ftpSubPathSabadoShow
$ftpSubPathSupANP = $config.ftpSubPathSupANP
$smtpServer = $config.smtpServer
$emailFrom = $config.emailFrom
$emailTo = $config.emailTo
$tempBakBase = $config.tempBakBase
$meses = $config.months

# Crear logs
$fechaLog = Get-Date -Format "yyyyMMdd"
$dailyLogFile = Join-Path $logDir "daily_process_$fechaLog.txt"
$historicalLogFile = Join-Path $logDir "historical_process.txt"
if (!(Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }

function Write-DualLog {
    param ([string]$mensaje)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp - $mensaje"
    # Solo escribir a archivos de log si no estamos en medio del envi璷 de correo para evitar recursion
    if (-not $script:isSendingEmail) {
        Add-Content -Path $dailyLogFile -Value $logMessage -Encoding UTF8 -ErrorAction SilentlyContinue
        Add-Content -Path $historicalLogFile -Value $logMessage -Encoding UTF8 -ErrorAction SilentlyContinue
    }
    Write-Host $logMessage
}

# --- RENOMBRADO DE CARPETAS (solo las que terminan en _WEB) ---
$carpetasPadreExcluidas = @("PAULA", "PAULA_CASA", "SABADO_SHOW", "TU_CASA_AQUI", "SUPLEMENTO_ANP")

Get-ChildItem -Path $origen -Directory | Where-Object {
    $_.Name.ToUpper().EndsWith("_WEB")
} | ForEach-Object {
    $oldName = $_.Name
    $oldNameUpper = $oldName.ToUpper()
    $oldFullPath = $_.FullName
    
    Write-DualLog "Procesando carpeta: $oldName"

    # Extraer el nombre base antes de "_WEB"
    $nombreSinWeb = $oldNameUpper -replace "_WEB$", ""
    
    # Si es carpeta padre excluida, no hacer nada
    if ($carpetasPadreExcluidas -contains $nombreSinWeb) {
        Write-DualLog "Salteando carpeta padre excluida: '$oldName'"
        return
    }

    # Buscar mes en el nombre de la carpeta
    $foundMesKey = $null
    foreach ($mesKey in $meses.Keys) {
        if ($oldNameUpper -match "\b$mesKey\b") {
            $foundMesKey = $mesKey
            break
        }
    }

    if (-not $foundMesKey) {
        Write-DualLog "[WARN] No se encontro un mes valido en '$oldName'. Saltando."
        return
    }

    # Extraer anio y dia (si aplica) del nombre de la carpeta
    $anio = $null
    $dia = $null
    if ($oldNameUpper -match "\b(\d{4})\b") {
        $anio = $matches[1]
    }
    if ($oldNameUpper -match "\b(\d{1,2})\s*$foundMesKey") {
        $dia = "{0:D2}" -f [int]$matches[1]
    }

    if (-not $anio) {
        Write-DualLog "[WARN] No se encontro un anio valido en '$oldName'. Saltando."
        return
    }

    # Determinar el nuevo nombre segun la publicacion
    $newDateFormat = $null
    $targetPath = $null
    $ftpTarget = $null
    $currentProcessStatusKey = $null
    if ($oldNameUpper -like "*SABADO SHOW*") {
        if (-not $dia) {
            Write-DualLog "[WARN] No se encontro un dia valido en '$oldName' para SABADO SHOW. Saltando."
            return
        }
        $newDateFormat = "$anio$($meses[$foundMesKey])$dia"
        $targetPath = Join-Path $processSabadoShow $newDateFormat
        $ftpTarget = "$ftpSubPathSabadoShow/$newDateFormat"
        $currentProcessStatusKey = "Revista-Sabado-Show"
    } else {
        $newDateFormat = "$anio$($meses[$foundMesKey])"
        switch -Wildcard ($oldNameUpper) {
            "*PAULA*" { 
                $targetPath = Join-Path $processPaula $newDateFormat
                $ftpTarget = "$ftpSubPathPaula/$newDateFormat"
                $currentProcessStatusKey = "Revista-Paula"
            }
            "*PAULA_CASA*" { 
                $targetPath = Join-Path $processPaulaCasa $newDateFormat
                $ftpTarget = "$ftpSubPathPaulaCasa/$newDateFormat"
                $currentProcessStatusKey = "Revista-Paula-Casa"
            }
            "*TU_CASA_AQUI*" { 
                $targetPath = Join-Path $processTuCasaAqui $newDateFormat
                $ftpTarget = "$ftpSubPathTuCasaAqui/$newDateFormat"
                $currentProcessStatusKey = "Revista-Tu-Casa-Aqui"
            }
            "*SUPLEMENTO_ANP*" { 
                $targetPath = Join-Path $processSupANP $newDateFormat
                $ftpTarget = "$ftpSubPathSupANP/$newDateFormat"
                $currentProcessStatusKey = "Suplemento-ANP"
            }
            default {
                Write-DualLog "[WARN] Carpeta '$oldName' no corresponde a ninguna publicacion conocida. Saltando."
                return
            }
        }
    }

    # Marcar la publicacion como procesada
    if ($currentProcessStatusKey) {
        $script:processedPublications[$currentProcessStatusKey] = $true
    }

    # Copiar contenido al destino solo si hay contenido valido
    try {
        Write-DualLog "[INFO] Procesando destino: $targetPath (FTP: '$ftpTarget')"
        Write-DualLog "Carpeta '$oldName' procesada correctamente con formato de fecha: $newDateFormat"
    } catch {
        Write-DualLog "[ERROR] Error al procesar carpeta '$oldName': $($_.Exception.Message)"
        $script:processSuccessful = $false
        if ($currentProcessStatusKey) {
            $script:processStatus[$currentProcessStatusKey] = $false
        }
    }
    Write-DualLog "Se renombran las carpetas correctamente."
}


# Subir todo por FTP
function Upload-DirectoryRecursive {
    param (
        [string]$localDir,
        [string]$ftpRemotePath
    )

    if (-not (Test-Path $localDir)) {
        Write-DualLog "[WARN] Carpeta local no existe para subir: $localDir."
        return
    }

    # Verificar si la carpeta tiene contenido valido
    $allFiles = Get-ChildItem -Path $localDir -Recurse -File
    if ($allFiles.Count -eq 0) {
        Write-DualLog "[INFO] Carpeta vacia, no se sube: $localDir."
        return
    }

    $ftpRemotePath = $ftpRemotePath.TrimEnd("/").Replace("\", "/")

    # Crear directorios remotos
    Get-ChildItem -Path $localDir -Recurse -Directory | ForEach-Object {
        $relativePath = $_.FullName.Substring($localDir.Length).TrimStart('\')
        $remoteSubDir = "$ftpRemotePath/$relativePath".Replace("\", "/")

        try {
            $dirUri = [System.Uri]::new("ftp://$ftpServer/$remoteSubDir")
            $dirRequest = [System.Net.FtpWebRequest]::Create($dirUri)
            $dirRequest.Method = [System.Net.WebRequestMethods+Ftp]::MakeDirectory
            $dirRequest.Credentials = New-Object System.Net.NetworkCredential($ftpUser, $ftpPass)
            $dirRequest.UsePassive = $true
            $dirRequest.UseBinary = $true
            $dirRequest.KeepAlive = $true

            $dirResponse = $dirRequest.GetResponse()
            $dirResponse.Close()
            Write-DualLog "[OK] Directorio FTP creado: $remoteSubDir"
        } catch {
            if ($_.Exception.Message -notmatch "550") {
                Write-DualLog "[ERROR] No se pudo crear el directorio FTP $remoteSubDir : $($_.Exception.Message)"
                $script:processSuccessful = $false
            } else {
                Write-DualLog "[INFO] Directorio FTP ya existe: $remoteSubDir"
            }
        }
    }

    # Subir archivos
    $successfulUploads = 0
    $itemsCount = $allFiles.Count

    Write-DualLog "[INFO] Subiendo un total de $itemsCount archivos a '$ftpRemotePath'."

    foreach ($file in $allFiles) {
        $localFile = $file.FullName
        $relativePath = $localFile.Substring($localDir.Length).TrimStart('\')
        $remoteFile = "$ftpRemotePath/$relativePath".Replace("\", "/")

        try {
            $fileUri = [System.Uri]::new("ftp://$ftpServer/$remoteFile")
            $fileRequest = [System.Net.FtpWebRequest]::Create($fileUri)
            $fileRequest.Method = [System.Net.WebRequestMethods+Ftp]::UploadFile
            $fileRequest.Credentials = New-Object System.Net.NetworkCredential($ftpUser, $ftpPass)
            $fileRequest.UsePassive = $true
            $fileRequest.UseBinary = $true
            $fileRequest.KeepAlive = $true

            $requestStream = $fileRequest.GetRequestStream()
            $fileStream = [System.IO.File]::OpenRead($localFile)

            $fileStream.CopyTo($requestStream)

            $fileStream.Close()
            $requestStream.Close()

            $response = $fileRequest.GetResponse()
            $response.Close()

            Write-DualLog "[OK] Subido a FTP: $remoteFile"
            $successfulUploads++
        } catch {
            Write-DualLog "[ERROR] Falla la subida de $remoteFile - $($_.Exception.Message)"
            $script:processSuccessful = $false
        }
    }

    Write-DualLog "[INFO] Se subieron $successfulUploads de $itemsCount archivos."
}

# Verificar conexion FTP
function Test-FtpConnection {
    param ($ftpServer, $ftpUser, $ftpPass, $ftpBasePath)

    if ($script:ftpConnectionTested) {
        Write-DualLog "[INFO] Conexion FTP ya probada y confirmada."
        return $true
    }

    try {
        $uri = "ftp://$ftpServer/"
        if (-not [string]::IsNullOrEmpty($ftpBasePath)) {
            $uri = "ftp://$ftpServer/$ftpBasePath/"
        }
        $ftpRequest = [System.Net.FtpWebRequest]::Create($uri)
        $ftpRequest.Method = [System.Net.WebRequestMethods+Ftp]::ListDirectory 
        $ftpRequest.Credentials = New-Object System.Net.NetworkCredential($ftpUser, $ftpPass)
        $ftpRequest.UsePassive = $true
        $ftpRequest.UseBinary = $true
        $ftpRequest.KeepAlive = $false

        $response = $null
        try {
            $response = $ftpRequest.GetResponse()
            Write-DualLog "[OK] Conexion FTP exitosa a '$uri'."
            $script:ftpConnectionTested = $true 
            return $true
        } catch {
            Write-DualLog "[ERROR] No se pudo conectar al FTP o listar directorio en '$uri': $($_.Exception.Message)"
            $script:ftpConnectionTested = $false 
            return $false
        } finally {
            if ($response) { $response.Close() }
        }
    } catch {
        Write-DualLog "[ERROR] Error general al intentar conectar al FTP: $($_.Exception.Message)"
        $script:ftpConnectionTested = $false 
        return $false
    }
}

# Envio de notificacion por correo
function Send-NotificationEmail {
    param (
        [bool]$success, 
        [string]$logFolderPath, 
        [bool]$sinProcesar = $false
    )
    $script:isSendingEmail = $true 

    $smtpClient = New-Object System.Net.Mail.SmtpClient
    $smtpClient.Host = $smtpServer
    $mailMessage = New-Object System.Net.Mail.MailMessage
    $mailMessage.From = $emailFrom
    $mailMessage.To.Add($emailTo)
    
    $hoy = Get-Date
    $currentDate = $hoy.ToString('dd-MM-yyyy - HH:mm')

    # Funcion para obtener el directorio mas reciente en $tempBakBase
    function Get-LatestBackupDirectory {
        param (
            [string]$backupPath,
            [string]$publication
        )
        try {
            if (Test-Path $backupPath -PathType Container) {
                $backupDirs = Get-ChildItem -Path $backupPath -Directory
                
                # Usar formato YYYYMMDD para Revista-Sabado-Show, YYYYMM para otros
                $regex = if ($publication -eq "Revista-Sabado-Show") { "^\d{8}$" } else { "^\d{6}$" }
                
                $latestBackupDir = $backupDirs | 
                                 Where-Object { 
                                     $_.Name -match $regex -and 
                                     (Get-ChildItem -Path $_.FullName -Recurse -File | Measure-Object).Count -gt 0 
                                 } | 
                                 Sort-Object { 
                                     try { 
                                         $format = if ($publication -eq "Revista-Sabado-Show") { "yyyyMMdd" } else { "yyyyMM" }
                                         [datetime]::ParseExact($_.Name, $format, $null) 
                                     } catch { 
                                         [datetime]::MinValue 
                                     }
                                 } -Descending | 
                                 Select-Object -First 1 | Select-Object -ExpandProperty Name

                if ($latestBackupDir) {
                    Write-DualLog "[INFO] Directorio mas reciente encontrado /temp-bak/$publication : $latestBackupDir"
                    return $latestBackupDir
                } else {
                    Write-DualLog "[WARN] No se encontraron directorios validos no vaci璷s en backup para $publication en $backupPath"
                }
            } else {
                Write-DualLog "[WARN] El path de backup $backupPath no existe para $publication"
            }
        } catch {
            Write-DualLog "[ERROR] No se pudo obtener el directorio mas reciente en backup para $publication en $backupPath : $($_.Exception.Message)"
        }

        # Fallback: No devolver fecha actual para evitar crear enlaces invalidos
        return $null
    }

    # Definir los paths de backup para cada publicacion
    $backupPaths = @{
        "Revista-Paula" = Join-Path $tempBakBase "Revista-Paula"
        "Revista-Paula-Casa" = Join-Path $tempBakBase "Revista-Paula-Casa"
        "Revista-Tu-Casa-Aqui" = Join-Path $tempBakBase "Revista-Tu-Casa-Aqui"
        "Revista-Sabado-Show" = Join-Path $tempBakBase "Revista-Sabado-Show"
        "Suplemento-ANP" = Join-Path $tempBakBase "Suplemento-ANP"
    }

    if ($sinProcesar) {
        $mailMessage.Subject = "Edicion Papel - [EXITOSO]"
        $bodyContent = @"
Ejecucion del dia: $currentDate

Estado general: Exitoso - Sin modificaciones.
"@

        foreach ($key in $backupPaths.Keys) {
            $latestDir = Get-LatestBackupDirectory -backupPath $backupPaths[$key] -publication $key
            $linkBase = "https://edicionpapel.elpais.com.uy/"
            $linkSpecific = switch ($key) {
                "Revista-Paula" { "revista-paula" }
                "Revista-Paula-Casa" { "revista-paula-casa" }
                "Revista-Tu-Casa-Aqui" { "revista-tu-casa-aqui" }
                "Revista-Sabado-Show" { "revista-sabado-show" }
                "Suplemento-ANP" { "suplemento-anp" }
                default { $key.ToLower().Replace("revista-", "").Replace("suplemento-", "").Replace("-", "") }
            }
            $linkDir = if ($latestDir) { "$linkSpecific/$latestDir" } else { $linkSpecific }
            $bodyContent += "`n    > $linkBase$linkDir"
        }
        $bodyContent += "`n`nDetalles: Ver LOG adjunto para mas informacion."
        $mailMessage.Body = $bodyContent
    } else {
        $overallSuccessForEmail = $true
        foreach ($status in $script:processStatus.Values) {
            if (-not $status) {
                $overallSuccessForEmail = $false
                break
            }
        }
        
        $mailMessage.Subject = if ($overallSuccessForEmail) { "Edicion Papel - [EXITOSO]" } else { "Edicion Papel - [FALLO]" }

        $bodyContent = "Ejecucion del dia: $currentDate`n-"
        
        $processStatusKeysForBody = $script:processStatus.Keys.Clone()

        foreach ($key in $processStatusKeysForBody) {
            $statusText = if ($script:processStatus[$key]) { 
                if ($script:processedPublications[$key]) { 
                    "Exitoso - Procesado correctamente" 
                } else { 
                    "No procesado - Sin carpetas _web disponibles" 
                }
            } else { 
                "Fallido - Por favor, revisar" 
            }
            
            $linkBase = "https://edicionpapel.elpais.com.uy/"
            $linkSpecific = switch ($key) {
                "Revista-Paula" { "revista-paula" }
                "Revista-Paula-Casa" { "revista-paula-casa" }
                "Revista-Tu-Casa-Aqui" { "revista-tu-casa-aqui" }
                "Revista-Sabado-Show" { "revista-sabado-show" }
                "Suplemento-ANP" { "suplemento-anp" }
                default { $key.ToLower().Replace("revista-", "").Replace("suplemento-", "").Replace("-", "") }
            }
            $latestDir = Get-LatestBackupDirectory -backupPath $backupPaths[$key] -publication $key
            $linkDir = if ($latestDir) { "$linkSpecific/$latestDir" } else { $linkSpecific }
            $bodyContent += "`n> Proceso: $key`nEstado: $statusText`n    > $linkBase$linkDir`n-"
        }
        $bodyContent += "`nDetalles: Ver LOG adjunto para mqs informacion."
        $mailMessage.Body = $bodyContent
    } 

    $attachments = @()
    if (Test-Path $dailyLogFile -PathType Leaf) {
        try {
            $attachment = New-Object System.Net.Mail.Attachment($dailyLogFile)
            $mailMessage.Attachments.Add($attachment)
            $attachments += $attachment
            Write-DualLog "[INFO] Adjuntando archivo $dailyLogFile al correo"
        } catch {
            Write-DualLog "[ERROR] No se pudo adjuntar archivo $dailyLogFile : $($_.Exception.Message)"
            $script:processSuccessful = $false
            $processStatusKeysForError = $script:processStatus.Keys.Clone()
            foreach ($key in $processStatusKeysForError) { 
                $script:processStatus[$key] = $false
            }
        }
    } else {
        Write-DualLog "[WARN] No se encontra el archivo de log $dailyLogFile para adjuntar."
        $script:processSuccessful = $false
        $processStatusKeysForError = $script:processStatus.Keys.Clone()
        foreach ($key in $processStatusKeysForError) { 
            $script:processStatus[$key] = $false
        }
    }

    try {
        $smtpClient.Send($mailMessage)
        Write-DualLog "[INFO] Correo enviado correctamente a $emailTo"
    } catch {
        Write-DualLog "[ERROR] No se pudo enviar correo: $($_.Exception.Message)"
        $script:processSuccessful = $false
        $processStatusKeysForError = $script:processStatus.Keys.Clone()
        foreach ($key in $processStatusKeysForError) { 
            $script:processStatus[$key] = $false
        }
    } finally {
        foreach ($attachment in $attachments) {
            $attachment.Dispose()
        }
        $mailMessage.Dispose()
        $script:isSendingEmail = $false
    }
    Write-DualLog "----------------------------------------------------"
}

# ==== MAIN ====
Write-DualLog "=== INICIO DEL SCRIPT - $fechaLog ==="

# Verificar conexion FTP
if (-not (Test-FtpConnection -ftpServer $ftpServer -ftpUser $ftpUser -ftpPass $ftpPass -ftpBasePath $ftpBasePath)) {
    Write-DualLog "[ERROR] No se pudo conectar al servidor FTP. Abortando script."
    Send-NotificationEmail -success $false -logFolderPath $logDir
    exit 1
}

Write-DualLog "Origen a procesar: $origen"
Write-DualLog "----------------------------------------------------"

$procesadosCount = 0
$foldersToProcess = Get-ChildItem -Path $origen -Directory | Where-Object { $_.Name -like "*_web" }

if ($foldersToProcess.Count -eq 0) {
    Write-DualLog "No se encontraron carpetas '_web' para procesar en '$origen'."
    Write-DualLog "Se envia mail con las ultimas versiones:"
    # No se realiza ningun procesamiento, por lo tanto, es un "exito" en terminos de que no hubo errores.
    $script:processSuccessful = $true
    
    $keysToSetTrue = $script:processStatus.Keys.Clone() 
    foreach ($key in $keysToSetTrue) { 
        $script:processStatus[$key] = $true 
    }

    Write-DualLog "----------------------------------------------------"
    Write-DualLog "=== FIN DEL SCRIPT - SIN CARPETAS PARA PROCESAR ==="
    Send-NotificationEmail -success $true -logFolderPath $logDir -sinProcesar $true
    exit 0
}

# Reiniciar processStatus para el procesamiento real
$statusKeys = $script:processStatus.Keys.Clone() 
foreach ($key in $statusKeys) {
    $script:processStatus[$key] = $true 
}

foreach ($carpeta in $foldersToProcess) {
    $nombre = $carpeta.Name.ToUpper()
    $currentProcessStatusKey = $null    
    $currentAnio = $null
    $currentMesNum = $null
    $currentDia = $null

    Write-DualLog "----------------------------------------------------"
    Write-DualLog "Procesando carpeta: $($carpeta.Name)"

    # Extraer dia, mes, anio de la carpeta
    if ($nombre -match "^(.+?)(\d{1,2})?\s*(\b\w+\b)\s*(\d{4})_WEB$") {
        $baseNombre = $matches[1].Trim()
        $dia = if ($matches[2]) { "{0:D2}" -f [int]$matches[2] } else { $null }
        $mesNombre = $matches[3].ToUpper()
        $anio = $matches[4]

        if ($meses.ContainsKey($mesNombre)) {
            $mesNum = $meses[$mesNombre]
            $currentAnio = $anio
            $currentMesNum = $mesNum
            $currentDia = $dia

            # Determinar destino basado en el nombre de la carpeta
            if ($nombre -like "*PAULA CASA*") {
                $destinoFinal = Join-Path $processPaulaCasa "$anio$mesNum"
                $destinoMovidoParent = $origenPaulaCasa
                $currentProcessStatusKey = "Revista-Paula-Casa"
            } elseif ($nombre -like "*PAULA*") {
                $destinoFinal = Join-Path $processPaula "$anio$mesNum"
                $destinoMovidoParent = $origenPaula
                $currentProcessStatusKey = "Revista-Paula"
            } elseif ($nombre -like "*TU CASA AQUI*") {
                $destinoFinal = Join-Path $processTuCasaAqui "$anio$mesNum"
                $destinoMovidoParent = $origenTuCasaAqui
                $currentProcessStatusKey = "Revista-Tu-Casa-Aqui"
            } elseif ($nombre -like "*SABADO SHOW*") {
                if (-not $dia) {
                    Write-DualLog "[WARN] No se encontro un di璦 valido en '$nombre' para SABADO SHOW. Saltando."
                    $script:processSuccessful = $false
                    $script:processStatus["Revista-Sabado-Show"] = $false
                    continue
                }
                $destinoFinal = Join-Path $processSabadoShow "$anio$mesNum$dia"
                $destinoMovidoParent = $origenSabadoShow
                $currentProcessStatusKey = "Revista-Sabado-Show"
            } elseif ($nombre -like "*SUPLEMENTO ANP*") {
                $destinoFinal = Join-Path $processSupANP "$anio$mesNum"
                $destinoMovidoParent = $origenSupANP
                $currentProcessStatusKey = "Suplemento-ANP"
            } else {
                Write-DualLog "[WARN] Nombre de carpeta '$nombre' no reconocido para asignar destino. Saltando."
                $script:processSuccessful = $false
                continue
            }

            # Buscar y copiar solo /flippingoffline y index.html de forma recursiva
            $sourcePath = $carpeta.FullName
            
            $flippingOffline = Get-ChildItem -Path $sourcePath -Recurse -Directory -Filter "flippingoffline" -ErrorAction SilentlyContinue | Select-Object -First 1
            $indexHtml = Get-ChildItem -Path $sourcePath -Recurse -File -Filter "index.html" -ErrorAction SilentlyContinue | Select-Object -First 1

            if (-not $flippingOffline -and -not $indexHtml) {
                Write-DualLog "[WARN] No se encontra ni 'flippingoffline' ni 'index.html' en '$sourcePath'. Saltando."
                $script:processSuccessful = $false
                if ($currentProcessStatusKey) {
                    $script:processStatus[$currentProcessStatusKey] = $false
                }
                continue
            }

            # Crear destino solo si hay contenido valido
            if (!(Test-Path $destinoFinal)) {
                try {
                    New-Item -ItemType Directory -Path $destinoFinal -Force | Out-Null
                    Write-DualLog "[INFO] Destino creado: $destinoFinal"
                } catch {
                    Write-DualLog "[ERROR] No se pudo crear el directorio destino $destinoFinal : $($_.Exception.Message)"
                    $script:processSuccessful = $false
                    if ($currentProcessStatusKey) {
                        $script:processStatus[$currentProcessStatusKey] = $false
                    }
                    continue
                }
            }

            $copySuccess = $true
            if ($flippingOffline) {
                $flippingDest = Join-Path $destinoFinal "flippingoffline"
                try {
                    Copy-Item -Path $flippingOffline.FullName -Destination $flippingDest -Recurse -Force -ErrorAction Stop
                    Write-DualLog "Copiado contenido de /flippingoffline a '$flippingDest'"
                } catch {
                    Write-DualLog "[ERROR] Error al copiar 'flippingoffline' de '$($flippingOffline.FullName)' a '$flippingDest': $($_.Exception.Message)"
                    $copySuccess = $false
                }
            }

            if ($indexHtml) {
                $indexDest = Join-Path $destinoFinal "index.html"
                try {
                    Copy-Item -Path $indexHtml.FullName -Destination $indexDest -Force -ErrorAction Stop
                    Write-DualLog "Copiando archivo 'index.html' a '$indexDest'"
                } catch {
                    Write-DualLog "[ERROR] Error al copiar 'index.html' de '$($indexHtml.FullName)' a '$indexDest': $($_.Exception.Message)"
                    $copySuccess = $false
                }
            }

            if ($copySuccess -and ($flippingOffline -or $indexHtml)) {
                $procesadosCount++

                # Marcar la publicaci贸n como procesada
                if ($currentProcessStatusKey) {
                    $script:processedPublications[$currentProcessStatusKey] = $true
                }

                # Ubicaci贸n del Application.css
                $targetFlippingOfflinePath = Join-Path $destinoFinal "flippingoffline"

                if (Test-Path $targetFlippingOfflinePath -PathType Container) {
                    $existingApplicationCss = Join-Path $targetFlippingOfflinePath "Application.css"
                    $oldApplicationCss = Join-Path $targetFlippingOfflinePath "Application_old.css"

                    if (Test-Path $existingApplicationCss -PathType Leaf) {
                        try {
                            Rename-Item -Path $existingApplicationCss -NewName "Application_old.css" -Force -ErrorAction Stop
                            Write-DualLog "Renombrado de Application.css a Application_old.css."
                        } catch {
                            Write-DualLog "[ERROR] Error al renombrar '$existingApplicationCss': $($_.Exception.Message)"
                            $script:processSuccessful = $false
                            if ($currentProcessStatusKey) {
                                $script:processStatus[$currentProcessStatusKey] = $false
                            }
                        }
                    } else {
                        Write-DualLog "No se encontra '$existingApplicationCss' existente en '$targetFlippingOfflinePath'."
                    }

                    if (Test-Path $sourceApplicationCss -PathType Leaf) {
                        try {
                            Copy-Item -Path $sourceApplicationCss -Destination $targetFlippingOfflinePath -Force -ErrorAction Stop
                            Write-DualLog "Copiando Application.css a '$targetFlippingOfflinePath'."
                        } catch {
                            Write-DualLog "[ERROR] Error al copiar '$sourceApplicationCss' a '$targetFlippingOfflinePath': $($_.Exception.Message)"
                            $script:processSuccessful = $false
                            if ($currentProcessStatusKey) {
                                $script:processStatus[$currentProcessStatusKey] = $false
                            }
                        }
                    } else {
                        Write-DualLog "[ERROR] No se encontra el archivo fuente '$sourceApplicationCss'."
                        $script:processSuccessful = $false
                        if ($currentProcessStatusKey) {
                            $script:processStatus[$currentProcessStatusKey] = $false
                        }
                    }
                } else {
                    Write-DualLog "[WARN] No se encontra la carpeta 'flippingoffline' en '$destinoFinal'."
                }

                # Crear archivo Default.asp
                $defaultAspPath = Join-Path $destinoFinal "Default.asp"
                $aspContent = @"
<%
    response.redirect("index.html")
%>
"@
                try {
                    Set-Content -Path $defaultAspPath -Value $aspContent -Encoding ASCII -ErrorAction Stop
                    Write-DualLog "Archivo Default.asp creado en: $defaultAspPath"
                } catch {
                    Write-DualLog "[ERROR] Error al crear Default.asp en '$defaultAspPath': $($_.Exception.Message)"
                    $script:processSuccessful = $false
                    if ($currentProcessStatusKey) {
                        $script:processStatus[$currentProcessStatusKey] = $false
                    }
                }

                # Mover carpeta original al destino correspondiente
                if (!(Test-Path $destinoMovidoParent)) {
                    try {
                        New-Item -ItemType Directory -Path $destinoMovidoParent -Force | Out-Null
                    } catch {
                        Write-DualLog "[ERROR] No se pudo crear el directorio de destino de movimiento '$destinoMovidoParent': $($_.Exception.Message)"
                        $script:processSuccessful = $false
                        if ($currentProcessStatusKey) {
                            $script:processStatus[$currentProcessStatusKey] = $false
                        }
                        continue
                    }
                }
                $nuevoDestinoCompleto = Join-Path $destinoMovidoParent $carpeta.Name
                try {
                    Move-Item -Path $carpeta.FullName -Destination $nuevoDestinoCompleto -Force -ErrorAction Stop
                    Write-DualLog "Carpeta movida: '$($carpeta.FullName)' -> '$nuevoDestinoCompleto'"
                } catch {
                    Write-DualLog "[ERROR] Error al mover '$($carpeta.FullName)' a '$nuevoDestinoCompleto': $($_.Exception.Message)"
                    $script:processSuccessful = $false
                    if ($currentProcessStatusKey) {
                        $script:processStatus[$currentProcessStatusKey] = $false
                    }
                }
            } else {
                Write-DualLog "[ERROR] No se pudo copiar el contenido necesario (flippingoffline o index.html) para '$sourcePath'."
                $script:processSuccessful = $false
                if ($currentProcessStatusKey) {
                    $script:processStatus[$currentProcessStatusKey] = $false
                }
            }
        } else {
            Write-DualLog "[ERROR] Mes '$mesNombre' no reconocido en el archivo de configuracion para la carpeta '$nombre'."
            $script:processSuccessful = $false
            if ($currentProcessStatusKey) {
                $script:processStatus[$currentProcessStatusKey] = $false
            }
        }
    } else {
        Write-DualLog "[WARN] Formato de carpeta '$nombre' no reconocido (esperado 'NOMBRE [DIA] MES A脩O_WEB'). Saltando."
        $script:processSuccessful = $false
    }
    Write-DualLog "----------------------------------------------------"
}

Write-DualLog "----------------------------------------------------"
Write-DualLog "Cantidad de carpetas a procesar por FTP: $procesadosCount."
Write-DualLog "----------------------------------------------------"

# Subir a FTP
$revistas = @(
    @{ Nombre = "Revista-Paula"; Local = $processPaula; Remota = "$ftpSubPathPaula" },
    @{ Nombre = "Revista-Paula-Casa"; Local = $processPaulaCasa; Remota = "$ftpSubPathPaulaCasa" },
    @{ Nombre = "Revista-Tu-Casa-Aqui"; Local = $processTuCasaAqui; Remota = "$ftpSubPathTuCasaAqui" },
    @{ Nombre = "Revista-Sabado-Show"; Local = $processSabadoShow; Remota = "$ftpSubPathSabadoShow" },
    @{ Nombre = "Suplemento-ANP"; Local = $processSupANP; Remota = "$ftpSubPathSupANP" }
)

foreach ($revista in $revistas) {
    # Saltar publicaciones que no tuvieron carpetas procesadas
    if (-not $script:processedPublications[$revista.Nombre]) {
        Write-DualLog "[INFO] No se encontraron carpetas _web para $($revista.Nombre). Saltando FTP y backup."
        continue
    }

    Write-DualLog "----------------------------------------------------"   
    Write-DualLog "Iniciando la subida FTP para: $($revista.Nombre)"
    
    $regex = if ($revista.Nombre -eq "Revista-Sabado-Show") { "^\d{8}$" } else { "^\d{6}$" }
    $carpetasMes = Get-ChildItem -Path $revista.Local -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $regex }
    
    if ($carpetasMes.Count -eq 0) {
        Write-DualLog "[INFO] No se encontraron carpetas validas para $($revista.Nombre) en '$($revista.Local)'. Saltando."
        continue
    }

    foreach ($carpeta in $carpetasMes) {
        $carpetaLocalMes = Join-Path $revista.Local $carpeta.Name
        $carpetaRemota = "$($revista.Remota)/$($carpeta.Name)"
        
        if (Test-Path $carpetaLocalMes -PathType Container) {
            $filesInFolder = Get-ChildItem -Path $carpetaLocalMes -Recurse -File
            if ($filesInFolder.Count -gt 0) {
                Write-DualLog "Directorio local a subir: $carpetaLocalMes"
                try {
                    Upload-DirectoryRecursive -localDir $carpetaLocalMes -ftpRemotePath $carpetaRemota
                } catch {
                    Write-DualLog "[ERROR] Falla la subida FTP para $($revista.Nombre) en $carpetaRemota : $($_.Exception.Message)"
                    $script:processSuccessful = $false
                    $script:processStatus[$revista.Nombre] = $false
                }
            } else {
                Write-DualLog "[INFO] Carpeta vaci璦 encontrada para $($revista.Nombre) en '$carpetaLocalMes'. Saltando subida FTP."
                continue
            }
        } else {
            Write-DualLog "[INFO] Carpeta de publicacion local no encontrada para $($revista.Nombre) en '$carpetaLocalMes'. Saltando subida FTP."
            continue
        }

        # Mover al backup
        $destinoBackupParent = Join-Path -Path $tempBakBase -ChildPath $revista.Nombre
        $destinoBackup = Join-Path -Path $destinoBackupParent -ChildPath $carpeta.Name
        
        if (!(Test-Path $destinoBackupParent)) {
            try {
                New-Item -Path $destinoBackupParent -ItemType Directory -Force | Out-Null
            } catch {
                Write-DualLog "[ERROR] No se pudo crear el directorio de backup padre '$destinoBackupParent': $($_.Exception.Message)"
                $script:processSuccessful = $false
                $script:processStatus[$revista.Nombre] = $false
            }
        }
        
        if (!(Test-Path $destinoBackup)) {
            try {
                New-Item -Path $destinoBackup -ItemType Directory -Force | Out-Null
            } catch {
                Write-DualLog "[ERROR] No se pudo crear el directorio de backup '$destinoBackup': $($_.Exception.Message)"
                $script:processSuccessful = $false
                $script:processStatus[$revista.Nombre] = $false
            }
        }

        try {
            Move-Item -Path $carpetaLocalMes -Destination $destinoBackup -Force -ErrorAction Stop 
            Write-DualLog "[INFO] Contenido de \temp movido a '$destinoBackup'"
        } catch {
            Write-DualLog "[ERROR] No se pudo mover el contenido de \temp a '$destinoBackup': $($_.Exception.Message)"
            $script:processSuccessful = $false
            $script:processStatus[$revista.Nombre] = $false
        }
    }
    Write-DualLog "----------------------------------------------------"
}

Write-DualLog "=== FIN DEL SCRIPT - Total Procesados: $procesadosCount Suplementos ==="

# Enviar notificaci贸n por email final
Send-NotificationEmail -success $script:processSuccessful -logFolderPath $logDir

# Eliminar logs diarios de mas de 30 dias
Write-DualLog "Limpiando logs antiguos (m谩s de 30 d铆as)."
try {
    Get-ChildItem -Path $logDir -Filter "daily_process_*.txt" | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } | Remove-Item -Force -ErrorAction Stop
    Write-DualLog "Logs antiguos eliminados correctamente."
} catch {
    Write-DualLog "[ERROR] Error al eliminar logs antiguos: $($_.Exception.Message)"
}