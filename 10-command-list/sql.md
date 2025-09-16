#####################################################################################
					>>>>	Comandos interesantes:	<<<<
#####################################################################################
#------------------------------------------------------------------------------------#
		>> SQL <<
#------------------------------------------------------------------------------------#
nano /root/.keys/mysql_admin --> crear una password
---> mysqldump -u root -p "table-name" > "table-name".sql
---> mysql
---> CREATE DATABASE "table-name";
---> mysql -u root -p "table-name" < /home/ebuela/pwm.sql
--	Entrar	-> mysql -u admin -p`cat /root/.keys/mysql_admin` -h IP -P 3306
--	Filtro 	-> SELECT TABLE_NAME, INDEX_NAME, COLUMN_NAME FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = 'db-name' AND INDEX_NAME LIKE 'IDX_%';
--	Elimina -> DROP INDEX IDX_1AE3441319EB6921 ON oauth2_user_client_xref;