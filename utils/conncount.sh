#!/bin/bash

total=0
prev=`netstat -na | grep "ESTABLISHED\|TIME" | wc -l`

function e {
  echo -e $(date "+%F %T"):  $1
}
e "Starting with count of $prev"
before="$(date +%s)"
for i in {1..1000}
do
   REZ=`netstat -na | grep "ESTABLISHED\|TIME" | wc -l`
   CUR=$REZ
   #e "$i : Current count is: $CUR"
   let REZ=$REZ-$prev   

   if [ "$REZ" -gt 0 ]; then
	#e "Difference: $REZ"
	let total=$total+$REZ
   fi
 	prev=$CUR 

   let mod=$i%60
   if [ $mod -eq 0 ]; then
	after="$(date +%s)"    
	elapsed_seconds="$(expr $after - $before)" 
	let req=$total/$elapsed_seconds
        e "Sub req/s for last 60 iteration: $req"
   fi
sleep 1 
done

after="$(date +%s)"    
elapsed_seconds="$(expr $after - $before)" 
let req=$total/$elapsed_seconds

e "Total: $total, time elapsed: $elapsed_seconds s."
e "Req/s: $req"

