#!/bin/bash
SCRIPTPATH=/tmp/notusedindex
if ! [ -d $SCRIPTPATH ];then mkdir $SCRIPTPATH; fi
SQL_FILE="$SCRIPTPATH/unused_index.sql"
SID=$(df -h | grep /oracle/[A-Z0-9]*$|awk -F "/" '{print $NF}')
SIDLOWER=$(echo $SID|awk '{print tolower($0)}')
DATUM=$(date +"%Y%m%d__%H_%M_%S")
VERTEILER="Waldemar.schott@burda.com"
#VERTEILER="Waldemar.schott@burda.com philippe.brechenmacher@burda.com frank.ockenfuss@burda.cpom Dennis.Gampe@burda.com Klaus.Gindner@burda.com"
MAIL=/usr/bin/s-nail

echo "SET pagesize 50000
SET linesize 200
column index_name format a30
column table_name format a30
spool /tmp/notusedindex/notused_$SID.log
SELECT index_name,
       table_name,
       monitoring,
       used,
       start_monitoring,
       end_monitoring
FROM   dba_object_usage
WHERE  owner = 'SYSADM'
AND    used = 'NO'
ORDER BY index_name;
spool off;
" > $SQL_FILE

cat $SQL_FILE |sqlplus  '/ as sysdba'
echo "Auswertung von SAP System $SID am $DATUM" >> /tmp/notusedindex/notused_$SID.log
cat /tmp/notusedindex/notused_$SID.log | $MAIL -S sendcharsets=iso-8859-1 -s  "unused Index Analyse von  ${SID}" $VERTEILER
