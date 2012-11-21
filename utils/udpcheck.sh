#!/bin/sh
. /opt/serverscripts/utils/functions.sh

DEFLOG=/var/log/udpcheck.log.%Y-%m-%d

DEBUG=1

if [ -z "$1" ] || [ -z "$2" ]; then
    error "No parameters specified"
fi

server=$1
port=$2

TEST=`nc -zv -w1 -u $server $port 2>&1`
ret_st=$?

debug "Test returned($ret_st): $TEST"

if [ $ret_st -eq 0 ]; then
    TEST="OK"
else
    TEST="FAILED"
fi

e "$server:$port test $TEST"

echo $TEST

#if [ $TEST == "1" ]; then
#        echo "OK"
#    else
#        echo "FAIL"
#fi

