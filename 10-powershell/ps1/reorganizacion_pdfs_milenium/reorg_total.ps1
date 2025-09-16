#---------------------------------------------------#
#   Entra en todas las carpetas y las reorganiza
#---------------------------------------------------#
$raiz = "C:\Users\mdelema\Desktop\pdfSuplementos"   #"\\srvfs06\MileniumPdfSuplementos" 
$carpetas = @("1-Lunes", "2-Martes", "3-Miercoles", "4-Jueves", "5-Viernes", "6-Sabado", "7-Domingo", "Economia", "Empresario", "Ovacion", "Suplementos", "RevistaDomingo", "SShow")
$logFile = Join-Path "$raiz" "reorganization_log.txt"   # "$raiz\test\logs" "reorganization_log.txt"

# Limpiar log anterior si existe
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

    # Recorre archivos de forma recursiva
    Get-ChildItem -Path $rutaCarpeta -File -Recurse | ForEach-Object {
        $archivo = $_.Name

        if ($archivo -match '\d{6}') {
            $fechaTexto = $matches[0]

            try {
                $fecha = [datetime]::ParseExact($fechaTexto, "ddMMyy", $null)
                $anio = $fecha.Year
                $mesNum = "{0:D2}" -f $fecha.Month
                $mesNombre = $fecha.ToString("MMMM", [System.Globalization.CultureInfo]::GetCultureInfo("es-UY"))

                $nombreSinExtension = [System.IO.Path]::GetFileNameWithoutExtension($archivo)
                $subcarpetaDia = $nombreSinExtension.Split("_")[0] + "_" + $fechaTexto

                # Ruta base original de la carpeta (ej: 1-Lunes)
                $carpetaBase = $_.FullName.Replace($raiz + "\", "").Split("\")[0]
                $rutaBase = Join-Path $raiz $carpetaBase
                $destino = Join-Path -Path $rutaBase -ChildPath "$anio\$mesNum-$mesNombre\$subcarpetaDia"

                if (-not (Test-Path $destino)) {
                    New-Item -Path $destino -ItemType Directory -Force | Out-Null
                    Write-Log "[INFO] Carpeta creada: $destino"
                }

                $origenCompleto = $_.FullName
                $destinoCompleto = Join-Path -Path $destino -ChildPath $archivo

                if ($origenCompleto -ne $destinoCompleto) {
                    Move-Item -Path $origenCompleto -Destination $destinoCompleto -Force

                    if ($conteoPorDestino.ContainsKey($destino)) {
                        $conteoPorDestino[$destino] += 1
                    } else {
                        $conteoPorDestino[$destino] = 1
                    }
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
