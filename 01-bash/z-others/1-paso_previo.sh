#!/bin/bash

#--------------------------------------------------------------------------------------#
# Autor: mdelema
#   - Convertir los scripts a formato Unix
#--------------------------------------------------------------------------------------#

echo "#*************************************************************#"
echo "#     Convierte los scripts en formato Unix                   #"
echo "#*************************************************************#"

apt install dos2unix -y
dos2unix /ruta/del/archivo/archivo.sh       # ej: /root/tpl-m/upgrade.sh
