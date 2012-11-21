#!/bin/bash

MAXCOUNT=60
RANGE=500
SLEEP=60
float_scale=3
result='/tmp/result'

let "ISLEEP=60/$MAXCOUNT"

function float_eval()
{
    local stat=0
    local result=0.0
    if [[ $# -gt 0 ]]; then
        result=$(echo "scale=$float_scale; $*" | bc -q 2>/dev/null)
        stat=$?
        if [[ $stat -eq 0  &&  -z "$result" ]]; then stat=1; fi
    fi
    echo $result
    return $stat
}

while /bin/true; do
count=1
timeT=0
	while [ "$count" -le $MAXCOUNT ]; do
		number=$RANDOM
		let "number %= $RANGE"
		#echo "curl -O http://mt3.ruptela.lt/dt/09/000/325/000/$number.png"
		timeC=`curl -s -w "%{time_total}\n" -o /dev/null  http://mt3.ruptela.lt/dt/09/000/325/000/$number.png`
		echo "Time local: $timeC"
		timeT=$(float_eval "$timeT+$timeC")
		let "count += 1"
		echo "Sleeping: $ISLEEP s"
		sleep $ISLEEP
	done
    timeT=$(float_eval "$timeT/$MAXCOUNT")
	echo "RESULT: $(date +'%F %H:%M:%S') $timeT" >> $result
	
	echo "Sleeping $SLEEP s between iterations"
	sleep $SLEEP
done
