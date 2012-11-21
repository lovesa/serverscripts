#!/bin/bash

. /opt/serverscripts/utils/functions.sh

PREAMBLES=/etc/slony1-91-II/scripts/preambles
PREFIX="/etc/slony1-91-II/scripts/preamble_"

if [ -z "$1" ]; then
	error "Please provide path to sql file"
	exit 1
fi

if [ ! -f $1 ]; then
	error "Can not find $1 file"
	exit 1
fi

if [ ! -f $PREAMBLES ]; then
	error "No file for slonik preambles found"
	exit 1
fi

sql=$1

echo "Executing sql file: $sql"

header="include </etc/slony1-91-II/scripts/preamble.sk>;"

pr_inc=0

for instance in $(cat $PREAMBLES); do
	e "Found instance: $instance"
	if [ ! -z "$instance" ]; then
		preamble_file="${PREFIX}${instance}.sk"
		debug "Preamble file: $preamble_file"

		if [ ! -f $preamble_file ]; then
			error "Can not find preamble: $preamble_file"
			exit 1
		fi
		let pr_inc++
		header="${header}include <${preamble_file}>;"
	fi
done


if read -p "Slave node count is $pr_inc, do you really want to execute sql? " in &&
        [ ".$in" == ".yes" ]; then
        
	slonik <<EOF
${header}
EXECUTE SCRIPT (
   SET ID = 1,
   FILENAME = '$sql',
   EVENT NODE = 1
);
EOF

fi




#slonik <<EOF
#include </etc/slony1-91-II/scripts/preamble.sk>
#EXECUTE SCRIPT (
#   SET ID = 1,
#   FILENAME = '$PARM',
#   EVENT NODE = 1
#);
#EOF
