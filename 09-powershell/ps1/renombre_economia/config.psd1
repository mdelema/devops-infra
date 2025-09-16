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
    EmailFrom = "internet@dominio"
    EmailTo = "mail-infra@dominio, mdaguardia@dominio"	#"mdelema@dominio"

    # Códigos de renombrado
    Renames = @{
        "014" = "0104E"
        "024" = "0204E"
        "034" = "0304E"
        "044" = "0404E"
    }
}