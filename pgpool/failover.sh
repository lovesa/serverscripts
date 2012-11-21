#! /bin/sh
# Failover command for streaming replication.
# This script assumes that DB node 0 is primary, and 1 is standby.
# 
# If standby goes down, do nothing. If primary goes down, create a
# trigger file so that standby takes over primary node.
#
# Arguments: $1: failed node id. $2: new master hostname. $3: path to
# trigger file.

. /opt/serverscripts/utils/functions.sh

SSH=/usr/bin/ssh
DEFLOG=/var/log/pgpool/failover.log
TRIGGER=/var/log/pgpool/trigger
ALLOWOUT=1

if [ $# -ne 5 ]; then
   "Argument count is less than 5"
fi

failed_node_id=$1
failed_node=$2
new_master=$3
new_master_id=$4
old_master_id=$5

e "Starting failover for node: $failed_node"
e "Incoming data:"
e "    *failed_node_id- $failed_node_id"
e "    *failed_node   - $failed_node"
e "    *new_master    - $new_master"
e "    *new_master_id - $new_master_id"
e "    *old_master_id - $old_master_id"

if [ -z "$new_master" ]; then
	error "Sorry it seems that all nodes are down...=(" 1
	exit 1;
fi

# Do nothing if standby goes down.

if [ ! $failed_node_id = $old_master_id ]; then
	error "Failed node is standby node, master node: $new_master" 0
	exit 0;
fi

# Create the trigger file.
e "Creating trigger file for node $new_master"
e "Executing command: $SSH $new_master \"touch $TRIGGER\""
$SSH $new_master "touch $TRIGGER" >> $DEFLOG 2>&1
if [ $? -ne 0 ]; then
  error "Error during ssh on failover" 1
fi
e "Trigger file created."
e "Trying to stop postgres on $failed_node"

ssh $failed_node "/etc/init.d/postgresql-9.1 stop" >> $DEFLOG 2>&1

e "End of failover"

exit 0
