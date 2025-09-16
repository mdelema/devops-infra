@{
    sourcePath		    = "\\Srv_Origen\Directorio_Sec"
    destinationPath	    = "E:\Satelites\dir-destino\temp"
    backupPath		    = "E:\Satelites\dir-destino\temp-bak"
    logFile		        = "E:\Satelites\dir-destino\process_log.txt"
    dailyLog		    = "daily_log.txt"

    ftpServer		    = "172.29.0.164"
    ftpUser		        = "publicadortareas"
    ftpPass		        = "u5nfg98"
    ftpBasePath		    = "/printed-home"

    smtpServer		    = "10.1.20.135"
    emailFrom		    = "internet@dominio"
	emailTo 			= "DAres@dominio, odonline@gmail.com, mail-infra@dominio, mpenaflor@dominio"

    magickPath		    = "C:\Program Files\ImageMagick-7.1.1-Q16-HDRI\magick.exe"
    deleteAfterUpload	= $true
    retryOnFail		    = $true
    maxRetries		    = 3
}