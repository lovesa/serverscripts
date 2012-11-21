#!/bin/sh
# Script used for VPS node replication while using HEARTBEAT + Pacemaker + apache.vps ocf script 
# as resource. This script starts from /etc/cron.replication/ folder
# Script replicates from master HW (on which service started, to standby node)
. /opt/serverscripts/utils/functions.sh

DEBUG=1
DEFLOG=/var/log/replication.log

if [ -z "$1" ]; then
	e "No VPS id specified"
	exit 1
fi

if [ -z "$2" ]; then
	e "No standby node specified"
	exit 1
fi

VPS=$1
NODE=$2
DEFLOG=/var/log/replication_$VPS.log.%Y-%m-%d
RSYNC=/usr/bin/rsync
RSYNC_C='-aH --delete-after'
FROM="/vz/private/$VPS/" 
TO="${NODE}:/vz/private/${VPS}/"
 
EXCLUDE=' --exclude=ifcfg-*'
EXCLUDE+=' --exclude=/etc/hosts'
EXCLUDE+=' --exclude=/proc/*'
#EXCLUDE+=' --exclude=logs/*'
EXCLUDE+=' --exclude=tmp/*'
EXCLUDE+=' --exclude=var/log/*'
EXCLUDE+=' --exclude=/var/lib/php/session/*'
EXCLUDE+=' --exclude=var/lock/subsys/*'

if [ ! -z "${NODE}" ] || [ ! -z "${VPS}" ]; then
	
	if [ ! -d $FROM ]; then
		error "Not a directory ${FROM}"
		exit 1
	fi

	e "Starting remote replication for VPS: $VPS to node: $NODE"

	before="$(date +%s)"
	# Starting replication using rsync

	e "ionice -c 3 $RSYNC $EXCLUDE $RSYNC_C $FROM $TO"

	ionice -c 3 $RSYNC $EXCLUDE $RSYNC_C $FROM $TO 2>&1

	after="$(date +%s)"
	elapsed_seconds="$(expr $after - $before)"

	e "Replication completed, elapsed time: $elapsed_seconds s"

fi 

exit
