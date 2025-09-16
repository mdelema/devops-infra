# ==============================
# Configuracion inicial
# ==============================

# Cargar configuracion
$config = Import-PowerShellDataFile -Path (Join-Path $PSScriptRoot "config.psd1")

# Variables base
$origen = $config.Origen
$destino = $config.SubfolderEconomia
$logDir = $config.LogDir

# Fecha actual +1 dia para renombrado y logs
$fecha = (Get-Date).AddDays(1)
$DDMMYY = $fecha.ToString("ddMMyy")
$fechaStr = $fecha.ToString("yyyy-MM-dd_HH-mm")

# Rutas de logs
$logFile = Join-Path $logDir $config.LogHistoricoName           # Log historico (sin fecha)
$dailyLog = Join-Path $logDir "$($config.LogDiarioPrefix)$fechaStr.txt"  # Log diario (con fecha)

# Flags y arrays para estado
$script:processSuccessful = $true
$script:isSendingEmail = $false
$renombradosLog = @()
$archivosRenombrados = $false

# ==============================
# Crear carpetas si no existen
# ==============================
if (-not (Test-Path $destino)) {
    New-Item -ItemType Directory -Path $destino | Out-Null
}
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}

# ==============================
# Funcion de log con manejo de errores
# ==============================
function Write-DualLog {
    param ([string]$message)

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $fullMessage = "$timestamp - $message"

    # Mostrar por consola
    Write-Host $fullMessage

    # Escribir en log historico
    try {
        Add-Content -Path $logFile -Value $fullMessage -Encoding UTF8 -ErrorAction Stop
    } catch {
        Write-Host "ERROR: No se pudo escribir en el log historico $logFile - $($_.Exception.Message)"
        $script:processSuccessful = $false
    }

    # Escribir en log diario (si no se esta enviando email)
    if (-not $script:isSendingEmail) {
        try {
            Add-Content -Path $dailyLog -Value $fullMessage -Encoding UTF8 -ErrorAction Stop
        } catch {
            Write-Host "ERROR: No se pudo escribir en el log diario $dailyLog - $($_.Exception.Message)"
            try {
                Add-Content -Path $logFile -Value "ERROR: No se pudo escribir en el log diario $dailyLog - $($_.Exception.Message)" -Encoding UTF8
            } catch {}
            $script:processSuccessful = $false
        }
    }
}

# ==============================
# Funcion para enviar correo
# ==============================
function Send-NotificationEmail {
    param (
        [bool]$success,
        [string]$logFilePath,
        [string[]]$renombrados = @()
    )

    $script:isSendingEmail = $true

    $smtpClient = New-Object System.Net.Mail.SmtpClient
    $smtpClient.Host = $config.SmtpServer

    $mailMessage = New-Object System.Net.Mail.MailMessage
    $mailMessage.From = $config.EmailFrom
    $mailMessage.To.Add($config.EmailTo)
    $mailMessage.Subject = if ($success) { "Ren_Economia - [EXITOSO]" } else { "Ren_Economia - [FALLO]" }

    $renombradosTexto = ""
    if ($renombrados.Count -gt 0) {
        $renombradosTexto = "`nArchivos renombrados:`n" + ($renombrados -join "`n")
    }

    $mailMessage.Body = @"
Ejecucion del dia: $(Get-Date -Format 'dd-MM-yyyy HH:mm')
Proceso:    Renombre de Economia y Mercado
Estado:     $(if ($success) { "Exitoso - Buen trabajo" } else { "Fallido - Por favor, revisar" })
$renombradosTexto

Detalles: Ver LOG diario adjunto para mas informacion.
"@

    # Adjuntar el log diario
    if (Test-Path $logFilePath) {
        try {
            $attachment = New-Object System.Net.Mail.Attachment($logFilePath)
            $mailMessage.Attachments.Add($attachment)
            Write-DualLog "Adjunto: $($logFilePath)"
        } catch {
            Write-DualLog "[ERROR] No se pudo adjuntar el log: $($_.Exception.Message)"
        }
    } else {
        Write-DualLog "[ADVERTENCIA] No se encontro el archivo de log para adjuntar."
    }

    try {
        $smtpClient.Send($mailMessage)
        Write-DualLog "Correo enviado exitosamente a $($config.EmailTo)"
    } catch {
        Write-DualLog "[ERROR] Fallo el envio del correo: $($_.Exception.Message)"
        $script:processSuccessful = $false
    } finally {
        foreach ($att in $mailMessage.Attachments) {
            $att.Dispose()
        }
        $mailMessage.Dispose()
    }
    $script:isSendingEmail = $false
}

#=================================
#==      INICIO DEL PROCESO     ==
#=================================

# Agregar separador en log historico
$separador = "==================== $(Get-Date -Format 'yyyy-MM-dd') ===================="
Add-Content -Path $logFile -Value $separador

Write-DualLog "-------------------------------------------------------------"
Write-DualLog "Inicio del proceso de suplementos."

# ==============================
# Copiar archivos
# ==============================
try {
    $archivos = Get-ChildItem -Path $origen -Filter "Eco_*_*_*.pdf" -ErrorAction Stop
    foreach ($archivo in $archivos) {
        Copy-Item -Path $archivo.FullName -Destination $destino -Force
        Write-DualLog "Copiado: $($archivo.Name)"
    }
} catch {
    Write-DualLog "[ERROR] Fallo en la copia: $($_.Exception.Message)"
    $script:processSuccessful = $false
}

# ==============================
# Renombrar archivos
# ==============================
$patrones = $config.Patrones

foreach ($codigo in $patrones) {
    $archivosFiltrados = Get-ChildItem -Path $origen -Filter "Eco_*_${codigo}_*.pdf"
    if ($archivosFiltrados.Count -gt 0) {
        $archivosRenombrados = $true
        foreach ($archivo in $archivosFiltrados) {
            $nuevoCodigo = $config.Renames[$codigo]
            $nuevoNombre = "Lun_${DDMMYY}__${nuevoCodigo}${DDMMYY}.pdf"
            try {
                Rename-Item -Path $archivo.FullName -NewName $nuevoNombre -Force
                $msg = "Renombrado: $($archivo.Name) -> $nuevoNombre"
                Write-DualLog $msg
                $renombradosLog += $msg
            } catch {
                Write-DualLog "[ERROR] Fallo al renombrar $($archivo.Name): $($_.Exception.Message)"
                $script:processSuccessful = $false
            }
        }
    }
}

# Si no renombro nada
if (-not $archivosRenombrados) {
    $msg = "Los nombres estan bien. No se tiene que renombrar ningún archivo Eco_***.pdf."
    Write-DualLog $msg
    $renombradosLog += $msg
}

Write-DualLog "Fin del procesamiento de archivos."
Write-DualLog "-------------------------------------------------------------"

# ==============================
# Enviar correo de notificacion
# ==============================
Write-DualLog "Se envia notificacion por correo y se adjunta log..."
Send-NotificationEmail -success $processSuccessful -logFilePath $dailyLog -renombrados $renombradosLog
