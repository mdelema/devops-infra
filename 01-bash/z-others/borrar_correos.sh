#!/bin/bash

# Redirección de logs
exec > >(tee -i /var/log/borrar_correos.log)
exec 2>&1

log() { echo -e "\e[1;32m[INFO]\e[0m $1"; }
error() { echo -e "\e[1;31m[ERROR]\e[0m $1" >&2; exit 1; }

if [ "$EUID" -ne 0 ]; then error "Este script debe ejecutarse como root."; fi
set -e

LOGFILE="/var/log/borrar_correos.log"
EMAIL="mail-infra@dominio"
HOSTNAME=$(hostname -f)

# === Envio de correos  ===
send_notification(){
    ALERTTYPE=$1
    APPNAME=$2
    MAILTO=$3
    BODY=$4

    if [ $ALERTTYPE != 3 ]; then
        APPNAME="$APPNAME-Requiere_Accion"
    fi

    CMDGET=W
    BODY=$(echo "$BODY" | od -t x1 -A n | tr " " %)
    BODY=$(echo "$BODY" | tr -d "\n")

    URL="http://regsuc.dominio/RegSucesosWS/Registrar.asmx/AddSuceso"
    URLPARAMS="pTipoSuceso=$ALERTTYPE&pOrigenHostName=$(hostname)&pOrigenAppName=$APPNAME&pDescripcion=$BODY&pMailTo=$MAILTO"

    if [ $CMDGET = 'W' ] ; then
        wget -U iceweasel $URL --post-data $URLPARAMS -S -O /dev/null
    fi
    if [ $CMDGET = 'C' ] ; then
        curl -d $URLPARAMS $URL
    fi
}

mkdir -p /root/scripts/temp
mkdir -p /root/scripts/temp/backup

declare -A usuarios=(
   ["administrador"]="/home/administrador/Maildir"
   ["dmarc"]="/home/dmarc/Maildir"
   ["dmarcold01"]="/home/dmarcold01/Maildir"
   ["dmarcold02"]="/home/dmarcold02/Maildir"
   ["envio"]="/home/envio/Maildir"
   ["envio1"]="/home/envio1/Maildir"
   ["envio2"]="/home/envio2/Maildir"
)

FECHA=$(date +%Y-%m-%d)
RESUMEN="Resumen limpieza de correos - $FECHA\n"
RESUMEN+="----------------------------------------\n"
RESUMEN+="Cuenta       NEW   CUR   TOTAL   MB Liberados\n"
RESUMEN+="----------------------------------------\n"

# Guardar espacio usado antes
espacio_antes_total=$(df --output=used / | tail -1)

for cuenta in "${!usuarios[@]}"; do
    find "${usuarios[$cuenta]}/new" -type f -print > "/root/scripts/temp/lista-new-$cuenta.txt"
    find "${usuarios[$cuenta]}/cur" -type f -print > "/root/scripts/temp/lista-cur-$cuenta.txt"

    count_new=$(wc -l < "/root/scripts/temp/lista-new-$cuenta.txt")
    count_cur=$(wc -l < "/root/scripts/temp/lista-cur-$cuenta.txt")
    total=$((count_new + count_cur))

    # Crear backup
    for carpeta in new cur; do
        lista="/root/scripts/temp/lista-$carpeta-$cuenta.txt"
        tarfile="/root/scripts/temp/backup/${carpeta}-${cuenta}-$FECHA.tar.gz"
        [ -s "$lista" ] && tar -czf "$tarfile" -T "$lista"
    done

    # Calcular espacio antes/después aproximado por cuenta
    espacio_antes=$(du -sb "${usuarios[$cuenta]}" | awk '{print $1}')
    cat "/root/scripts/temp/lista-new-$cuenta.txt" "/root/scripts/temp/lista-cur-$cuenta.txt" | xargs -r rm -v
    espacio_despues=$(du -sb "${usuarios[$cuenta]}" | awk '{print $1}')
    espacio_liberado=$(( (espacio_antes - espacio_despues) / 1024 ))  # en KB

    # Agregar fila a resumen
    RESUMEN+=$(printf "%-12s %5d %5d %6d %12d\n" "$cuenta" "$count_new" "$count_cur" "$total" "$espacio_liberado")
done

# Limpiar backups antiguos (>1 año)
find /root/scripts/temp/backup -type f -name "*.tar.gz" -mtime +365 -exec rm -f {} \;

# Calcular espacio liberado total
espacio_despues_total=$(df --output=used / | tail -1)
espacio_liberado_total=$(( (espacio_antes_total - espacio_despues_total) / 1024 )) # MB
RESUMEN+="----------------------------------------\n"
RESUMEN+="Total espacio liberado: ${espacio_liberado_total} MB\n"

# Enviar notificación vía RegSucesos
ALERTTYPE=3
APPNAME="LimpiezaCorreos"
MAILTO="$EMAIL"
BODY="$RESUMEN"

send_notification $ALERTTYPE $APPNAME $MAILTO "$BODY"

log "Proceso finalizado con éxito."
