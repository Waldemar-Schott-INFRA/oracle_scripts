#!/bin/bash
export LC_ALL=C.UTF-8
export NLS_LANG="${NLS_LANG%%.*}.AL32UTF8"
SCRIPTPATH=/tmp/notusedindex
if ! [ -d $SCRIPTPATH ];then mkdir $SCRIPTPATH; fi
SQL_FILE="$SCRIPTPATH/unused_index.sql"
SID=$(df -h | grep /oracle/[A-Z0-9]*$|awk -F "/" '{print $NF}')
SIDLOWER=$(echo $SID|awk '{print tolower($0)}')
DATUM=$(date +"%Y%m%d__%H_%M_%S")
TAGE=365
VERTEILER="Waldemar.schott@burda.com"
#VERTEILER="Waldemar.schott@burda.com philippe.brechenmacher@burda.com frank.ockenfuss@burda.cpom Dennis.Gampe@burda.com Klaus.Gindner@burda.com"
MAIL=/usr/bin/s-nail

echo "SET echo off
SET pagesize 50000
SET linesize 240
column index_name format a35
column table_name format a35
column created_at format a19
column last_used format a19
column usage_status format a20
column constraint_index format a10
column collection_type format a15
spool /tmp/notusedindex/notused_$SID.log
prompt Index usage collection status:
SELECT index_stats_enabled,
    DECODE(index_stats_collection_type, 0, 'ALL', 1, 'SAMPLED', 'UNKNOWN') AS collection_type,
    last_flush_time
FROM   v\$index_usage_info;

prompt Index candidates: no usage data or last recorded use older than $TAGE days.
prompt NO DATA means usage is unknown, not that the index was never used.
SELECT indexes.index_name,
    indexes.table_name,
    TO_CHAR(objects.created, 'YYYY-MM-DD HH24:MI:SS') AS created_at,
    TO_CHAR(usage.last_used, 'YYYY-MM-DD HH24:MI:SS') AS last_used,
    usage.total_access_count,
    CASE WHEN usage.last_used IS NULL THEN 'NO DATA' ELSE 'OLDER THAN $TAGE DAYS' END AS usage_status,
    CASE WHEN EXISTS (
        SELECT 1
        FROM   dba_constraints constraints
        WHERE  constraints.index_owner = indexes.owner
        AND    constraints.index_name = indexes.index_name
        AND    constraints.constraint_type IN ('P', 'U')
    ) THEN 'YES' ELSE 'NO' END AS constraint_index
FROM   dba_indexes indexes
LEFT JOIN dba_objects objects
    ON objects.owner = indexes.owner
      AND objects.object_name = indexes.index_name
      AND objects.object_type = 'INDEX'
LEFT JOIN dba_index_usage usage
    ON usage.object_id = objects.object_id
WHERE  indexes.owner = 'SYSADM'
AND    (usage.last_used IS NULL OR usage.last_used < SYSDATE - $TAGE)
ORDER BY usage.last_used NULLS FIRST, indexes.index_name;
spool off;
exit;
" > $SQL_FILE

sqlplus -s '/ as sysdba' @"$SQL_FILE"
echo "Auswertung von SAP System $SID am $DATUM" >> /tmp/notusedindex/notused_$SID.log
cat /tmp/notusedindex/notused_$SID.log | $MAIL -S sendcharsets=utf-8 -s  "unused Index Analyse von  ${SID}" $VERTEILER
