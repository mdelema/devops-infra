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

# Confirmación inicial
read -p "¿Deseas continuar con la actualización de Debian? (s/n): " confirm
if [[ "$confirm" != "s" ]]; then
    log "Proceso cancelado por el usuario."
    exit 0
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

#############################################################################
#   Actualiza Debian y limpia el sistema
#############################################################################
echo "#*************************************************************************#"
echo "#     Borrando paquetes del sistema...                                    #"
echo "#*************************************************************************#"
apt-get remove --purge postgres*
apt-get autoremove
apt-get clean

#############################################################################
#   Install MongoDB.js
#############################################################################
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
echo "deb http://apt.postgresql.org/pub/repos/apt/ bookworm-pgdg main" | sudo tee /etc/apt/sources.list.d/pgdg.list
apt update && apt upgrade -y
apt install postgresql postgresql-contrib

echo " Levantando el Servicio..."
systemctl start postgresql
systemctl enable postgresql
systemctl status postgresql

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
    echo "$residual_packages"

    # Confirmación para purgar paquetes residuales
    read -p "¿Deseas eliminar estos paquetes residuales con 'dpkg --purge'? (s/n): " confirm_purge
    if [[ "$confirm_purge" == "s" ]]; then
        echo "$residual_packages" | xargs -r dpkg --purge
        log "Paquetes residuales eliminados correctamente."
    else
        log "Eliminación de paquetes residuales cancelada por el usuario."
    fi
else
    log "No se encontraron paquetes residuales configurados."
fi


echo "#*************************************************************************#"
echo "#	    >>>>    Se reinicia para aplicar los cambios    <<<<                #"
echo "#*************************************************************************#"
reboot
