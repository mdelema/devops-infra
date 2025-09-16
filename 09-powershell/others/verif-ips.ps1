# Ruta del archivo Excel
$excelPath = "C:\Users\mdelema\Desktop\Relay.xlsx"

# Crear instancia de Excel
$excel = New-Object -ComObject Excel.Application
$excel.Visible = $false
$excel.DisplayAlerts = $false

# Abrir el archivo
$workbook = $excel.Workbooks.Open($excelPath)
$sheet = $workbook.Sheets.Item(1)

# Empezar desde la fila 2 (saltamos encabezados)
$row = 2

while ($true) {
    $ip = $sheet.Cells.Item($row, 1).Text  # IP está en columna A

    if ([string]::IsNullOrWhiteSpace($ip)) {
        break  # Sale si no hay IP
    }

    Write-Host "🔍 Verificando IP: $ip"

    # Comprobar si responde al ping
    $ping = Test-Connection -ComputerName $ip -Count 1 -Quiet -ErrorAction SilentlyContinue

    if ($ping) {
        $sheet.Cells.Item($row, 4).Value2 = "SI"  # Columna D (Responde)

        try {
            $dns = [System.Net.Dns]::GetHostEntry($ip)
            $sheet.Cells.Item($row, 5).Value2 = $dns.HostName  # Columna E (Nombre DNS)
        } catch {
            $sheet.Cells.Item($row, 6).Value2 = "No Resuelto"
        }
    } else {
        $sheet.Cells.Item($row, 4).Value2 = "NO"  # Columna D
        $sheet.Cells.Item($row, 5).Value2 = "-"   # Columna E
    }

    $row++
}

# Guardar y cerrar
$workbook.Save()
$workbook.Close($true)
$excel.Quit()

# Liberar objetos
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($sheet) | Out-Null
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($workbook) | Out-Null
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null

Write-Host "`n✅ ¡Proceso terminado! Verifica el archivo Excel actualizado." -ForegroundColor Green
