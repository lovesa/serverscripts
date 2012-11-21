#!/bin/sh

. /opt/serverscripts/utils/functions.sh

e "Starting node dettach"

if [ -z "$1" ]; then
	error "Please enter node ip"
	exit 1
fi

if [ -z "$2" ]; then
        error "Please enter node ID"
        exit 1
fi


NODE=$1
NODEID=$2
KEY=""

_AL_PREFIX=$1

LOCAL_SLONSCDIR="/etc/slony1-91-II/scripts/"
LOCAL_PREAMBLES=${LOCAL_SLONSCDIR}preambles

if [ ! -f $KEY ]; then
	error "No ssh key found"
	exit 1
fi

SSH="ssh -o StrictHostKeyChecking=no -i $KEY "

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

function dettach_node {
	local ret_st
        local ret_msg
	
	e "Trying to dettach node"
	
	rem_preambles	

	scriptu=${LOCAL_SLONSCDIR}/unscript_${NODEID}.sk

	if [ ! -f $scriptu ]; then
		error "No dettach slony script found($scriptu)"
		exit 1
	fi 

	$scriptu
	e "Stopping slony"

	ret_msg=`$SSH $NODE "/etc/init.d/slony1-91-II stop"`
	ret_st=$?

	if [ $ret_st -ne 0 ]; then
		error "Slony stop error($ret_st):$ret_msg"
		exit 1
	fi
	e "Dropping postgres connections"
	
	ret_msg=`$SSH $NODE "/etc/init.d/postgresql-9.1 restart"`
        
        ret_st=$?

        if [ $ret_st -ne 0 ]; then
                error "Drop connections error($ret_st):$ret_msg"
                exit 1
        fi	
	
	sleep 10

	e "Dropping database"
	
	ret_msg=`$SSH $NODE "dropdb -U postgres"`
	
	ret_st=$?

        if [ $ret_st -ne 0 ]; then
                error "Drop db error($ret_st):$ret_msg"
                exit 1
        fi

	e "Stopping postgres"

	$SSH $NODE "/etc/init.d/postgresql-9.1 stop"	

	e "Dettach done"

}	
function rem_preambles {
        sed -i 's/${NODEID}//g' $LOCAL_PREAMBLES
}


if check_ssh; then

	dettach_node	
else
	exit 1
fi
