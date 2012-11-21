#!/bin/sh

. /opt/serverscripts/utils/functions.sh

DEFLOG=/var/log/csync.cron.log.%Y-%m-%d

if [ -z "$1" ]; then
    error "Provide a group"
    exit 1
fi

e "Csync service called"
ret_msg=`ps aux | grep csync2 | grep $1`
if [ -z "$ret_msg" ]; then
	before="$(date +%s)"
	
	e "Starting csync"

	ret_msg=`/usr/sbin/csync2 -xv -G $1`
	ret_st=$?

	if [ $ret_st -ne 0 ]; then
		error "Erro in recalc($ret_st): $ret_msg"
	fi		

	after="$(date +%s)"
	elapsed_seconds="$(/usr/bin/expr $after - $before)"
	e "Elapsed time: $elapsed_seconds"
else
	error "Proccess is running: $ret_msg"
	exit
fi

exit
