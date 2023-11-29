#!/usr/bin/env sh

set -eu

DATAFILE=$1

PWD=$(pwd)

for i in $(<${DATAFILE}); do 
    echo "$i" && WPAAS_SITE_ID=${i} wpaas-site find /var/chroot/home/content/${POD}/ -depth -type f \( -iname sucuri_listcleaned.php -o -iname sucuri-cleanup.php -o -iname sucuri-db-cleanup.php -o -iname sucuri-filemanager.php -o -iname sucuri-toolbox-client.php -o -iname sucuri-version-check.php \) -mtime +1 -print -exec echo -n \; |tee -a ${PWD}/sucuri_script_cleanup.log;
    sleep 5;
done;
