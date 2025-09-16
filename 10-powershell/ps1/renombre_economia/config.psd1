@{
    # Base paths
    Origen = "\\srvfs06\MileniumPdfSuplementos\test"
    SubfolderEconomia = "\\srvfs06\MileniumPdfSuplementos\test\Economia"
    LogDir = "E:\Satelites\renombre-economia\logs"

    # Log file names
    LogDiarioPrefix = "log_diario_"
    LogHistoricoName = "log_historico.txt"
    
    # File patterns for renaming
    Patrones = @("014", "024", "034", "044")
    
    # SMTP settings
    SmtpServer = "10.1.20.135"
    EmailFrom = "internet@elpais.com.uy"
    EmailTo = "TI-Infraestructura@elpais.com.uy, mdaguardia@elpais.com.uy"	#"mdelema@elpais.com.uy"

    # Códigos de renombrado
    Renames = @{
        "014" = "0104E"
        "024" = "0204E"
        "034" = "0304E"
        "044" = "0404E"
    }
}