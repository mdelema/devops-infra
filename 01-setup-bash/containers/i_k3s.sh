#!/bin/bash
# Autor: mdelema
# Objetivo: Instalar k3s en Debian (servidor single-node)

set -e

# --- Validaciones ---
if [ "$(id -u)" -ne 0 ]; then
    echo "Este script debe ejecutarse como root"
    exit 1
fi

echo " Iniciando instalación de k3s en Debian 12..."

# --- Actualizar sistema ---
echo "Actualizando paquetes..."
apt update -y && apt upgrade -y

# --- Dependencias útiles ---
echo "Instalando dependencias..."
apt install -y curl wget apt-transport-https ca-certificates gnupg lsb-release

# --- Instalar k3s ---
echo "Instalando k3s (servidor)..."
curl -sfL https://get.k3s.io | sh -

# --- Esperar unos segundos ---
sleep 10

# --- Configuración de kubectl ---
echo "Configurando kubectl..."
if [ ! -d /root/.kube ]; then
    mkdir -p /root/.kube
fi
cp /etc/rancher/k3s/k3s.yaml /root/.kube/config
chown root:root /root/.kube/config

# Alias para facilitar kubectl
if ! grep -q "alias k=kubectl" /root/.bashrc; then
    echo "alias k=kubectl" >> /root/.bashrc
fi

# --- Estado ---
echo "Verificando estado del cluster..."
systemctl status k3s --no-pager
kubectl get nodes -o wide

echo "Instalación finalizada con éxito."
echo "Usa 'kubectl get pods -A' para ver todos los pods."
