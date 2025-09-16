# Bandera para indicar si se está escribiendo el correo
$script:isSendingEmail = $false

# Variable para rastrear el estado del proceso
$processSuccessful = $true

# Envío de mails
function Send-NotificationEmail {
    param ([bool]$success, [string]$backupDir)
    $script:isSendingEmail = $true
    $smtpClient = New-Object System.Net.Mail.SmtpClient
    $smtpClient.Host = $smtpServer
    $mailMessage = New-Object System.Net.Mail.MailMessage
    $mailMessage.From = $emailFrom
    $mailMessage.To.Add($emailTo)
    $mailMessage.Subject = if ($success) { "Full_Process - [EXITOSO]" } else { "Full_Process - [FALLO]" }
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

# Enviar notificación por correo
Write-Log "Enviando notificacion por correo"
Send-NotificationEmail -success $processSuccessful -backupDir $backupDayDir