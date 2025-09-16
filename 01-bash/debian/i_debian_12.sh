#!/bin/bash
# Redirección de logs
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
read -p "¿Deseas continuar con la actualización de Debian 11 a 12? (s/n): " confirm
if [[ "$confirm" != "s" ]]; then
    log "Proceso cancelado por el usuario."
    exit 0
fi

# Detener el script ante cualquier error
set -e  

#############################################################################
#   Actualización a Debian 12 (Bookworm)
#############################################################################
echo "#*************************************************************************#"
echo "#     Se procede a actalizar a Debian 12...                               #"
echo "#*************************************************************************#"

# Agregar dentro del archivo /icinga.list las siguientes líneas
cat <<EOF > /etc/apt/sources.list.d/icinga.list
#****************************************************************************************
# Debian 10
#deb http://packages.icinga.com/debian icinga-buster main

# Debian 11
#deb http://packages.icinga.com/debian icinga-bullseye main

# Debian 12
deb http://packages.icinga.com/debian icinga-bookworm main

#****************************************************************************************
EOF

# Configurar repositorios para Debian 12
cat <<EOF > /etc/apt/sources.list
#****************************************************************************************
# Repositorios principales
deb http://ftp.es.debian.org/debian/ bookworm main contrib non-free-firmware 
deb-src http://ftp.es.debian.org/debian/ bookworm main contrib non-free-firmware

# Actualizaciones de seguridad
deb http://security.debian.org/debian-security bookworm-security main contrib non-free-firmware 
deb-src http://security.debian.org/debian-security bookworm-security main contrib non-free-firmware

# Actualizaciones regulares
deb http://ftp.es.debian.org/debian/ bookworm-updates main contrib non-free-firmware 
deb-src http://ftp.es.debian.org/debian/ bookworm-updates main contrib non-free-firmware

# Backports
deb http://ftp.es.debian.org/debian/ bookworm-backports main contrib non-free-firmware 
deb-src http://ftp.es.debian.org/debian/ bookworm-backports main contrib non-free-firmware

#****************************************************************************************
EOF

echo "#*************************************************************************#"
echo "# 	Se actualizan los cambios a Debian 12 y se limpia el sistema:       #"
echo "#*************************************************************************#"
if ! (apt update && apt upgrade -y); then
    error "Error al actualizar la lista de paquetes."
fi
apt full-upgrade -y
apt autoremove --purge -y
apt clean

echo "#*************************************************************************#"
echo "#     Debian 12 instalado correctamente. | versión instalada              #"
echo "#*************************************************************************#"
cat /etc/os-release

echo "#*************************************************************************#"
echo "#	    Verifica que el sistema esté en un estado estable:                  #"
echo "#*************************************************************************#"
dpkg --configure -a
apt --fix-broken install -y

echo "#*************************************************************************#"
echo "#	    Se reinicia para aplicar los cambios:                               #"
echo "#*************************************************************************#"
reboot
