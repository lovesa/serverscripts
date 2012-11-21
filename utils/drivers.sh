#!/bin/bash
. /opt/serverscripts/utils/functions.sh
DEBUG=1

FOUND=`find /opt/*/bin/ -regextype posix-egrep -regex "/opt/([a-zA-Z0-9_+]+)/bin/\1" -perm /222`

if [ $? -ne 0 ]; then
	error "Error during find command: $FOUND"
	exit 1
fi


for i in $FOUND
  do
	e "Running $i $1"
	$i $1
  done

e "Done"
exit
