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
#   Actualizar a PHP8.3
#############################################################################

log "Actualiza y detiene las versiones de PHP exixstentes:"
#systemctl stop php*-fpm.service
apt autoremove -y
apt clean
apt update

log "Comienza la actualización  de PHP"
# Agregar repositorio de Ondřej Surý (si no está)
if ! apt-cache policy | grep -q 'packages.sury.org'; then
    echo "-> Agregando repositorio de PHP actualizado..."
    apt update
    apt install -y lsb-release ca-certificates apt-transport-https software-properties-common gnupg2
    wget -qO - https://packages.sury.org/php/apt.gpg | gpg --dearmor -o /usr/share/keyrings/php.gpg
    echo "deb [signed-by=/usr/share/keyrings/php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php.list
    apt update
fi

# Detectar última versión de PHP disponible
LATEST=$(apt-cache search ^php[0-9] | grep -oP '^php\K[0-9]\.[0-9]' | sort -Vr | head -n1)

echo "-> Última versión de PHP detectada: $LATEST"

# Lista de extensiones a instalar
EXTENSIONS=(cli fpm mysql curl xml mbstring zip gd soap tidy ldap)

# Construir lista completa de paquetes
PACKAGES="php$LATEST"
for ext in "${EXTENSIONS[@]}"; do
    PACKAGES+=" php$LATEST-$ext"
done

echo "-> Instalando: $PACKAGES"
apt install -y $PACKAGES

#curl -sSL https://packages.sury.org/php/README.txt | sudo bash -x

log "Verifica la versión de PHP:"
php -v


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
#   Reiniciar los servicios
#############################################################################
echo "#*************************************************************************#"
echo "#	    Se reinicia para aplicar los cambios:                               #"
echo "#*************************************************************************#"
systemctl daemon-reload

reboot
