#!/bin/bash

#-----------------------------------------------------------------------------------#
# Autor: mdelema
# Motivo:
#   Tipo = 2
#   Origen = mautic-segments-update-Requiere_Accion
#   Descripcion = El proceso se está ejecutando más del tiempo esperado, revisar.
#-----------------------------------------------------------------------------------#

# Rutas
FECHA=$(date +%F)
LOG_ORIGINAL="/var/log/mautic/update-segments-list.log"
OUTPUT_DIR="/root/scripts/long_segment"
LOG_TEMP="$OUTPUT_DIR/ultimas_lineas.txt"
OUTPUT_FILE="$OUTPUT_DIR/long_segment_$FECHA.txt"

# Crear carpeta si no existe
mkdir -p "$OUTPUT_DIR"

# Paso 1: Guardar últimas 1000 líneas del log
tail -n 1000 "$LOG_ORIGINAL" > "$LOG_TEMP"

# Paso 2: Variables de control
start_time=""
end_time=""
segmento=""
> "$OUTPUT_FILE"  # Vaciar archivo anterior si existe

bloque_lines=()

# Leer línea por línea
while IFS= read -r linea || [ -n "$linea" ]; do
    # Agregar línea al bloque temporal
    bloque_lines+=("$linea")

    # Si es separador de bloque
    if [[ "$linea" == "****" ]]; then
        # Procesar bloque anterior si existe
        if [[ -n "$start_time" && -n "$end_time" ]]; then
            start_epoch=$(date -d "${start_time//_/ }" +%s)
            end_epoch=$(date -d "${end_time//_/ }" +%s)
            diff_sec=$((end_epoch - start_epoch))

            if (( diff_sec > 900 )); then  # 15 minutos = 900 segundos
                hrs=$((diff_sec / 3600))
                mins=$(((diff_sec % 3600) / 60))
                secs=$((diff_sec % 60))
                printf "%s = %02d:%02d:%02d\n" "$segmento" "$hrs" "$mins" "$secs" >> "$OUTPUT_FILE"

                # Buscar línea de detalle en el bloque
                detalle=$(printf "%s\n" "${bloque_lines[@]}" | grep -E "Rebuilding contacts for segment")
                if [[ -n "$detalle" ]]; then
                    echo "- $detalle" >> "$OUTPUT_FILE"
                fi
            fi
        fi

        # Resetear para el nuevo bloque
        start_time=""
        end_time=""
        segmento=""
        bloque_lines=()
        continue
    fi

    # Detectar líneas de timestamp
    if [[ "$linea" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}:[0-9]{2}:[0-9]{2}$ ]]; then
        if [[ -z "$start_time" ]]; then
            start_time="$linea"
        fi
        end_time="$linea"
    fi

    # Detectar "Procesando segmento"
    if [[ "$linea" =~ Procesando\ segmento\ ([0-9]+) ]]; then
        segmento="segmento ${BASH_REMATCH[1]}"
    fi
done < "$LOG_TEMP"

# Mensaje de finalización
if [ -s "$OUTPUT_FILE" ]; then
    echo "Análisis completado. Los segmentos largos se han registrado en $OUTPUT_FILE"
else
    echo "Análisis completado. No se encontraron segmentos que demoraran más de 15min."
fi

echo "Proceso completo."
echo "Revisar: $OUTPUT_FILE"
