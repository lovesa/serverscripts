#!/bin/bash
# Apache tester

. /opt/serverscripts/utils/functions.sh

WEIGHT=0
DEBUG=1
LAST=0
ALLOWOUT=1
DEFLOG=/var/log/apache_checker.log.%Y-%m-%d

SERVER_IP=
BWORKERSMAX=3
ITCOUNT=1

max=7

function usage() {
cat << EOF
usage: $0 [-h] -i IP  [-c MaxBusyWorkers] [-j IterationCount]

This is apache server testing utility

OPTIONS:
    -h      Show this message
    -i	    Server Ip address
    -c      Maximum allowed busy workers count
    -j      Test iteration count
EOF
}


while getopts “hi:c:j:” OPTION
do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
         i)
             SERVER_IP=$OPTARG
             ;;
         c)
             BWORKERSMAX=$OPTARG
             ;;
	 j)
	     ITCOUNT=$OPTARG
	     ;;
         ?)
             usage
             exit
             ;;
     esac
     if [ $OPTIND -gt $max ]

        then
                let "max=$OPTIND-1"

        fi
done

shift $max

if [[ -z "$@" ]]; then
        usage
        exit
fi


function check_server_status() {
	local busy_workers
	local wg
	
	if [ ! -z "$1" ]; then
		debug "Trying to get server status from: http://$1/server-status?auto" 
		busy_workers=`curl http://${1}/server-status?auto 2>&1`
			
		if [ $? -eq 0 ]; then
			e "Server is responding =)"
				
			busy_workers=`echo -e "$busy_workers" | grep "BusyWork" | awk '{print $2}'`
			
			if [ ! -z "$busy_workers" ]; then 
				debug "Got apache BusyWorkers count: ${busy_workers}"
				let "wg=busy_workers-LAST"
				debug "Local weight: ${wg}"
				let "WEIGHT = WEIGHT+wg"
			
				LAST=$busy_workers
			else
				error "Can not determine BusyWorkers count" 5
			fi
		else
			error "Can not determine busy workers count. Possible timeout or 404 error, or server unavailable" 1
		fi
	else
		error "No enough parameters" 3
	fi
}
debug "Apache check called"
#Determine working state
check_server_status $SERVER_IP

	WEIGHT=0
	sleep 1

	debug "Trying to get weight of apache load for ${ITCOUNT} iterations and busy workers: ${BWORKERSMAX}"
	#Rechecking iterations
	for i in `seq 1 $ITCOUNT`
	do
		check_server_status $SERVER_IP $BWORKERSMAX
		sleep 1
	done
	#let "IT=ITCOUNT1"

debug "Summ weight: ${WEIGHT}"

let "WEIGHT=WEIGHT/ITCOUNT"

debug "It count: ${ITCOUNT}"
debug "Weight: ${WEIGHT}"

if [ $WEIGHT -ge $BWORKERSMAX ]; then
	error "Weight is greater thant $BWORKERSMAX"
	exit 1
fi

exit 0
