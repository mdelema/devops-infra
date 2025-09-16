# $raiz = "\\Srv_Origen\Directorio_Sec"
# $carpetas = @("1-Lunes", "2-Martes", "3-Miercoles", "4-Jueves", "5-Viernes", "6-Sabado", "7-Domingo", "Economia", "Empresario", "Ovacion", "Suplementos", "RevistaDomingo", "SShow")
# $logFile = Join-Path "$raiz\test\logs" "reorganization_log.txt" 

$raiz = "C:\Users\mdelema\Desktop\pdfSuplementos"   #"\\Srv_Origen\Directorio_Sec" 
$carpetas = @("1-Lunes", "2-Martes", "3-Miercoles", "4-Jueves", "5-Viernes", "6-Sabado", "7-Domingo", "Economia", "Empresario", "Ovacion", "Suplementos", "RevistaDomingo", "SShow")

$fechaHoy = Get-Date -Format "yyyy-MM-dd"
$logFile = Join-Path "$raiz\test\logs" "reorganization_log_$fechaHoy.txt"

# Crear carpeta de logs si no existe
$logDir = Split-Path $logFile
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

# Limpiar log anterior del mismo día si existe
if (Test-Path $logFile) { Remove-Item $logFile -Force }

function Write-Log {
    param ([string]$mensaje)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $linea = "[$timestamp] $mensaje"
    Write-Output $linea
    Add-Content -Path $logFile -Value $linea
}

foreach ($carpeta in $carpetas) {
    $rutaCarpeta = Join-Path $raiz $carpeta

    if (-Not (Test-Path $rutaCarpeta)) {
        Write-Log "[WARN] Carpeta no encontrada: $rutaCarpeta"
        continue
    }

    $conteoPorDestino = @{}

    Get-ChildItem -Path $rutaCarpeta -File | ForEach-Object {

        $archivo = $_.Name

        if ($archivo -match '\d{6}') {
            $fechaTexto = $matches[0]

            try {
                $fecha = [datetime]::ParseExact($fechaTexto, "ddMMyy", $null)
                $anio = $fecha.Year
                $mesNum = "{0:D2}" -f $fecha.Month
                $mesNombre = $fecha.ToString("MMMM", [System.Globalization.CultureInfo]::GetCultureInfo("es-UY"))
                $destinoMes = Join-Path -Path $rutaCarpeta -ChildPath "$anio\$mesNum-$mesNombre"

                # Crear subcarpeta diaria basada en el nombre del archivo
                $nombreSinExtension = [System.IO.Path]::GetFileNameWithoutExtension($archivo)
                $subcarpetaDia = $nombreSinExtension.Split("_")[0] + "_" + $fechaTexto
                $destino = Join-Path -Path $destinoMes -ChildPath $subcarpetaDia

                if (-not (Test-Path $destino)) {
                    New-Item -Path $destino -ItemType Directory | Out-Null
                    Write-Log "[INFO] Carpeta creada: $destino"
                }

                $origenCompleto = $_.FullName
                $destinoCompleto = Join-Path -Path $destino -ChildPath $archivo

                Move-Item -Path $origenCompleto -Destination $destinoCompleto -Force

                if ($conteoPorDestino.ContainsKey($destino)) {
                    $conteoPorDestino[$destino] += 1
                } else {
                    $conteoPorDestino[$destino] = 1
                }

            } catch {
                Write-Log "[ERROR] Fallo al procesar fecha '$fechaTexto' en archivo $archivo"
            }
        } else {
            Write-Log "[WARN] No se encontró fecha válida en: $archivo"
        }
    }

    foreach ($destino in $conteoPorDestino.Keys) {
        $cantidad = $conteoPorDestino[$destino]
        $subcarpeta = "\" + (Split-Path $destino -Leaf)
        Write-Log "[OK] Se movieron $cantidad archivo(s) a $subcarpeta"
    }

    Write-Log "---------- FIN del PROCESO OK ----------"
}
