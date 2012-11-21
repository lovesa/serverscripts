#!/bin/bash

###
# chkconfig: 2345 99 12 
# description: Apache+pgpool VPS startup and status script
###
: ${OCF_FUNCTIONS_DIR=${OCF_ROOT}/lib/heartbeat}
. ${OCF_FUNCTIONS_DIR}/ocf-shellfuncs
. /opt/serverscripts/utils/functions.sh


##### CONFIGURATION SECTION
DEBUG=1

VZCTL=/usr/sbin/vzctl							#OpenVZ VZCTL utility
VZLIST=/usr/sbin/vzlist							#OpenVZ VZLIST utility

DEFLOG="/var/log/ha.%Y-%m-%d"						#Default LOG file path (Support rotatelog syntax)

apache_limit=3								#Apache monitoring connection limit
apache_it=5								#Apache connections tests count

MONITOR=/opt/serverscripts/utils/apache_monitor.sh			#Apache monitoring tool
REPLICATOR=/opt/serverscripts/cluster/replication/replicate_node.sh	#Replication utility, based on rsync
CRONDIR=/etc/cron.replication						#Replication cron dir

#### FUNCTIONS

function validate {							#Configuration validation function
	#Checking vps id
	if [ -z "$OCF_RESKEY_vps" ]; then
		error "No VPS id specified"
		exit $OCF_ERR_CONFIGURED
	else
		if ! ocf_is_decimal $OCF_RESKEY_vps; then
			error "No VPS id is not numeric (${OCF_RESKEY_vps})"
                	exit $OCF_ERR_CONFIGURED
		else
			VPS=$OCF_RESKEY_vps
			_AL_PREFIX=$VPS
			DEFLOG="/var/log/ha_${VPS}.%Y-%m-%d"
		fi
	fi

	#Checking utilities
	if [ ! -x $MONITOR ]; then
                error "Can't find monitoring utility.."
                exit $OCF_ERR_INSTALLED
        fi
	if [ ! -x $REPLICATOR ]; then
		error "Can't find VPS replication utility.."
		exit $OCF_ERR_INSTALLED
	fi
	if [ ! -d $CRONDIR ]; then
		error "No cron directory for replication.."
		exit $OCF_ERR_INSTALLED
	fi

	#Checking apache connections limit	NOT REQUIRED
	if [ -z "$OCF_RESKEY_apache_limit" ]; then
                if [ ! -z "$OCF_RESKEY_apache_limit_default" ]; then
                        debug "Using default Apache connections limit value: ${OCF_RESKEY_apache_limit_default}"
                        apache_limit=$OCF_RESKEY_apache_limit_default}
                else
                        e "No Apache connections limit specified, using script specified: ${apache_limit}"
                fi
        else
                debug "Using specified Apache connections count value: ${OCF_RESKEY_apache_limit}"
                apache_limit=$OCF_RESKEY_apache_limit
        fi
	
	#Checking apache connections count      NOT REQUIRED
        if [ -z "$OCF_RESKEY_apache_it" ]; then
                if [ ! -z "$OCF_RESKEY_apache_it_default" ]; then
                        debug "Using default Apache connections count value: ${OCF_RESKEY_apache_it_default}"
                        apache_it=$OCF_RESKEY_apache_it_default}
                else
                        e "No Apache connections count specified, using script specified: ${apache_it}"
                fi
        else
                debug "Using specified Apache connections count value: ${OCF_RESKEY_apache_it}"
                apache_limit=$OCF_RESKEY_apache_it
        fi
	return $OCF_SUCCESS
}

start_replication() {							#Replication support function

local NODES
local COUNT
local HOSTNAME
local NODEN

	e "Starting replication"
	
	#Checking which node is standby
	NODES=`crm_mon -1 | grep Online | sed -r 's/.*\[(.*)\]/\1/'`
	COUNT=`echo ${NODES} | wc -w`
	HOSTNAME=`uname -n`

	if [ ! -z "${COUNT}" ]; then
        	if [ $COUNT -ge 2 ]; then
                	for NODEN in $NODES
                	do
                        	if [ "${NODEN}" != "${HOSTNAME}" ]; then
                                	
					e "Slave node is ${NODEN}"

					e "Trying to deploy replication script"
					
					if [ ! -z "${CRONDIR}" ]; then

						cat > $CRONDIR/replicate_$VPS.cron <<EOF
#!/bin/sh
${REPLICATOR} ${VPS} ${NODEN} >> /var/log/replication_${VPS}.log 2>&1

EOF
						debug "File creted $CRONDIR/replicate_$VPS.cron"						
						debug "Chmod +x $CRONDIR/replicate_$VPS.cron"

						chmod +x $CRONDIR/replicate_$VPS.cron
						
						if [ $? -eq 0 ]; then
							e "Replication added"
						else
							error "Error occured during replication add($?)"
						fi
					else
						error "Settings error"
					fi
	
                        	fi
                	done

        	else
			error "Only one node is online ${COUNT}"
		fi
	else
		error "Can not count online nodes"
	fi


	return $OCF_SUCCESS
}

stop_replication() {				
	e "Stoping replication"
	
	if [ ! -z "${CRONDIR}" ]; then	
		e "unlink ${CRONDIR}/replicate_${VPS}.cron"
		unlink ${CRONDIR}/replicate_${VPS}.cron		
		
		if [ $? -eq 0 ]; then
			e "Replication stoped"
		else
			error "Error occured during replication stop($?)"
		fi
	else
		error "Settings error"		
	fi

	return $OCF_SUCCESS
}

# VPS startup 
start() {								#VPS startup function, uses vzctl to start VPS
	local vz_msg
	local vz_ret

 	debug "Starting resource"	
	
	#validating 

	validate || exit $?
	
	if status; then
		e "Resource is running"
		return $OCF_SUCCESS
	fi
	
	debug "Running vzctl"

        vz_msg=`$VZCTL start $VPS`
	vz_ret=$?
	 
	debug "$vz_msg"

	if [ $vz_ret -ne 0 ]; then
		error "Vzctl returned error: $vz_ret"
		return $OCF_ERR_PERM
	fi
	#ifconfig veth${VPS}.0 up
	#e "Adding veth${VPS}.0 into ${BRIDGE}"
	#brctl addif ${BRIDGE} veth${VPS}.0 
        #e "Sleeping 20s"
	#sleep 20s
	#e "Starting pgpool"
	#$VZCTL exec $VPS /etc/init.d/pgpool start
	 
	debug "Going to while"
	while ! status; do
        	e "Resource has not started yet, waiting"
        	sleep 1
    	done
	
	debug "Resource started"

	start_replication

        return $OCF_SUCCESS
}

# VPS stop
stop() {								#VPS stop function
	local vz_msg
	local vz_ret

	debug "Perform STOP of resource"
	
	#Validate
	validate || exit $?

	status
    	rc=$?
    	case "$rc" in
        	"$OCF_SUCCESS")
            	# Currently running. Normal, expected behavior.
            	e "Resource is currently running"
            	;;
        	"$OCF_NOT_RUNNING")
            	# Currently not running. Nothing to do.
            	e "Resource is already stopped"
            	return $OCF_SUCCESS
            	;;
    	esac
	
	debug "Stop VPS $VPS"
	
	vz_msg=`$VZCTL stop $VPS`
	vz_ret=$?

	debug "$vz_msg"

	if [ $vz_ret -ne 0 ]; then
		error "Can not stop VPS, vzctrl returned $vz_ret. HINT - unmount problem?"
		debug "Trying to wait a little bit..."
		sleep 5
		debug "Trying to get status, determine if VPS is not really stopped"
		if status; then
			error "VPS is not really stopped" 
			return $OCF_ERR_PERM
		fi
	fi
	
	while status; do
        	e "Resource has not stopped yet, waiting"
        	sleep 1
    	done
	
	debug "Resource is stopped"
	stop_replication
	return $OCF_SUCCESS
}

# VPS status
 
status() {								#Basic resource status monitoring
local PING
	local vz_msg
	local vz_ret

	debug "Starting status check"
	
	#Validate
        validate || exit $?

	#Checking if VPS is running
	vz_msg=`${VZLIST} ${VPS} -o status`
	vz_ret=$?

	if [ $vz_ret -eq 0 ]; then
		STATUS=`echo $vz_msg | tail -1 | awk '{print $2}'`
		debug "Got status of vps: ${STATUS}";

		if [ -z "${STATUS}" ] || [ "${STATUS}" != "running" ]; then
			e "VPS is not running: ${STATUS}"
			return $OCF_NOT_RUNNING
		fi
	else
		error "Failed: ${VZCTL} returned $vz_ret"
		return $OCF_ERR_PERM 
	fi
	
 	# Getting ip address of the VPS
	SIP="`${VZLIST} ${VPS} | grep ${VPS} | awk '{print \$4}'`"
	if [ -z "$SIP" ] || [ "$SIP" == "-" ]; then
		SIP="`${VZCTL} exec ${VPS} ifconfig eth0  | grep 'inet addr:'| cut -d: -f2 | awk '{ print $1}'`"
		if [ -z "$SIP" ]; then
			error "Can not determine VPS(${VPS}) IP"
			return $OCF_ERR_PERM
		fi
	fi	
	debug "Got ip of VPS: ${SIP}"
	
	debug "Runing ping ${SIP}"

	PING=`/bin/ping -q -n -c 5 ${SIP} | grep "packet loss" | cut -d " " -f 6 | cut -d "%" -f1`
	
	debug "Packet lost: ${PING}"

	if [ $? -eq 0 ]; then
		if [ $PING -gt 50 ]; then
			e "Node not started yet, or network error"
			return $OCF_NOT_RUNNING	
		fi
	else
		error "Failed to ping, returned $?"
		return $OCF_ERR_PERM
	fi	
	e "Resource is running"

	return $OCF_SUCCESS
	
}

monitor() {								#Monitoring function
	local mon_msg
	local mon_rez
	
 	debug "Starting monitoring"
	
	#validating 

        validate || exit $?

	if status; then
                e "Resource is running"
		
		if [ ! -z "$SIP" ]; then
			debug "Running apache_check"
			
			mon_msg=`$MONITOR -i $SIP -c $apache_limit -j $apache_it`
				
			mon_rez=$?
			
			debug "$mon_msg"

			if [ $mon_rez -ne 0 ]; then
				error "Monitoring error: $mon_rez"
				return $mon_rez				
			fi

			e "Monitoring success"
			return $OCF_SUCCESS
			
		else
			error "Can not determine VPS ip"
			return $OCF_ERR_PERM
		fi
        else
		return $OCF_NOT_RUNNING
	fi

}

function meta() {
debug "Retrieving meta-data"
cat <<EOF
<?xml version="1.0"?>
<!DOCTYPE resource-agent SYSTEM "ra-api-1.dtd">
<resource-agent name="apache.vps" version="0.1">
  <version>0.1</version>
  <longdesc lang="en">
This is a apache VPS reource agent. This this agent you can start/stop apache VPS 
with Pgpool, also status monitoring is available
  </longdesc>
  <shortdesc lang="en">Apache VPS agent</shortdesc>
  <parameters>
    <parameter name="vps" unique="0" required="1">
      <longdesc lang="en">
      VPS id
      </longdesc>
      <shortdesc lang="en">VPS id</shortdesc>
      <content type="integer"/>
    </parameter>
    <parameter name="apache_limit" unique="0" required="0">
      <longdesc lang="en">
      Apache connections allowed
      </longdesc>
      <shortdesc lang="en">Apache connections limit</shortdesc>
      <content type="integer" default="100"/>
    </parameter>
    <parameter name="apache_it" unique="0" required="0">
      <longdesc lang="en">
      Apache connections tests count
      </longdesc>
      <shortdesc lang="en">Apache connections tests count</shortdesc>
      <content type="integer" default="5"/>
    </parameter>
  </parameters>
  <actions>
    <action name="start"        timeout="20" />
    <action name="stop"         timeout="20" />
    <action name="monitor"      timeout="20"
                                interval="10" depth="0" />
    <action name="meta-data"    timeout="5" />
  </actions>
</resource-agent>
EOF
}

function usage() {
	echo $"Usage: apache.vps {start|stop|status}"
}

# See how we were called.

case $__OCF_ACTION in
	meta-data)	meta
			exit $OCF_SUCCESS
			;;
	start)          start
			;;
	stop)           stop
			;;
	status) 	status
			;;
	monitor)	monitor
			;;
	*)		uage
			exit $OCF_SUCCESS
			;;
esac
rc=$?

# The resource agent may optionally log a debug message
debug "${OCF_RESOURCE_INSTANCE} $__OCF_ACTION returned $rc"
exit $rc

