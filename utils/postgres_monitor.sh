#! /bin/bash
#
# Name: zapost
#
# Checks PostgreSQL activity.
#
# Author: bashman
#
# Version: 1.0
#

zapostver="1.0"
rval=0
sql=""

case $1 in

#'summary')
#       sql="select a.datname, pg_size_pretty(pg_database_size(a.datid)) as size, cast(blks_hit/(blks_read+blks_hit+0.000001)*100.0 as numeric(5,2)) as cache, cast(xact_commit/(xact_rollback+xact_commit+0.000001)*100.0 as numeric(5,2)) as success from pg_stat_database a order by a.datname"
#       ;;

#'size')
        #comprobar aqui los parametros
#       shift
#       sql="select pg_database_size('$1') as size"
#       ;;

#'version')
#       sql='select version()'
#       ;;
'status')
	if [ `/etc/init.d/postgresql-9.1 status | awk '{print $2}'` == "stopped" ]; then
		echo 0
		exit $retval
	fi
		echo 1
		exit $retval	
	;;
'totalsize')
        sql="select sum(pg_database_size(datid)) as total_size from pg_stat_database"
        ;;

'db_cache')
        # comprueba los parametros
        if [ ! -z $2 ]; then
		shift
        	sql="select cast(blks_hit/(blks_read+blks_hit+0.000001)*100.0 as numeric(5,2)) as cache from pg_stat_database where datname = '$1'"
	fi
        ;;

'db_success')
        # comprueba los parametros
	if [ ! -z $2 ]; then
		shift
       		sql="select cast(xact_commit/(xact_rollback+xact_commit+0.000001)*100.0 as numeric(5,2)) as success from pg_stat_database where datname = '$1'"
	fi
	;;

'server_processes')
	sql="select sum(numbackends) from pg_stat_database"
	;;

'tx_commited')
	sql="select sum(xact_commit) from pg_stat_database"
	;;

'tx_rolledback')
	sql="select sum(xact_rollback) from pg_stat_database"
	;;
'db_size')
	# comprueba los parametros
        if [ ! -z $2 ]; then
		shift
		sql="select pg_database_size('$1')" #as size"
	fi
	;;

'db_connections')
        # comprueba los parametros
        if [ ! -z $2 ]; then
		shift
        	sql="select numbackends from pg_stat_database where datname = '$1'"
	fi
	;;
'db_active_connections')
	sql="select sum(numbackends) from pg_stat_database"
	;;
'db_returned')
	# comprueba los parametros
        if [ ! -z $2 ]; then
		shift
		sql="select tup_returned from pg_stat_database where datname = '$1'"
	fi
	;;

'db_fetched')
        # comprueba los parametros
        if [ ! -z $2 ]; then
		shift
        	sql="select tup_fetched from pg_stat_database where datname = '$1'"
	fi
	;;

'db_inserted')
	# comprueba los parametros
        if [ ! -z $2 ]; then
        	shift
        	sql="select tup_inserted from pg_stat_database where datname = '$1'"
	fi
        ;;

'db_updated')
	# comprueba los parametros
        if [ ! -z $2 ]; then
        	shift
        	sql="select tup_updated from pg_stat_database where datname = '$1'"
	fi
        ;;

'db_deleted')
	# comprueba los parametros
        if [ ! -z $2 ]; then
        	shift
        	sql="select tup_deleted from pg_stat_database where datname = '$1'"
	fi
        ;;

'db_commited')
	# comprueba los parametros
        if [ ! -z $2 ]; then
        	shift
		sql="select xact_commit from pg_stat_database where datname = '$1'"
	fi
	;;

'db_rolled')
	# comprueba los parametros
	if [ ! -z $2 ]; then
        	shift
		sql="select xact_rollback from pg_stat_database where datname = '$1'"
	fi
	;;

'exclusivelock')
	sql="SELECT count(*) FROM pg_locks where mode='ExclusiveLock'"
	;;

'accessexclusivelock')
	sql="SELECT count(*) FROM pg_locks where mode='AccessExclusiveLock'"
	;;

'accesssharelock')
	sql="SELECT count(*) FROM pg_locks where mode='AccessShareLock'"
	;;

'rowsharelock')
	sql="SELECT count(*) FROM pg_locks where mode='RowShareLock'"
	;;

'rowexclusivelock')
	sql="SELECT count(*) FROM pg_locks where mode='RowExclusiveLock'"
	;;

'shareupdateexclusivelock')
	sql="SELECT count(*) FROM pg_locks where mode='ShareUpdateExclusiveLock'"
	;;

'sharerowexclusivelock')
	sql="SELECT count(*) FROM pg_locks where mode='ShareRowExclusiveLock'"
	;;

'version')
	sql="version"
	;;

'zapostver')
        echo "$zapostver"
	exit $rval
        ;;

*)
        echo "zapost version: $zapostver"
        echo "usage:"
	echo "    $0 total size                  -- Check the total databases size."
	echo "    $0 db_cache <dbname>           -- Check the database cache hit ratio (percentage)."
	echo "    $0 db_success <dbname>         -- Check the database success rate (percentage)."
	echo "    $0 server_processes            -- Check the total number of Server Processes that are active."
	echo "    $0 tx_commited                 -- Check the total number of commited transactions."
	echo "    $0 tx_rolledback               -- Check the total number of rolled back transactions."
	echo "    $0 db_size <dbname>            -- Check the size of a Database (in bytes)."
	echo "    $0 db_connections <dbname>     -- Check the number of active connections for a specified database."	
	echo "    $0 db_returned <dbname>        -- Check the number of tuples returned for a specified database."
	echo "    $0 db_fetched <dbname>         -- Check the number of tuples fetched for a specified database."
	echo "    $0 db_inserted <dbname>        -- Check the number of tuples inserted for a specified database."
	echo "    $0 db_updated <dbname>         -- Check the number of tuples updated for a specified database."
	echo "    $0 db_deleted <dbname>         -- Check the number of tuples deleted for a specified database."
	echo "    $0 db_commited <dbname>        -- Check the number of commited back transactions for a specified database."
	echo "    $0 db_rolled <dbname>          -- Check the number of rolled back transactions for a specified database."
	echo "	  $0 db_active_connections	 -- Active connections count."
	echo "	  $0 exclusivelock 		 -- Exclusive locks."
	echo "	  $0 accessexclusivelock	 -- Access exclusive lock."
	echo "    $0 accesssharelock		 -- Access share lock."
	echo "	  $0 rowsharelock		 -- Row share lock."
	echo "	  $0 rowexclusivelock		 -- Row exclusive lock."
	echo "    $0 shareupdateexclusivelock"
	echo "    $0 sharerowexclusivelock"
	echo "    $0 version                     -- The PostgreSQL version."
	echo "    $0 zapostver                   -- Version of this script."
        exit $rval
        ;;
esac

if [ "$sql" != "" ]; then
	if [ "$sql" == "version" ]; then
		psql --version|head -n1
		rval=$?
	else
		psql -h localhost -U postgres -t -c "$sql" 2>/dev/null
		rval=$?
	fi
fi

if [ "$rval" -ne 0 ]; then
  	echo "ZBX_NOTSUPPORTED"
fi

exit $rval

#
# end zapost
