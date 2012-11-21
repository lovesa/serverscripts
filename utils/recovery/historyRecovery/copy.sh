#!/bin/sh

. /opt/serverscripts/utils/functions.sh

e "Starting copy process"
i=0
for file in $(ls -1 ./sql/*.sql | sort); do
	let i=$i+1
	
	e "$i Inserting file: $file"
 	psql postgres -f $file 2>&1
	e "Done"
done

