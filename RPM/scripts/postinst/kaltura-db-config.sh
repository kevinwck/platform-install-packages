#!/bin/bash - 
#===============================================================================
#          FILE: kaltura-db-config.sh
#         USAGE: ./kaltura-db-config.sh 
#   DESCRIPTION: 
#       OPTIONS: ---
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: Jess Portnoy, <jess.portnoy@kaltura.com>
#  ORGANIZATION: Kaltura, inc.
#       CREATED: 01/09/14 04:57:40 EST
#      REVISION:  ---
#===============================================================================
#set -o nounset                              # Treat unset variables as an error

if [ "$#" -lt 4 ];then
	echo "Usage: $0 <mysql-hostname> <mysql-super-user> <mysql-super-user-passwd> <mysql-port> [upgrade]"
	exit 1
fi

RC_FILE=/etc/kaltura.d/system.ini
if [ ! -r "$RC_FILE" ];then
	echo "Could not find $RC_FILE so, exiting.."
	exit 2
fi
. $RC_FILE
DB_ACTIONS_RC=`dirname $0`/db_actions.rc
if [ ! -r "$DB_ACTIONS_RC" ];then
	echo "Could not find $DB_ACTIONS_RC so, exiting.."
	exit 3
fi
. $DB_ACTIONS_RC

MYSQL_HOST=$1
MYSQL_SUPER_USER=$2
MYSQL_SUPER_USER_PASSWD=$3
MYSQL_PORT=$4
IS_UPGRADE=$5

if [ "$IS_UPGRADE" = 'upgrade' ];then
	echo "calling upgrade script instead."
	# the upgrade script is more complex naturally.. will include a check for schema
	# decide how far back to run alter scripts, etc.
fi
KALTURA_DB=$DB1_NAME

# check DB connectivity:
echo "Checking MySQL version.."
echo "select version();" | mysql -h$MYSQL_HOST -u$MYSQL_SUPER_USER -p$MYSQL_SUPER_USER_PASSWD -P$MYSQL_PORT -N
if [ $? -ne 0 ];then
cat << EOF
Failed to run:
# mysql -h$MYSQL_HOST -u$MYSQL_SUPER_USER -p$MYSQL_SUPER_USER_PASSWD -P$MYSQL_PORT."
Check your settings."
EOF
	exit 4
fi

# check whether the 'kaltura' already exists:
echo "use kaltura" | mysql -h$MYSQL_HOST -u$MYSQL_SUPER_USER -p$MYSQL_SUPER_USER_PASSWD -P$MYSQL_PORT $KALTURA_DB
if [ $? -eq 0 ];then
cat << EOF
The $KALTURA_DB DB seems to already be installed.

Did you mean to perform an upgrade? if so, run with:
# $0 $MYSQL_HOST $MYSQL_SUPER_USER $MYSQL_SUPER_USER_PASSWD $MYSQL_PORT upgrade

EOF
	exit 5
fi 

# this is the DB creation part, we want to exit if something fails here:
set -e

# create users:
for DB_USER in $DB_USERS;do
	echo "CREATE USER ${DB_USER};"
	echo "CREATE USER ${DB_USER} IDENTIFIED BY '$DB1_PASS' ;"  | mysql -h$MYSQL_HOST -u$MYSQL_SUPER_USER -p$MYSQL_SUPER_USER_PASSWD -P$MYSQL_PORT
done
# create the DBs:
for DB in $DBS;do 
	echo "creating db $DB"
	echo "create database $DB;" | mysql -h$MYSQL_HOST -u$MYSQL_SUPER_USER -p$MYSQL_SUPER_USER_PASSWD -P$MYSQL_PORT
	PRIVS=${DB}_PRIVILEGES
	DB_USER=${DB}_USER
	# apply privileges:
	echo "GRANT ${!PRIVS} ON $DB.* TO '${!DB_USER}'@'%';FLUSH PRIVILEGES;" | mysql -h$MYSQL_HOST -u$MYSQL_SUPER_USER -p$MYSQL_SUPER_USER_PASSWD -P$MYSQL_PORT
	DB_SQL_FILES=${DB}_SQL_FILES
	# run table creation scripts:
	for SQL in ${!DB_SQL_FILES};do 
		mysql -h$MYSQL_HOST -u$MYSQL_SUPER_USER -p$MYSQL_SUPER_USER_PASSWD -P$MYSQL_PORT $DB < $SQL
	done
done

#deployment/base/scripts/insertContent.php
#deployment/base/scripts/insertDefaults.php
#deployment/base/scripts/insertPermissions.php
#deployment/base/scripts/installPlugins.php

# populate data:
for PHP_CODE in /opt/kaltura/app/deployment/base/scripts/*php;do
	php PHP_CODE
done

set +e


# DWH setup:
# @DWH_DIR@/setup/dwh_setup.sh


