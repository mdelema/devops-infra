#####################################################################################
					>>>>	Comandos interesantes:	<<<<
#####################################################################################

- Inspeccionar y gestionar el entorno ------------------------> docker system [OPTIONS] || prune || df || info || events
- Navegar y configurar diferentes contextos ------------------> docker context ls 
- Congela los procesos activos de un contenedor --------------> docker pause || docker unpause [CONTAINER]
- Eliminar contenedores, imagenes y volumenes ----------------> docker rm [CONTAINER] || docker rmi [IMAGE ID] || docker volume rm [NAME]
- Muestra la lista de todos los contenedores -----------------> docker ps -a || docker ps -s
- Gestión de red ---------------------------------------------> docker network [OPTIONS] || connect || create || disconnect || rm
- Detener todos los contenedores -----------------------------> docker stop $(docker ps -aq)
- Eliminar todos los contenedores ----------------------------> docker container prune -f
- Eliminar todas las imágenes --------------------------------> docker image prune -a -f
- Eliminar volúmenes no utilizados ---------------------------> docker volume prune -f
- Eliminar redes no utilizadas -------------------------------> docker network prune -f
- Eliminar caché de construcción -----------------------------> docker builder prune -a -f
- Limpiar completamente Docker -------------------------------> docker system prune -a -f --volumes
- Detener y borra los contenedores ---------------------------> docker compose down
- Limpiar cache y contenedores previos -----------------------> docker compose down -v && docker system prune -a -f
- Construir contenedor de cero -------------------------------> docker compose build "<nombre-app>" --no-cache
- Levantar todo y construir imagen ---------------------------> docker compose up -d	|| docker compose up --build 
