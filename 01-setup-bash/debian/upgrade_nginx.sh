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
#       Respaldar Archivos
#############################################################################
mkdir -p /root/tpl-m/respaldos

archivos=(
    "/etc/nginx/nginx.conf"
)

for archivo in "${archivos[@]}"; do
    if [ -f "$archivo" ]; then
        cp "$archivo" /root/actualizacion/respaldos
        log "Respaldo de $archivo completado."
    else
        log "Archivo $archivo no encontrado, se omite."
    fi
done

log "Se copian carpetas importantes"
cp -r /etc/nginx/cert/ /root/tpl-m/respaldos
cp -r /etc/nginx/sites-available/ /root/tpl-m/respaldos


#############################################################################
#	Actualizar Nginx
#############################################################################
echo "#*************************************************************************#"
echo "#     Se procede a actualizar Nginx...                                    #"
echo "#*************************************************************************#"
# Desisntalar:
systemctl disable nginx.service
apt remove nginx nginx-common -y
apt autoremove
apt autoclean

# Instalar y Actualizar.
apt update
apt install nginx -y
systemctl enable nginx.service
systemctl start nginx.service


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

echo "#*************************************************************************#"
echo "#	    Verifica que el sistema esté en un estado estable:                  #"
echo "#*************************************************************************#"
dpkg --configure -a
apt --fix-broken install -y
log "Servicio estable"


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
echo "#	    NGINX actualizado correctamente...                                  #"
echo "#*************************************************************************#"
log "Se reinicia para guardar cambios"

reboot
