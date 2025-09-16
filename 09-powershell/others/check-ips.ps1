param (
    [string]$ExcelPath = "C:\Users\mdelema\Desktop\ips.xlsx",
    [string]$TxtPath = "C:\Users\mdelema\Desktop\ips.txt"
)

function Test-IP {
    param (
        [string]$ip
    )

    $result = [ordered]@{
        IP         = $ip
        Responde   = "NO"
        NombreDNS  = "-"
    }

    try {
        $ping = Test-Connection -ComputerName $ip -Count 1 -Quiet -ErrorAction SilentlyContinue

        if ($ping) {
            $result["Responde"] = "SI"
            try {
                $dns = [System.Net.Dns]::GetHostEntry($ip)
                $result["NombreDNS"] = $dns.HostName
            } catch {
                $result["NombreDNS"] = "No Resuelto"
            }
        }
    } catch {
        # No hace falta, ya devuelve NO por defecto
    }

    return $result
}

### 1) Verificar IPs desde EXCEL ###
if (Test-Path $ExcelPath) {
    Write-Host "📘 Procesando IPs desde Excel: $ExcelPath"

    $excel = New-Object -ComObject Excel.Application
    $excel.Visible = $false
    $excel.DisplayAlerts = $false

    $workbook = $excel.Workbooks.Open($ExcelPath)
    $sheet = $workbook.Sheets.Item(1)

    $row = 2
    while ($true) {
        $ip = $sheet.Cells.Item($row, 1).Text
        if ([string]::IsNullOrWhiteSpace($ip)) {
            break
        }

        Write-Host "➡️ IP: $ip"

        $result = Test-IP -ip $ip

        $sheet.Cells.Item($row, 4).Value2 = $result.Responde        # Columna D
        $sheet.Cells.Item($row, 5).Value2 = $result.NombreDNS       # Columna E

        $row++
    }

    $workbook.Save()
    $workbook.Close($true)
    $excel.Quit()

    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($sheet) | Out-Null
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($workbook) | Out-Null
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null

    Write-Host "`n✅ Excel actualizado correctamente.`n"
}

### 2) Verificar IPs desde .TXT ###
if (Test-Path $TxtPath) {
    Write-Host "📄 Procesando IPs desde archivo TXT: $TxtPath"

    $salida = @()
    Get-Content $TxtPath | ForEach-Object {
        $ip = $_.Trim()
        if (-not [string]::IsNullOrWhiteSpace($ip)) {
            Write-Host "➡️ IP: $ip"
            $resultado = Test-IP -ip $ip
            $salida += [PSCustomObject]$resultado
        }
    }

    # Guardar resultados en un CSV al lado del TXT
    $outputPath = [System.IO.Path]::ChangeExtension($TxtPath, ".csv")
    $salida | Export-Csv -Path $outputPath -NoTypeInformation -Encoding UTF8

    Write-Host "`n✅ Resultados guardados en: $outputPath`n"
}

Write-Host "🎉 Proceso finalizado." -ForegroundColor Green
