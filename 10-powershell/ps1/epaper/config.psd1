@{
    # Milenium
    origen = "\\10.5.3.10\General\Output\DIGITAL\"
    origenPaula = "\\10.5.3.10\General\Output\DIGITAL\PAULA"
    origenPaulaCasa = "\\10.5.3.10\General\Output\DIGITAL\PAULA_CASA"
    origenTuCasaAqui = "\\10.5.3.10\General\Output\DIGITAL\TU_CASA_AQUI"
    origenSabadoShow = "\\10.5.3.10\General\Output\DIGITAL\SABADO_SHOW"
    origenSupANP = "\\10.5.3.10\General\Output\DIGITAL\SUPLEMENTO_ANP"
    
    # Process04
    processPaula = "E:\Satelites\proceso-epaper\temp\Revista-Paula"
    processPaulaCasa = "E:\Satelites\proceso-epaper\temp\Revista-Paula-Casa"
    processTuCasaAqui = "E:\Satelites\proceso-epaper\temp\Revista-Tu-Casa-Aqui"
    processSabadoShow = "E:\Satelites\proceso-epaper\temp\Revista-Sabado-Show"
    processSupANP = "E:\Satelites\proceso-epaper\temp\Suplemento-ANP"
    sourceApplicationCss = "E:\Satelites\proceso-epaper\Application.css"  

    # Configuración del servidor FTP
    ftpServer = "172.29.0.204"
    ftpUser = "usr_paula"
    ftpPass = "u5nfg98-!"
    ftpBasePath = "/"
    ftpSubPathPaula = "Revista-Paula"
    ftpSubPathPaulaCasa = "Revista-Paula-Casa"
    ftpSubPathTuCasaAqui = "Revista-Tu-Casa-Aqui"
    ftpSubPathSabadoShow = "Revista-Sabado-Show"
    ftpSubPathSupANP = "Suplemento-ANP"

    # Configuración del servidor SMTP para notificaciones
    smtpServer = "10.1.20.135"
    emailFrom = "internet@elpais.com.uy"
    emailTo = "TI-Infraestructura@elpais.com.uy, dlorenzo@elpais.com.uy" #, CCaeiro@elpais.com.uy, Impresiones@elpais.com.uy, FMesa@elpais.com.uy"

    # Logs y Backup
    LogDir = "E:\Satelites\proceso-epaper\logs"
    tempBakBase = "E:\Satelites\proceso-epaper\temp-bak"
    
    # Mapeo de nombres de meses a números (dos dígitos)
    months = @{
        "ENERO" = "01"; "FEBRERO" = "02"; "MARZO" = "03"; "ABRIL" = "04"
        "MAYO" = "05"; "JUNIO" = "06"; "JULIO" = "07"; "AGOSTO" = "08"
        "SETIEMBRE" = "09"; "SEPTIEMBRE" = "09" # Se aceptan ambas formas para septiembre
        "OCTUBRE" = "10"; "NOVIEMBRE" = "11"; "DICIEMBRE" = "12"
    }
}