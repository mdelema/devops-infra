#####################################################################################
					>>>>	Comandos interesantes:	<<<<
#####################################################################################
#------------------------------------------------------------------------------------#
		>> Windows <<
#------------------------------------------------------------------------------------#
	
- Saber el nombre de la PC -----------------------------------> ping -a [IP]   |o| 	nslookup [IP]	
- Limpiar el historial de AnyDesk ----------------------------> Remove-Item C:\Users\user\AppData\Roaming\AnyDesk\
- Ejecuta el script solo en esta sesión de PS. ---------------> Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
- Mapear carpeta compartida o una unidad de red (ej: H:) -----> net use (unidad) (Server a mapear) /persistent:yes (ej -> net use H: srvfsadm02\E /persistent:yes)
- Listar archivos dentro de una directorio (nuevo) -----------> Get-ChildItem -File | Where-Object { $_.Name -like "*Archivo*" }
- Listar archivos dentro de una directorio (viejo) -----------> Get-ChildItem | Where-Object { -not $_.PSIsContainer -and $_.Name -like "*Archivo*" }
