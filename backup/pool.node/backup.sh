#!/bin/sh

. /opt/serverscripts/utils/functions.sh

DEBUG=1
DEFLOG=/var/log/backupDB.log.%Y-%m-%d
ALLOWOUT=1

STANDBYID=1

if al_check_pidf; then
	error "Backup script id alredy running"
	exit 1
fi

if al_is_locked; then
	error "System is locked for a backup. HINT backup script is running!" 1
	exit 1	
fi

IP=`ifconfig eth0  | grep 'inet addr:'| cut -d: -f2 | awk '{ print $1}'`

if [ -z "$IP" ]; then
	error "Can not detect ip address"
	exit 1;
fi

STANDBY=`/opt/serverscripts/utils/cluster/database/pgpool/pcp_node_info $STANDBYID`
ret_st=$?

e "Starting backups on $IP"

if [ $ret_st -ne 0 ] || [ -z "$STANDBY" ]; then
	error "Can not detect standby node ($ret_st): $STANDBY"
	exit 1
fi

HOST=`echo -e "$STANDBY" | awk '{print $3}'`

al_create_pid_file
al_lock

e "Trying to start backup for standby node $STANDBYID on $HOST from pool($IP)"

ssh $HOST "/opt/serverscripts/backup/db.node/backupDB.sh $STANDBYID $IP" 2>&1

ret_st=$? 

if [ $ret_st -ne 0 ]; then
	error "Unexpected exit($ret_st)"
	al_unlock
	al_delete_pid_file
	exit 1
else
	e "Backup completed"
fi

e "End"

al_unlock
al_delete_pid_file

exit
