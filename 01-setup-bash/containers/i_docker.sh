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
#   Install Docker
#############################################################################
echo "📦 Instalando paquetes necesarios..."
apt install -y ca-certificates curl gnupg lsb-release

echo "🔐 Agregando clave GPG de Docker..."
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | \
gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo "📁 Agregando repositorio de Docker..."
echo \
  "deb [arch=$(dpkg --print-architecture) \
  signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list

echo "🔄 Actualizando repositorios..."
apt update

echo "🐳 Instalando Docker Engine y plugins..."
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "✅ Habilitando e iniciando Docker..."
systemctl enable docker
systemctl start docker

echo "👤 Agregando el usuario '$SUDO_USER' al grupo docker..."
usermod -aG docker "$SUDO_USER"

echo "🎉 Docker se ha instalado correctamente. Reiniciá sesión o ejecutá: newgrp docker"


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
