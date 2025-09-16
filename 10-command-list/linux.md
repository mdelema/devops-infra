#####################################################################################
					>>>>	Comandos interesantes:	<<<<
#####################################################################################
#------------------------------------------------------------------------------------#
		>> Linux <<
#------------------------------------------------------------------------------------#
	
- Actualizaar todos lo paquetes ------------------------------> apt update && apt upgrade -y
- Ver la lista de paquetes que se pueden actualizar ----------> apt list --upgradable -a
- Cambiar de contraseña al usuario ---------------------------> passwd
- Editar el nombre y hostname 	------------------------------> hostnamectl set-hostname "<server_name>"
- Editar hosts y localhost -----------------------------------> nano /etc/hosts (Poner el "<server_name>".dominio  "<server_name>")
- Problemas con los DNS --------------------------------------> nano /etc/resolv.conf
- Dejar el "root@prod:~#" de color verde ---------------------> nano /root/.bashrc  >pegar> PS1='\[\e[0;32m\]\u@\h:\[\e[1;36m\]\w\[\e[0m\]\$ '
- Buscar una IP dentro de varios archivos --------------------> grep -r "IP, palabra clave o web"
- Filtrar cosas por los ultimos ------------------------------> history | tail -n "<30>"
- Buscar archivos por partes del nombres ---------------------> find / -type f -iname "*dominio*.crt" 2>/dev/null
- Ver trabajos Detenidos -------------------------------------> jobs || kill %1 (o los que sean) || fg %1 (te devuelve al archivo)
- Ver todo el arbol de carpetas dentro -----------------------> tree (apt install tree)
- Ver el tiempo de arranque y qué servicios tardaron más -----> systemd-analyze blame
- Mostrar todos los servicios activos ------------------------> systemctl list-units --type=service --state=running
- Mostrar servicios habilitados al arranque ------------------> systemctl list-unit-files --type=service --state=enabled
- Mostrar los servicios realmente activos al arranque actual -> systemctl --type=service --state=running
- Mapear achivos de una carpeta a la otra --------------------> ln -s /etc/nginx/sites-available/* /etc/nginx/sites-enabled/
- Cambiar permisos para ejecutar el script -------------------> chmod +x "mi_script.sh"	 || chmod ug+x mi_script.sh (solo dueño y grupo puedan ejecutar)
- Saber cuanta RAM tengo -------------------------------------> cat /proc/meminfo || free -h || vmstat || 
- Saber cuanta CPU tengo -------------------------------------> cat /proc/cpuinfo || nproc || lscpu   || htop   || 
- Ver las versiones de Gitlab  -------------------------------> dpkg -l gitlab-ce |o| apt show gitlab-ce |o| sudo gitlab-ctl reconfigure
- Eliminar archivos residuales -------------------------------> dpkg -l | awk '/^rc/ {print $2}' | xargs -r dpkg --purge
- Eliminar caché de paquetes ---------------------------------> apt clean  &&  apt autoremove -y
- Eliminar caché de usuarios ---------------------------------> rm -rf ~/.cache/thumbnails/*
- Eliminar archivos temporales -------------------------------> rm -rf /tmp/*  &&  rm -rf /var/tmp/*
- Eliminar logs antiguos -------------------------------------> journalctl --vacuum-size=100M
- Vaciar el archivo ------------------------------------------> > ~/.bash_history	|| history -c
