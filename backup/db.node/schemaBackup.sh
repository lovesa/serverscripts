#!/bin/bash

. /opt/serverscripts/utils/functions.sh

DEBUG=1
DEFLOG=/var/log/backup.log.%Y-%m-%d

SCHEMA=""
PSQL="pg_dump -F c -U postgres preproduction -n $SCHEMA"
GZIP="gzip -q -1"
FILE="/tmp/schema.$(date "+%Y-%m-%d").sql.gz"
NICE="nice -n 3"

CMD="$NICE $PSQL"

e "Starting schema backup"

debug "Running $CMD | $GZIP > $FILE"

$CMD | $GZIP > $FILE

if [ $? -ne 0 ];then
        error "Error during backup"
	exit 1
fi

