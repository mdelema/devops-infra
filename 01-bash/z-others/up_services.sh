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
#   Levanto todos los servicios
#############################################################################
echo "Levantando del servicio cron..."
echo $(systemctl enable cron)
echo $(systemctl start cron)
echo $(systemctl status cron | grep "Active:")

echo "Levantando servicio snmpd..."
echo $(systemctl enable snmpd)
echo $(systemctl start snmpd)
echo $(systemctl status snmpd | grep "Active:")

echo "Levantando del servicio php8.3-fpm..."
echo $(systemctl enable php8.3-fpm)
echo $(systemctl start php8.3-fpm)
echo $(systemctl status php8.3-fpm | grep "Active:")

echo "Levantando del servicio nginx..."
echo $(systemctl enable nginx)
echo $(systemctl start nginx)
echo $(systemctl status nginx | grep "Active:")


#############################################################################
#   Actualizar paquetes.
#############################################################################
echo "#*************************************************************************#"
echo "#     Actualizar la lista de paquetes con apt y manejar errores           #"
echo "#*************************************************************************#"
if ! (apt update && apt upgrade -y); then
    error "Error al actualizar la lista de paquetes."
fi
apt full-upgrade -y
apt autoremove --purge -y
apt clean
dpkg --configure -a
apt --fix-broken install -y
log "Servicio estable"
systemctl daemon-reload

#############################################################################
#   Verificación de paquetes residuales (rc)
#############################################################################
echo "#*************************************************************************#"
echo "#	    Verificando paquetes residuales configurados...                     #"
echo "#*************************************************************************#"
# Verificar si hay paquetes en estado 'rc'
residual_packages=$(dpkg -l | awk '/^rc/ {print $2}')

if [ -n "$residual_packages" ]; then
    log "Se encontraron los siguientes paquetes residuales:"
    echo "$residual_packages" | xargs -r dpkg --purge
    log "Paquetes residuales eliminados correctamente."
else
    log "No se encontraron paquetes residuales configurados."
fi


#############################################################################
#         >>>>  CONSULTAS  <<<<
#############################################################################
echo "Status del servicio cron..."
echo $(systemctl status cron | grep "Active:") - $(systemctl is-enabled cron)

echo "Status servicio snmpd..."
echo $(systemctl status snmpd | grep "Active:") - $(systemctl is-enabled snmpd)

echo "Status servicio php8.3-fpm..."
echo $(systemctl status php8.3-fpm | grep "Active:") - $(systemctl is-enabled php8.3-fpm)

echo "Status servicio nginx..."
echo $(systemctl status nginx | grep "Active:") - $(systemctl is-enabled nginx)

#############################################################################
#           FIN DE LA EJECU
#############################################################################
echo "#*************************************************************************#"
echo "#	    Proceso de actualización completado con éxito.                      #"
echo "#	                FIN DE LA EJECUCION                                     #"
echo "#*************************************************************************#"

exit 0


# --------------------------------------------------------------------------#
# > user: infradmin
# > pass: Mau$1c-!"#
# --------------------------------------------------------------------------#
