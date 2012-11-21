#! /bin/sh
# Failover command for streaming replication.
# This script assumes that DB node 0 is primary, and 1 is standby.
# 
# If standby goes down, do nothing. If primary goes down, create a
# trigger file so that standby takes over primary node.
#
# Arguments: $1: failed node id. $2: new master hostname. $3: path to
# trigger file.

SSH=/usr/bin/ssh
LOG=/var/log/pgpool/failback.log
TRIGGER=/var/log/pgpool/trigger

function e {
   echo -e "*INFO[" $(date "+%F %T") "]:" $1 >> $LOG
   echo -e "*INFO[" $(date "+%F %T") "]:" $1
}
function die {
   echo -e "!!!ERROR[" $(date "+%F %T") "]:" $1 >> $LOG
   echo -e "!!!ERROR[" $(date "+%F %T") "]:" $1
   exit 1
}

if [ $# -ne 5 ]; then
  die "Argument count is less than 5"
fi

nodeid=$1
node=$2
hostname=$3
new_master_id=$4
old_master_id=$5

e "Starting failback for node: $node"

# Do nothing if standby goes down.

if [ $nodeid = $old_master_id ]; then
	e "Node $nodeid was old master, so deleting trigger"	
	e "Executing command: $SSH $hostname \"rm -f $TRIGGER\" >> $LOG 2>&1" >> $LOG
	#$SSH $hostname "rm -f $TRIGGER" >> $LOG 2>&1
exit 0;

fi
e "End of failback" >> $LOG
