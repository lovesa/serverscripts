#! /bin/sh
# Failover command for streaming replication.
# This script assumes that DB node 0 is primary, and 1 is standby.
# 
# If standby goes down, do nothing. If primary goes down, create a
# trigger file so that standby takes over primary node.
#
# Arguments: $1: failed node id. $2: new master hostname. $3: path to
# trigger file.

failed_node=$1
new_master=$2
trigger_file=/var/log/pgpool/trigger
SSH=/usr/bin/ssh
TOUCH=/bin/touch
LOG=/var/log/pgpool/failover.log

function e {
  echo -e $(date "+%F %T"):  $1
}

e "Starting failover for node: $failde_node" >> $LOG

# Do nothing if standby goes down.
if [ $failed_node = 1 ]; then
	e "Failed node is standby node, master node: $new_master" >> $LOG
	exit 0;
fi

# Create the trigger file.
e "Creating trigger file for node $new_master" >> $LOG
$SSH -T $new_master $TOUCH $trigger_file >> $LOG 2>&1
e "End of failover" >> $LOG

exit 0;
