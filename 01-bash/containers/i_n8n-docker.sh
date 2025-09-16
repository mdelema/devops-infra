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
#   Install n8n 
#############################################################################

echo "📁 Creando carpeta de proyecto n8n..."
mkdir -p ~/n8n-docker
cd ~/n8n-docker

echo "📝 Generando archivo docker-compose.yml..."
cat > docker-compose.yml <<EOF
version: '3.7'

services:
  n8n:
    image: n8nio/n8n
    restart: always
    ports:
      - "5678:5678"
    environment:
      - DB_TYPE=sqlite
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=admin
      - N8N_BASIC_AUTH_PASSWORD=admin123
      - N8N_HOST=10.1.20.40
#      - N8N_PORT=5678
      - N8N_SECURE_COOKIE=false
      - WEBHOOK_URL=http://test-automatizacion-docker/
    volumes:
      - n8n_data:/home/node/.n8n

volumes:
  n8n_data:
EOF

echo "▶️ Iniciando n8n con Docker Compose..."
docker compose up -d

echo "✅ n8n está corriendo en http://<<IP_del_Server>>:5678"
echo "🔐 Usuario: admin | Contraseña: admin123"



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


#############################################################################
#           FIN DE LA EJECU
#############################################################################
echo "#*************************************************************************#"
echo "#	    Proceso de instalación completado con éxito.                        #"
echo "#	                FIN DE LA EJECUCION                                     #"
echo "#*************************************************************************#"

exit 0
