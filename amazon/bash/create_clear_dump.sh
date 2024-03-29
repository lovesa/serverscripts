#!/bin/sh
# ----------
# slony1_extract_schema.sh
#
#	Script to extract the user schema of a slony node in the original
#	state with all Slony related cruft removed.
# ----------

# ----
# Check for correct usage
# ----
if test $# -ne 3 ; then
	echo "usage: $0 dbname clustername tempdbname" >&2
	exit 1
fi

# ----
# Remember call arguments and get the nodeId of the DB specified
# ----
dbname=$1
cluster=$2
tmpdb=$3
user="postgres"
nodeid=`psql -U $user -At -c "select \"_$cluster\".getLocalNodeId('_$cluster')" $dbname`

TMP=tmp.$$

# ----
# Print a warning for sets originating remotely that their
# triggers and constraints will not be included in the dump.
# ----
psql -U $user -At -c "select 'Warning: Set ' || set_id || ' does not origin on node $nodeid - original triggers and constraints will not be included in the dump' from \"_$cluster\".sl_set where set_origin <> $nodeid" $dbname >&2

# ----
# Step 1.
#
# Dump the current schema and the Slony-I configuration data. Add
# UPDATE commands that correct the table oid's in the config data
# when this dump is restored.
# ----
echo "Creating clear dump for node: $nodeid" 1>&2
echo "pg_dump -U $user -s -N coordinates $dbname >$TMP.sql" 1>&2

pg_dump -U $user -s -N coordinates $dbname >$TMP.sql
echo "CREATE SCHEMA coordinates;">>$TMP.sql

echo "pg_dump -U $user -s -n coordinates -t coordinates $dbname >>$TMP.sql" 1>&2
pg_dump -U $user -s -n coordinates -t coordinates $dbname >>$TMP.sql

echo "pg_dump -U $user -a -n _$cluster $dbname >>$TMP.sql" 1>&2
pg_dump -U $user -a -n \"_$cluster\" $dbname >>$TMP.sql

echo "SQL1" 1>&2
psql -U $user -t -c "select 'update \"_$cluster\".sl_table set tab_reloid=(select C.oid from \"pg_catalog\".pg_class C, \"pg_catalog\".pg_namespace N where C.relnamespace = N.oid and C.relname = ''' || C2.relname || ''' and N.nspname = ''' || N2.nspname || ''') where tab_id = ''' || tab_id || ''';' from \"_$cluster\".sl_table T, \"pg_catalog\".pg_class C2, \"pg_catalog\".pg_namespace N2 where T.tab_reloid = C2.oid and C2.relnamespace = N2.oid" $dbname >>$TMP.sql

echo "SQL2" 1>&2
psql -U $user -t -c "select 'update \"_$cluster\".sl_sequence set seq_reloid=(select C.oid from \"pg_catalog\".pg_class C, \"pg_catalog\".pg_namespace N where C.relnamespace = N.oid and C.relname = ''' || C2.relname || ''' and N.nspname = ''' || N2.nspname || ''') where seq_id = ''' || seq_id || ''';' from \"_$cluster\".sl_sequence T, \"pg_catalog\".pg_class C2, \"pg_catalog\".pg_namespace N2 where T.seq_reloid = C2.oid and C2.relnamespace = N2.oid" $dbname >>$TMP.sql

# ----
# Step 2.
#
# Create a temporary database and restore the schema including all
# Slony related cruft.
# ----
echo "Creating temp db" 1>&2
echo "createdb -U $user $tmpdb >/dev/null" 1>&2
createdb -U $user $tmpdb >/dev/null 
echo "Importing" 1>&2
psql -U $user $tmpdb <$TMP.sql >/dev/null 2>&1

# ----
# Step 3.
#
# Use the slonik "uninstall node" command to restore the original schema.
# ----
slonik >/tmp/error.log 2>&1 <<_EOF_
cluster name = $cluster;
node $nodeid admin conninfo = 'user=postgres dbname=$tmpdb';
uninstall node (id = $nodeid);
_EOF_

# ----
# Step 4.
#
# Use pg_dump on the temporary database to dump the user schema
# to stdout.
# ----
echo "Dumping temp database" 1>&2
pg_dump -U $user -c -s $tmpdb

# ----
# Remove temporary files and the database
# ----
sleep 2
dropdb -U $user $tmpdb >/dev/null
rm $TMP.*
