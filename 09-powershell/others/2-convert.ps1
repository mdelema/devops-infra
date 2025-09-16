param (
    [string]$pdfFolder = "E:\Satelites\dir-destino\temp",  # Carpeta con PDFs
    [string]$outputFolder = "E:\Satelites\dir-destino\temp",  # Carpeta para JPGs
    [string]$magickPath = "C:\Program Files\ImageMagick-7.1.1-Q16-HDRI\magick.exe"
    #[string]$exePath = "E:\Satelites\dir-destino\PDFtoJPG.exe"
)

# Crear carpeta de salida si no existe
if (-not (Test-Path $outputFolder)) {
    New-Item -ItemType Directory -Path $outputFolder | Out-Null
}
#   PDFtoJPG.exe
# Obtener y Convertir PDFs a JPG en la carpeta
    #
    # $pdfFiles = Get-ChildItem -Path $pdfFolder -Filter *.pdf
    #
    # foreach ($pdf in $pdfFiles) {
    #     $inputPdfPath = $pdf.FullName
    #     $outputJpgPath = Join-Path $outputFolder ($pdf.BaseName + ".jpg")
    #     Write-Host "Convirtiendo $inputPdfPath a $outputJpgPath..."
    #     # Ejecutar conversión
    #     & $exePath -i $inputPdfPath -0 $outputJpgPath
    # }

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
    $outputJpgPath = Join-Path $destinationPath ($pdf.BaseName)
    Write-DualLog "Copiando de $($pdf.Name) a $($pdf.BaseName).jpg"
    try {
        & "$magickPath" -density 150 "$inputPdfPath" -background white -alpha remove -alpha off -colorspace sRGB -quality 100 "$outputJpgPath"
    } catch {
        Write-DualLog "ERROR al convertir $inputPdfPath - $($_.Exception.Message)"
        $processSuccessful = $false
        continue
    }
#-alpha remove -alpha off: elimina completamente el canal alfa.
#-colorspace sRGB: asegura espacio de color estándar.
}

Write-Host "¡Todas las conversiones completadas!"
