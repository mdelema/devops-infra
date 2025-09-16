#!/bin/sh

echo "#*************************************************************************#"
echo "#         Comienza actualización de MAUTIC 	                        #"
echo "#*************************************************************************#"

RUNNING=`ps auxw | grep "mautic" | grep -v "upgrade" |grep -v "grep"`
if [ -n "$RUNNING" ]; then
        echo "Hay procesos de Mautic en ejecucion"
        exit 1;
fi


echo "iniciamos la actualización de Mautic"

#Detengo servicios
echo "Deteniendo servicio cron..."
echo $(service cron stop)
echo $(service cron status | grep "Active:")
echo "Deteniendo servicio php..."
echo $(service php8.3-fpm stop)
echo $(service php8.3-fpm status | grep "Active:")
echo "Deteniendo servicio nginx..."
echo $(service nginx stop)
echo $(service nginx status | grep "Active:")

#Fix a permisos a carpetas y archivos con el usuario:grupo www-data
echo "Fix www-data:www-data..."
chown -R www-data:www-data /var/www/html
echo "Fix permisos..."
find /var/www/html/. -type d -not -perm 755 -exec chmod 755 {} +
find /var/www/html/. -type f -not -perm 644 -exec chmod 644 {} +
chmod -R g+w /var/www/html/var/cache/ /var/www/html/var/logs/ /var/www/html/app/config/
chmod -R g+w /var/www/html/media/files/ /var/www/html/media/images/ /var/www/html/translations/

#Borro cache
echo "Borrando cache..."
rm -rf /var/www/html/var/cache/*

#Ejecuto FIX de Mysql donde genera los indices
echo "Fix MySQL donde se generan los indices"
mysql -vvv -u mauticadmin  -p`cat /root/.keys/mysql_mauticadmin` -h 192.168.7.110 mautic < /root/scripts/mautic-upgrade.sql

#Busco actualizacion
echo "Buscando actualizacion mautic..."
php /var/www/html/bin/console -vvv mautic:update:find

#Actualizo mautic
echo "Actualizando mautic..."
php /var/www/html/bin/console -vvv mautic:update:apply
php /var/www/html/bin/console -vvv mautic:update:apply --finish

#Fix permisos  a carpetas y archivos con el usuario:grupo www-data
echo "Fix www-data:www-data..."
chown -R www-data:www-data /var/www/html
echo "Fix permisos..."
find /var/www/html/. -type d -not -perm 755 -exec chmod 755 {} +
find /var/www/html/. -type f -not -perm 644 -exec chmod 644 {} +
chmod -R g+w /var/www/html/var/cache/ /var/www/html/var/logs/ /var/www/html/app/config/
chmod -R g+w /var/www/html/media/files/ /var/www/html/media/images/ /var/www/html/translations/

#Levanto servicios
echo "Levantando servicio php8.3-fpm..."
echo $(service php8.3-fpm start)
echo $(service php8.3-fpm status | grep "Active:")
echo "Levantando servicio nginx..."
echo $(service nginx start)
echo $(service nginx status | grep "Active:")

echo "**** Logearse (s/login) y luego levantar servicio de CRON ****"
echo "#######  PRONTO --> Actualización de MAUTIC finalizada  ####### "
