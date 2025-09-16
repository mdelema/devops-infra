@{
    sourcePath		    = "\\srvfs06\MileniumPdfSuplementos"
    destinationPath	    = "E:\Satelites\portada-impresa\temp"
    backupPath		    = "E:\Satelites\portada-impresa\temp-bak"
    logFile		        = "E:\Satelites\portada-impresa\process_log.txt"
    dailyLog		    = "daily_log.txt"

    ftpServer		    = "172.29.0.164"
    ftpUser		        = "publicadortareas"
    ftpPass		        = "u5nfg98"
    ftpBasePath		    = "/printed-home"

    smtpServer		    = "10.1.20.135"
    emailFrom		    = "internet@elpais.com.uy"
	emailTo 			= "DAres@elpais.com.uy, odonline@gmail.com, TI-Infraestructura@elpais.com.uy, mpenaflor@elpais.com.uy"

    magickPath		    = "C:\Program Files\ImageMagick-7.1.1-Q16-HDRI\magick.exe"
    deleteAfterUpload	= $true
    retryOnFail		    = $true
    maxRetries		    = 3
}