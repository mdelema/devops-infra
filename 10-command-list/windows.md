#####################################################################################
					>>>>	Comandos interesantes:	<<<<
#####################################################################################
>> Atajos	
- Propiedades del Sistema (Variables de Entorno) -------------> Win + R => sysdm.cpl
- Información del Sistema (Heramienta de Diagnostico) --------> Win + R => dxdiag
- Programador de Tareas --------------------------------------> Win + R => taskschd.msc
- Administrador de Discos ------------------------------------> Win + R => diskmgmt.msc
	....................................................................................
>> Comandos
- Saber el nombre de la PC -----------------------------------> ping -a [IP]   |o| 	nslookup [IP]
- Resetear los DNS -------------------------------------------> ipconfig /flushdns
- Ver estados de los Discos "similar al df -h" ---------------> Get-PSDrive -PSProvider FileSystem	
- Ejecuta el script solo en esta sesión de PS. ---------------> Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
- Mapear carpeta compartida o una unidad de red (ej: H:) -----> net use (unidad) (Server a mapear) /persistent:yes (ej -> net use H: srvfsadm02\E /persistent:yes)
- Listar archivos dentro de una directorio (nuevo) -----------> Get-ChildItem -File | Where-Object { $_.Name -like "*Archivo*" }
- Listar archivos dentro de una directorio (viejo) -----------> Get-ChildItem | Where-Object { -not $_.PSIsContainer -and $_.Name -like "*Archivo*" }
- Limpiar el historial de AnyDesk ----------------------------> Remove-Item C:\Users\mdelema\AppData\Roaming\AnyDesk
- Instalar WSL	----------------------------------------------> wsl --install 
- Habilitar el Hipervisor y el Subsistema para Linux ---------> dism.exe /online /enable-feature /featurename:Microsoft-Hyper-V /all
																dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all
																dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all
