@{
    # Rutas de origen y destino
    Srv_Origen    = "\\srvfs06\MileniumPdfSuplementos\test"
    Srv_Process  = "E:\Satelites\pdfs-unicos\1-original_PDFs"

    # ==== Configuración FTP ====
    ftpServer     = "172.29.0.50"
    ftpUser       = "usrdiseno"
    ftpPass       = "usrdiseno"
    ftpBasePath   = ""

    # Carpeta temporal local que se va a subir
    tempDir       = "E:\Satelites\pdfs-unicos\compact_PDFs"

    # Carpeta de respaldo
    tempBakDir    = "E:\Satelites\pdfs-unicos\compact_PDFs-bak"

    # Archivo de log
    logFile       = "E:\Satelites\pdfs-unicos\pdf-unico_log.txt"

    # DLL PdfSharp (versión net20)
    PdfSharpDll   = "C:\Tools\PdfSharp\lib\net20\PdfSharp.dll"
}