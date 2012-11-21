#!/bin/sh

. /opt/serverscripts/utils/functions.sh
DEBUG=1

imeiFile=./imei
logfile=./objects

e "Starting logparser"

if [ ! -f $imeiFile ]; then
	error "No file $imeiFile"
	exit
fi

e "Found $(cat $imeiFile | wc -l) imeis"

for imei in $(cat $imeiFile)
do
	ret_msg=""
	found=""
	for file in $(ls -1 ./data/ | sort)
	do
		e "Processing file $file"
		if [ -f ./data/$file ]; then
			ret_msg=`cat ./data/$file | grep -e "SELECT.*,$imei::bigint.*\n.*" -A 1| tail -n1 | awk '{print $15}'`
			if [ "X$ret_msg" != "X" ]; then
				oldObject=$ret_msg
				found="1"

				e "Found old object $oldObject for imei: $imei"
				
				ret_msg=`psql postgres -c "SELECT id FROM object WHERE imei='$imei';"`
				ret_msg=`echo -e $ret_msg | awk '{print $3}'`
				
				newObject=$ret_msg
				e "Found new object $newObject for imei $imei"
					
				echo "$imei $oldbject $newObject" >> $logfile
				
				if [ "$oldObject" != "$newObject" ]; then
		
					sqlFile=./sql/$imei.sql
					e "Generating sql file: $sqlFile"

cat > $sqlFile <<EOF
INSERT INTO coordinates_$newObject(object_id, satelites, altitude, speed, direction, datetime, latidute, longitude, server_datetime, old_inputs,  started, last_valid_gps_datetime, latitude_orig, longitude_orig, gsmoperator, valid, inputs, trip_type, driver_id, second_driver_id) select $newObject, satelites, altitude, speed, direction, datetime, latidute, longitude, server_datetime, old_inputs,  started, last_valid_gps_datetime, latitude_orig, longitude_orig, gsmoperator, valid, inputs, trip_type, driver_id, second_driver_id from coordinates_$oldObject;
EOF

				else
					error "Old object id is the same as new (Data corrupted)"
				fi
				break
			fi
		else
			error "No file $file found"
		fi 
	done
	if [ "X$found" == "X" ]; then
		error "No old objects found for imei: $imei"
		echo "$imei NOTFOUND NOTFOUND" >> $logfile
	fi
done

#cat Driver.log.2012-01-01 | grep -e 'SELECT.*,12207007376665::bigint.*\n.*' -A 1| tail -n1 | awk '{print $15}'
