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
read -p "¿Deseas continuar con la actualización de MaribaDB? (s/n): " confirm
if [[ "$confirm" != "s" ]]; then
    log "Proceso cancelado por el usuario."
    exit 0
fi

# Detener el script ante cualquier error
set -e  

#############################################################################
#   Remover la versión antigua
#############################################################################
echo "#*************************************************************************#"
echo "#     Detener el servicio...                                              #"
echo "#*************************************************************************#"
systemctl stop mariadb 
systemctl disable mariadb


echo "#*************************************************************************#"
echo "#     Limpiar paquetes no necesarios:                                     #"
echo "#*************************************************************************#"
apt autoremove 
apt autoclean
dpkg --configure -a
apt --fix-broken install
apt autoremove --purge -y
apt autoclean
apt clean


#############################################################################
#   Instalación o Actualización 
#############################################################################
echo "#*************************************************************************#"
echo "#     Descargar y agregar la clave GPG:                                   #"
echo "#*************************************************************************#"
apt install curl -y
curl -LsS https://mariadb.org/mariadb_release_signing_key.asc | sudo tee /etc/apt/trusted.gpg.d/mariadb.asc

echo "#*************************************************************************#"
echo "#     Agregar el repositorio de MariaDB:                                  #"
echo "#*************************************************************************#"
#echo "deb [signed-by=/etc/apt/trusted.gpg.d/mariadb.asc] https://mirror.mariadb.org/repo/$(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/mariadb.list 

echo "#*************************************************************************#"
echo "#     Instalar MariaDB:                                                   #"
echo "#*************************************************************************#"
apt update 
apt install mariadb-server -y

echo "#*************************************************************************#"
echo "#     Verifica que se instaló correctamente:                              #"
echo "#*************************************************************************#"
mariadb --version 
systemctl enable mariadb 
systemctl restart mariadb 
systemctl status mariadb


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
log  "	  >>>>  MARIADB actualizado correctamente... <<<<                        "
log  "            Se reinicia para guardar cambios                               "
echo "#*************************************************************************#"

reboot
