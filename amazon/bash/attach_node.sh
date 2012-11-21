#!/bin/sh

. /opt/serverscripts/utils/functions.sh

DEBUG=1

e "Starting node attach"

if [ -z "$1" ]; then
	error "Please enter node ip"
	exit 1
fi

if [ -z "$2" ]; then
        error "Please enter node ID"
        exit 1
fi

if [ -z "$3" ]; then
	error "Please enter cluster name"
	exit 1
fi


NODE=$1
NODEID=$2
cluster=$3
KEY=""
_AL_PREFIX=$1

LOCAL_PGCONFDIR="/opt/serverscripts/amazon/configs/"
LOCAL_SLONSCDIR="/etc/slony1-91-II/scripts/"
LOCAL_PREAMBLES=${LOCAL_PREAMBLES}preambles

REMOTE_PGCONFDIR="/etc/postgres/"
REMOTE_SLONCONFDIR="/etc/slony1-91-II/"

database=""
user="postgres"

if [ ! -f $KEY ]; then
	error "No ssh key found"
	exit 1
fi

SSH="ssh -o StrictHostKeyChecking=no -i $KEY "

IP=`ifconfig eth0  | grep 'inet addr:'| cut -d: -f2 | awk '{ print $1}'`

if [ -z "$IP" ]; then
        error "Can not detect ip address"
        exit 1;
fi


function check_ssh {
	local ret_st
	local ret_msg
	
	debug "Runing ping $NODE"

        PING=`/bin/ping -q -n -c 5 $NODE | grep "packet loss" | cut -d " " -f 6 | cut -d "%" -f1`
	ret_st=$?

        debug "Packet lost: ${PING}"

        if [ $ret_st -eq 0 ]; then
                if [ $PING -gt 50 ]; then
                        error "Node not started yet, or network error"
                        return 1
                fi
        else
                error "Failed to ping, returned $ret_st"
                return 1
        fi


	ret_msg=`$SSH ${NODE} "echo 1";`
	ret_st=$?

	if [ $ret_st -ne 0 ]; then
		error "SSH check failed($ret_st): $ret_msg"
	else
		e "SSH check success"
	fi	
	
	return $ret_st
}

function postgres_startup {
	local ret_st
        local ret_msg

	#Creating full dump
	e "Creating full dump"
	debug "pg_dumpall -U $user -c -g > $LOCAL_PGCONFDIR/global.sql"

	pg_dumpall -U $user -c -g > $LOCAL_PGCONFDIR/global.sql

	debug "./create_clear_dump.sh $database $cluster temp_db > $LOCAL_PGCONFDIR/database.sql"
	./create_clear_dump.sh $database $cluster temp_db > $LOCAL_PGCONFDIR/database.sql 
		
	if [ $? -ne 0 ]; then
		error "Error during full schema dump"
		exit 1
	fi

	#Copying postgres configs to instance
	e "Copying postgres files"
	debug "Running: scp -i ${KEY} ${LOCAL_PGCONFDIR}/* ${NODE}:/${REMOTE_PGCONFDIR}/"

	ret_msg=`scp -i ${KEY} ${LOCAL_PGCONFDIR}/* ${NODE}:/${REMOTE_PGCONFDIR}/`
	ret_st=$?

	if [ $ret_st -ne 0 ]; then
		error "Config copy error($ret_st): $ret_msg"
		exit 1
	fi
	
	#chmoding work
	debug "Running: $SSH $NODE \"chown postgres.postgres $REMOTE_PGCONFDIR; chmod 700 $REMOTE_PGCONFDIR;\""
	$SSH $NODE "chown postgres.postgres $REMOTE_PGCONFDIR; chmod 700 $REMOTE_PGCONFDIR;"
	
	#Postgres startup
	e "Starting postgres"

	ret_msg=`$SSH $NODE "/etc/init.d/postgresql-9.1 start"`
	ret_st=$?

	if [ $ret_st -ne 0 ]; then
		error "Postgres startup failed($ret_st): $ret_msg"
		exit 1
	fi

	e "Postgres started"
	sleep 5s
	#Check if postgres is available from local node

	ret_msg=`psql -U postgres -h $NODE -c "SELECT 1;"`
	ret_st=$?

	if [ $ret_st -ne 0 ]; then
		error "Postgres is not available from local node($ret_st): $ret_msg"
		exit
	fi
	import_log=/tmp/import.log.$$
		
	#trying to import sql
	e "Creating database"

	$SSH $NODE "createdb -U postgres"
	
	e "Importing database schema"
	
	$SSH $NODE "psql -U postgres -f ${REMOTE_PGCONFDIR}/global.sql"  >> $import_log 2>&1
	ret_st=$?

	if [ $ret_st -ne 0 ]; then
                error "Database global import failed($ret_st)"
                exit 1
        fi

	$SSH $NODE "psql -U postgres -f ${REMOTE_PGCONFDIR}/database.sql"  >> $import_log 2>&1

	ret_st=$?

	if [ $ret_st -ne 0 ]; then
		error "Database import failed($ret_st)"
		exit 1
	fi

	e "Postgres preparation done"

}	

function slony_startup {
	local ret_msg
	local ret_st
	local tmp=./preamble.tmp.$$
	
	local scriptp

	scripts=${LOCAL_SLONSCDIR}/script_${NODEID}.sk
	scriptu=${LOCAL_SLONSCDIR}/unscript_${NODEID}.sk
	e "Generating attach script: $scripts"

		
	cat > ${LOCAL_SLONSCDIR}preamble_${NODEID}.sk << EOF

define SLAVE${NODEID} ${NODEID};
node @SLAVE${NODEID} admin conninfo = 'dbname=postgres host=$NODE user=postgres';

EOF

	cat > $scripts << EOF
#!/usr/pgsql-9.1/bin/slonik
include <${LOCAL_SLONSCDIR}preamble.sk>;
include <${LOCAL_SLONSCDIR}preamble_${NODEID}.sk>;
store node (id=@SLAVE${NODEID}, event node=@PRIMARY, comment='${NODEID} Slave Slony Node');
store path (server=@PRIMARY, client=@SLAVE${NODEID}, conninfo='dbname=postgres host=$IP user=postgres');
store path (server=@SLAVE${NODEID}, client=@PRIMARY, conninfo='dbname=postgres host=$NODE user=postgres');
subscribe set (id = 1, provider = @PRIMARY, receiver = @SLAVE${NODEID});
EOF

	e "Generating dettach script: $scriptu"

	cat > $scriptu << EOF
#!/usr/pgsql-9.1/bin/slonik
include <${LOCAL_SLONSCDIR}preamble.sk>;
include <${LOCAL_SLONSCDIR}preamble_${NODEID}.sk>;
unsubscribe set (id = 1, receiver = @SLAVE${NODEID});
#drop path (server=@SLAVE${NODEID}, client=@PRIMARY);
drop path (server=@PRIMARY, client=@SLAVE${NODEID});
drop node (id=@SLAVE${NODEID}, event node=@PRIMARY);
EOF

	#Chmoding 
	chmod +x $scripts $scriptu
	e "Attaching node"

	$scripts

	ret_st=$?

	if [ $ret_st -ne 0 ]; then
		error "Node attach error($ret_st)"
		exit 1
	fi

	e "Starting slon daemon"
	
	echo $NODEID >> $LOCAL_PREAMBLES

	$SSH $NODE "/etc/init.d/slony1-91-II start"
	
	ret_st=$?

	if [ $ret_st -ne 0 ]; then
		error "Error during slony startup"
		e "Trying to rollback changes with: $scriptu"
		
		$scriptu

		rem_preambles

		ret_msg=$?
		
		exit 1
	fi
	
	rm -f $tmp
	e "Slon started"
}

function rem_preambles {
	sed -i 's/${NODEID}//g' $LOCAL_PREAMBLES
}

if check_ssh; then
	e "Starting postgres section"

	postgres_startup
	slony_startup
	
else
	exit 1
fi
