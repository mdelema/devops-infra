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
#   Actualiza Debian y limpia el sistema
#############################################################################
echo "#*************************************************************************#"
echo "#     Actualizando paquetes del sistema...                                #"
echo "#*************************************************************************#"

if ! (apt update && apt upgrade -y); then
    error "Error al actualizar la lista de paquetes."
fi
apt full-upgrade -y
apt autoremove --purge -y
apt clean


echo "#*************************************************************************#"
echo "#	    Verifica que el sistema esté en un estado estable:                  #"
echo "#*************************************************************************#"
dpkg --configure -a
apt --fix-broken install -y
log "Servicio estable"


echo "#*************************************************************************#"
echo "#     Recargar systemd:                                                   #"
echo "#*************************************************************************#"
systemctl daemon-reexec
systemctl daemon-reload
log "Systemd ok"


#############################################################################
#   Verificación de paquetes residuales (rc)
#############################################################################
echo "#*************************************************************************#"
echo "#	    Verificando paquetes residuales configurados...                     #"
echo "#*************************************************************************#"
# Verificar sin confirmación
residual_packages=$(dpkg -l | awk '/^rc/ {print $2}')

if [ -n "$residual_packages" ]; then
    log "Se encontraron los siguientes paquetes residuales:"
    echo "$residual_packages" | xargs -r dpkg --purge
    log "Paquetes residuales eliminados correctamente."
else
    log "No se encontraron paquetes residuales configurados."
fi

echo "#*************************************************************************#"
log  "		    Se han actualizado todos los paquetes del			"
log  "		     >>>	Sistema Operativo	<<<			"
echo "#*************************************************************************#"
