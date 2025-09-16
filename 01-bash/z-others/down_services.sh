#!/bin/bash

# Respaldo de logs
exec > >(tee -i /var/log/upgrade_debian.log)
exec 2>&1

# Función para mostrar mensajes de estado
log() {
    echo -e "\e[1;32m[INFO]\e[0m $1"
}

error() {
    echo -e "\e[1;31m[ERROR]\e[0m $1" >&2
    exit 1
}

# Validación de permisos de root
if [ "$EUID" -ne 0 ]; then
    error "Este script debe ejecutarse como root."
fi

# Detener el script ante cualquier error
set -e


#############################################################################
#   Bajando todos los servicios
#############################################################################
echo "Levantando del servicio cron..."
echo $(systemctl disabled cron)
echo $(systemctl stop cron)
echo $(systemctl status cron | grep "Active:")

echo "Levantando servicio snmpd..."
echo $(systemctl disabled snmpd)
echo $(systemctl stop snmpd)
echo $(systemctl status snmpd | grep "Active:")

echo "Levantando del servicio php8.3-fpm..."
echo $(systemctl disabled php8.3-fpm)
echo $(systemctl stop php8.3-fpm)
echo $(systemctl status php8.3-fpm | grep "Active:")

echo "Levantando del servicio nginx..."
echo $(systemctl disabled nginx)
echo $(systemctl stop nginx)
echo $(systemctl status nginx | grep "Active:")


#############################################################################
#           FIN DE LA EJECU
#############################################################################
echo "#*************************************************************************#"
echo "#	    Proceso de baja de servicios finalizado con exito.                  #"
echo "#	                FIN DE LA EJECUCION                                     #"
echo "#*************************************************************************#"

exit 0
