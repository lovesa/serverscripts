#!/bin/sh

. /opt/serverscripts/utils/functions.sh

DEFLOG=/var/log/services/recalc.log.%Y-%m-%d


e "Recal service called"
ret_msg=`ps aux | grep php | grep recalc`
if [ -z "$ret_msg" ]; then
	before="$(date +%s)"
	
	e "Starting recalc"

	ret_msg=`php recalc.php`
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
