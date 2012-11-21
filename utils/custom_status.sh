#!/bin/bash

. /opt/serverscripts/utils/functions.sh

DEBUG=1
DEFLOG=/var/log/zabbix/custom.log.%Y-%m-%d
function=$1

debug "Running function $1 $2"

function last_conn() {
	netstat --numeric-ports | awk '{print $6}' | grep -v CLOSE | grep LAST | sort | uniq -c | awk '{print $1}'
}

function established_conn() {
	netstat -nat | grep -v 127.0.0.1 | awk '{print $6}' | sort | uniq -c | sort -n | grep ESTABLISHED | awk '{print $1}'
}

function freem() {
	free -m | grep Mem | gawk '{print $4}'
}

function usedm() {
	free -m | grep Mem | gawk '{print $3}'
}
function elf() {
	ps -eLf | wc -l	
}

function service() {
	local ret_stat
	local ret_msg

	if [ ! -z "$1" ]; then
		debug "Service $1"
		if [ -f /etc/init.d/$1 ]; then
			ret_msg=`/etc/init.d/$1 status 2>&1`
			
			ret_stat=$?
			debug "Ret msg: $ret_msg; Stat: $ret_stat"

			if [ $ret_stat -eq 0 ]; then
				debug "No error"
				ret_msg2=`echo "$ret_msg" | grep 'not'`
				if [ "X$ret_msg2" == "X" ]; then		
					debug "Service is running"
					echo 1
					exit
				else
					debug "Service is not running($ret_msg)"
					echo 0
					exit
				fi
			else
				debug "Service error($ret_stat) $ret_msg Or service not running"
				echo 0
				exit
			fi
		fi
		debug "No service detected"
		exit
	else
		error "No service $2 detected"
		exit 1
	fi
}

function dbpoolstat() {
	local ret_msg
	local ret_st
	local MASTER
	local SLAVE
	local dbhost
	if [ ! -z "$1" ]; then
		dbhost="$1"
	else
		dbhost="127.0.0.1"
	fi	
	
	local PSQL="psql -h $dbhost"
	debug "Psql: $PSQL"
	
	ret_msg=`$PSQL -c "SHOW pool_nodes" 2>&1`
	ret_st=$?
	if [ $ret_st -eq 0 ]; then
		MASTER=`echo "$ret_msg" | awk 'NR==3 {print $7;exit}'`
		SLAVE=`echo "$ret_msg" | awk 'NR==4 {print $7;exit}'`
		if [ ! -z "$MASTER" ] && [ ! -z "$SLAVE" ]; then
        		if [ $MASTER -gt 2 ]; then
                		if [ $SLAVE -gt 2 ]; then
					debug "All nodes are down"
                        		echo 4
                        		exit
                		else
					debug "Master is down"
                        		echo 3
                        		exit
                		fi
        		else
                		if [ $SLAVE -gt 2 ]; then
					debug "Slave is down"
                        		echo 2
                        		exit
                		else
					debug "All nodes are up"
                        		echo 1
                        		exit
				fi
                	fi
        	fi
	else
		error "Psql error($ret_st): $ret_msg"
		exit 1
	fi

}

if [ ! -z "$function" ]; then

	if fn_exists "$function"; then
		$function $2 $3 $4
	else
		error "Function $function not exists" 
	fi

else
	error "No function specified"
	exit 1
fi
