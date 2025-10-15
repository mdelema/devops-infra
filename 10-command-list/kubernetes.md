#####################################################################################
					>>>>	Comandos interesantes:	<<<<
#####################################################################################

- Ejecutar: especificando URL y token del nodo maestro -------> curl -sfL https://get.k3s.io | K3S_URL=https://<TU_IP_MAESTRO>:6443 K3S_TOKEN=<TU_TOKEN_DE_NODO> sh -
- Información del cluter -------------------------------------> kubectl cluster-info 
- Listar los pods --------------------------------------------> kubectl get pods
- Listar los pods del namespace prueba -----------------------> kubectl get pods -n <"nombre_namespace"> 
- Listar los nodos del cluster -------------------------------> kubectl get nodes -n <"nombre_namespace"> 
- Listar los servicios ---------------------------------------> kubectl get service -n <"nombre_namespace">  
- Listar deployments -----------------------------------------> kubectl get deployments -n <"nombre_namespace"> 
- Listar namespaces ------------------------------------------>	kubectl get namespaces 		| grep -v 'kube-' (-v > es lo que queres sacar)  
- Obtén el token del nodo ------------------------------------> cat /var/lib/rancher/k3s/server/node-token
- Escalar a 3 replicas un deployment -------------------------> kubectl scale --replicas=3 deployment <"nombre_namespace">  -n <"nombre_namespace"> 
- Eliminar servicio ------------------------------------------> kubectl delete service <"nombre_service">
- Eliminar deployment ----------------------------------------> kubectl delete deployment <"nombre_deployment">  
- Eliminar todos los pods en todos los namespaces ------------> kubectl delete pods --all --all-namespaces
