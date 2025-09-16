#!/bin/bash

#-------------------------------------------------------------------------------------#
# Autor: mdelema
#   - Script para actualizar Ubuntu LTS automáticamente y de forma segura.
#-------------------------------------------------------------------------------------#

LOG_FILE="/var/log/upgrade_ubuntu.log"

# Función para imprimir y registrar mensajes
log() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

# Requiere root
if [ "$EUID" -ne 0 ]; then
    echo "Este script debe ejecutarse como root."
    exit 1
fi

# Confirmación inicial
read -p "¿Deseas continuar con la actualización? (s/n): " confirm
if [[ "$confirm" != "s" ]]; then
    log "Proceso cancelado por el usuario."
    exit 0
fi

# Mostrar versión actual
log "[INFO] Versión actual: $(lsb_release -d | cut -f2)"
log "[INFO] Iniciando proceso de actualización..."

# Actualizar sistema actual
log "[INFO] Actualizando sistema actual..."
apt update && apt upgrade -y 
apt dist-upgrade -y 
apt autoremove --purge -y
log "[OK] Sistema actualizado."

# Verificar e instalar update-manager-core
log "[INFO] Verificando paquete update-manager-core..."
apt install -y update-manager-core

# Asegurar que el Prompt sea lts
log "[INFO] Asegurando que Prompt=lts esté en /etc/update-manager/release-upgrades"
sed -i 's/^Prompt=.*/Prompt=lts/' /etc/update-manager/release-upgrades

# Verificar si hay nueva versión disponible
NEW_RELEASE=$(do-release-upgrade -c | grep -oP "New release '\K[^']+")
if [[ -z "$NEW_RELEASE" ]]; then
    log "[INFO] No hay nuevas versiones disponibles. Ya estás en la última LTS."
    exit 0
fi

log "[INFO] Todo listo. Iniciando actualización a Ubuntu $NEW_RELEASE..."
sleep 2

# Ejecutar la actualización y loguear
do-release-upgrade | tee -a "$LOG_FILE"

# Para automático sin interacción:
# export DEBIAN_FRONTEND=noninteractive
# export DPKG_OPTIONS="--force-confdef --force-confold"
# do-release-upgrade -f DistUpgradeViewNonInteractive | tee -a "$LOG_FILE"

# Mostrar nueva versión y reiniciar
log "[FIN] Actualización Finalizada OK. Nueva versión:"
log "[INFO] $(lsb_release -d | cut -f2)"
log "[INFO] Reiniciando el sistema..."
reboot
