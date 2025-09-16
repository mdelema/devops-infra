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

# Verificar versiones de Node.js y npm
log "Versión de Node y NPM"
node -v
npm -v


#############################################################################
#   Crear carpeta de necesarias
#############################################################################
echo "#*********************************************************#"
echo " >>> Configurar npm para evitar problemas de permisos <<< "
echo "#*********************************************************#"
log " >> Se crea un directorio para paquetes globales:"
mkdir -p ~/.npm-global

log " >> Se configura npm para usar este directorio"
npm config set prefix '~/.npm-global'

log " >> Se edita el archivo .bashrc y añade la ruta para npm:"
cat <<EOF > ~/.bashrc
export PATH="$HOME/.npm-global/bin:$PATH"
EOF


source ~/.bashrc


#############################################################################
#   Instalar n8n y pm2 globalmente
#############################################################################
echo "📦 Instalando n8n..."
npm install -g n8n


#############################################################################
#   Crear carpeta de proyecto
#############################################################################
echo "📁 Creando carpeta de proyecto ~/n8n..."
mkdir -p ~/n8n
cd ~/n8n


#############################################################################
#   Crear archivo .env con configuración de entorno
#############################################################################
echo "#************************************************#"
echo "      >>> Generando archivo .env <<<             "
echo "#************************************************#"
cat <<EOF > .env
#--------------------------------------------------------------------------------
# Configuración de entorno para n8n con login habilitado (true)
#--------------------------------------------------------------------------------

N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=n8n-io

N8N_HOST=10.1.20.40
N8N_PORT=5678
N8N_SECURE_COOKIE=false
WEBHOOK_URL=http://10.1.20.40:5678
NODE_ENV=production

#--------------------------------------------------------------------------------
# Configuración con dominio
# WEBHOOK_URL=https://test-automatizacion.dominio
#--------------------------------------------------------------------------------
EOF


#############################################################################
#   Configurar n8n como un servicio
#############################################################################
cat <<EOF > /etc/systemd/system/n8n.service
[Unit]
Description=n8n_Automation
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/n8n
EnvironmentFile=/root/n8n/.env
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable n8n
systemctl start n8n
systemctl status n8n

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

dpkg --configure -a
apt --fix-broken install -y
apt install -f


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

echo "#*************************************************************************#"
log  "#	    >>>>    n8n iniciando, por favor espere!!   <<<<                    #"
echo "#*************************************************************************#"
systemctl daemon-reload
systemctl restart n8n.service
exit 0
