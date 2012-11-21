#!/bin/sh

. /opt/serverscripts/utils/functions.sh

if [ -z "$1" ] || [ -z "$2" ]; then
	echo "Usage: node_id http_server_ip"
	exit 1
fi

DEFLOG="/var/log/backup.log.%Y-%m-%d"
ALLOWOUT=1
DEBUG=1

NODEID=$1
POOLIP=$2

debug "Node id: $NODEID, HttpIP: $POOLIP"

# USER VARIABLES
BACKUPDIR=/var/lib/pgsql/archive/archive/
TEMPDIR="${BACKUPDIR}temp"			# Temp directory

LOCALDIR=/var/lib/pgsql/9.1/data					# Folder to be backed up

HOSTNAME=`/bin/hostname`;
SLEEPTIME=40

REMOTE_HOST="82.135.156.149"
REMOTE_DIR="/vz/vzfs/databaseBackup/${HOSTNAME}/"

EXCLUDES=$BACKUPDIR/backup_exclude                              	# File containing the excluded directories
DAYS=2

PCP="10 localhost 9898 postgres qwert234"


RSYNC="rsync -ah --bwlimit=11240 --delete-after "			
RSYNC+=" --exclude-from=$EXCLUDES"



function stop_db {
	e "Stoping database"
	#Detach from pgpool
	e "Detaching node"
	debug "Trying to detach node $NODEID with command: ssh $POOLIP \"pcp_detach_node $PCP $NODEID\"" 
	
	ssh $POOLIP "pcp_detach_node $PCP $NODEID" 2>&1
	ret_msg=$?
	if [ $ret_msg -ne 0 ]; then
		error "Error occured during detach($ret_msg)"
		exit 1;
	else
		e "Trying to stop database"
		debug "Running service postgresql-9.1 stop"
		service postgresql-9.1 stop 2>&1
		ret_msg=$?

		if [ $ret_msg -ne 0 ]; then
			error "Could not stop postgres($ret_msg) during backup on node $HOSTNAME" 1
		fi
	fi	
}

function start_db {
        e "Starting database on $VEHOSTNAME"
	
	debug "service postgresql-9.1 start"
 	service postgresql-9.1 start 2>&1
	ret_msg=$?
	if [ $ret_msg -ne 0 ]; then
		error "Database start failure($ret_msg) no $HOSTNAME" 1
	else
        	#Attach node to pgpool
		e "Sleeping for $SLEEPTIME secconds"
		sleep $SLEEPTIME
		
		e "Attaching node to cluster"
		debug "Running command: ssh $POOLIP \"pcp_attach_node $PCP $NODEID\""
	
		ssh $POOLIP "pcp_attach_node $PCP $NODEID" 2>&1
		ret_msg=$?
	
		if [ $ret_msg -ne 0 ]; then
			error "Error during node attach on $HOSTNAME. Possible cluster problems" 1
		fi
	fi
 
}

function first_stage {
	before="$(date +%s)"
	e "Starting first stage of sync"
	# =================================
	e "Running rsync"
	debug "Running command: $RSYNC $LOCALDIR $TEMPDIR"
	
	$RSYNC $LOCALDIR $TEMPDIR 2>&1

	# =================================
	after="$(date +%s)"
	elapsed_seconds="$(/usr/bin/expr $after - $before)"
	e "Done first stage, elapsed time: $elapsed_seconds s."
}

function second_stage {
        before="$(date +%s)"
        e "Starting second stage of sync"
        # =================================
	e "Perform stop_db"

	stop_db

	e "Running rsync"
        debug "Running command: $RSYNC $LOCALDIR $TEMPDIR" 

        $RSYNC $LOCALDIR $TEMPDIR 2>&1

	e "Perform start_db"
	start_db
        # =================================
        after="$(date +%s)"
        elapsed_seconds="$(/usr/bin/expr $after - $before)"
        e "Done second stage, elapsed time: $elapsed_seconds s."
}

function remote_backup {
	if [ -n "${REMOTE_HOST}" ] && [ -n "${REMOTE_DIR}" ]; then
		
		before="$(date +%s)"
		
        	NOW=`date '+%Y-%m'-%d_%H:%M`
        	NOW=${REMOTE_DIR}increment/${NOW}
		
		e "Creating remote dir for incremental backup"
		debug "Running ssh ${REMOTE_HOST} \"mkdir -p ${REMOTE_DIR}current/; mkdir -p ${NOW}\""

		ssh ${REMOTE_HOST} "mkdir -p ${REMOTE_DIR}current/; mkdir -p $NOW" 2>&1
		
		ret_msg=$?
		
		if [ $ret_msg -ne "0" ]; then
			error "Can not create remote dir($ret_msg)"
		else		
			e "Running remote backup process"
			
			if [ "$1" == "link" ]; then
				e "Running remote rsync using HARDLINK mode"
				
				debug "Commencing remote ${RSYNC} ${TEMPDIR} ${REMOTE_HOST}:${REMOTE_DIR}current/"                 

                                ${RSYNC} ${TEMPDIR}/ ${REMOTE_HOST}:${REMOTE_DIR}current/ 2>&1
                                ret_msg=$?

                                if [ $ret_msg -ne 0 ]; then
                                        error "Remote backup error($ret_msg)"
                                else

					e "Updating mtime to reflect the snapshot time"
        				# UPDATE THE MTIME TO REFELCT THE SNAPSHOT TIME
        				ssh ${REMOTE_HOST} "touch ${REMOTE_DIR}current/" 2>&1
					ret_msg=$?
					
					if [ $ret_msg -ne 0 ]; then
						error "Error during updating mtime"
					else

        					e "Making hardlink copy"
        					# MAKE HARDLINK COPY
        					ssh ${REMOTE_HOST} "cp -al ${REMOTE_DIR}current/* $NOW" 2>&1
						ret_msg=$?
						
						if [ $ret_msg -ne 0 ]; then
							error "Error during hardlink copy"
						else
							e "Done making hardlinks"
						fi
						
					fi
				fi
			else
				e "Running remote rsync using RSYNC mode"

				debug "Commencing remote ${RSYNC} --backup --backup-dir=${NOW} ${TEMPDIR} ${REMOTE_HOST}:${REMOTE_DIR}current/"  		

    				${RSYNC} --backup --backup-dir=${NOW} ${TEMPDIR}/ ${REMOTE_HOST}:${REMOTE_DIR}current/ 2>&1
				ret_msg=$?

				if [ $ret_msg -ne 0 ]; then
					error "Remote backup error($ret_msg)"
				fi
			fi
		
		fi

		after="$(date +%s)"
        	elapsed_seconds="$(/usr/bin/expr $after - $before)"
        	e "Done remote backup, elapsed time: $elapsed_seconds s."
	else
		error "Remote backup failed, no remote host or remote dir specified"
	fi
}

function local_backup {
	before="$(date +%s)"
	NOW=`date '+%Y-%m'-%d_%H:%M`
        NOW=${BACKUPDIR}increment/${NOW}
	CURRENT=${BACKUPDIR}current/
	
        e "Starting local backup"
        # =================================
        e "Running rsync"
	debug "Running command: $RSYNC $TEMPDIR $CURRENT"

        $RSYNC $TEMPDIR $CURRENT 2>&1
	
        # =================================
        after="$(date +%s)"
        elapsed_seconds="$(/usr/bin/expr $after - $before)"
        e "Done local backup, elapsed time: $elapsed_seconds s."

	e "Updating mtime to reflect the snapshot time"
	# UPDATE THE MTIME TO REFELCT THE SNAPSHOT TIME
	touch $BACKUPDIR/current 2>&1
	
	e "Making hardlink copy"
	# MAKE HARDLINK COPY
	cp -al $CURRENT/* $NOW 2>&1

}

function remove_old_local {
	# REMOVE OLD BACKUPS
	e "Removing old backups: $OLD" 
	for FILE in "$( $FIND $OLD -maxdepth 1 -type d -mtime +$DAYS )"
	do
		e "Removing: $FILE"
		rm -Rf $FILE 2>&1
        done

}

function remove_old_remote {
        local CMDR
	local ret_msg
	local ret_st

        # REMOVE OLD BACKUPS
	if [ ! -z "$1" ]; then
        	e "Removing old (older than $DAYS days) from $1"
        	CMDR="find $1 -maxdepth 1 --mindepth 1 -type d -atime +${DAYS}"
        	CMDR+=" -execdir rm -rfv --preserve-root {} \;"  #This will remove files
		
        	debug "Commant to run: $CMDR"

		ret_msg=`ssh ${REMOTE_HOST} "$CMDR" 2>&1`

		debug "Remote remove returned($ret_st): $ret_msg"
	fi
}

e "Starting remote backup for node $NODEID, pgpool server is $POOLIP"

#Checking if current node is standby node
e "Checking if current node is standby"
debug "Running: ssh $POOLIP \"/opt/serverscripts/utils/cluster/database/pgpool/pcp_node_info $NODEID\" 2>&1"
CH_CMD=`ssh $POOLIP "/opt/serverscripts/utils/cluster/database/pgpool/pcp_node_info $NODEID" 2>&1`
ret_msg=$?

debug "$CH_CMD"

if [ $ret_msg -ne 0 ] || [ "X$CH_CMD" == "X" ];then
	error "Chek returned error or no standby node found($ret_msg): $CH_CMD"
	exit 1
fi

if [ `echo -e "$CH_CMD" | awk '{print $2}'` -ne $NODEID ]; then
	error "Node id $NODEID is not equal to id from checker: $CH_CMD"
	exit 1
fi 

if [ "`echo -e "$CH_CMD" | awk '{print $3}'`" != "$HOSTNAME" ]; then
	error "Hostname $HOSTNAME is not equal to hostname from checker: $CH_CMD"
	exit 1
fi

if [ "`echo -e "$CH_CMD" | awk '{print $5}'`" != "standby" ]; then
	error "Node $HOSTNAME is not standby node"
	exit 1
fi

if [ ! -d $TEMPDIR ];
then
        e "Creating temp dir: $TEMPDIR"
        mkdir -p $TEMPDIR 2>&1
fi

if [ ! -f $EXCLUDES ];
then
        e "Creating blank exclude file: $EXCLUDES"
        touch $EXCLUDES
fi


e "Running backup"
first_stage 
second_stage 
remote_backup "link"
#backup
remove_old_remote "${REMOTE_DIR}increment/"

e "Backup completed"

exit 0

