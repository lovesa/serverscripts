#!/bin/sh
. /opt/serverscripts/utils/functions.sh

# Config
DEFLOG='/tmp/rsyncnice.log'
PROG='rsyn[c] '


# Body
PIDS=`ps aux | grep "$PROG" | awk  {'print $2'}`

if [ -z "$PIDS" ]; then
	error "No $PROG proccesses found"
	exit 1
fi

for pid in $PIDS ; do 
	kill -0 $pid > /dev/null 2>&1
	ret_st=$?

	if [ $ret_st -eq 0 ]; then
		e "Running ionice on process: $(ps aux | grep $pid)"
		ionice -c3 -p$pid
	else
		error "No pid $pid found"
	fi
done

exit 0
