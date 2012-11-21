#!/bin/sh

active=`/opt/serverscripts/zabbix/scripts/zabix_agentd/apache2.pl http://127.0.0.1 7`
limit1=50
limit2=90
name="httpd.old."$(date "+%F_%T")
lock_file=/var/log/httpd/access_log.lock
httpd_conf=/etc/httpd/conf/httpd.conf
backup_dir=/opt/serverscripts/utils/availability/apache_restart/back/
log=/var/log/httpd/apache_restart.log
tmp=/opt/serverscripts/utils/availability/apache_restart/tmp
server_status_log=/var/log/httpd/server_status.$(date "+%F_%T").html
DEBUG=yes

function e {
  echo -e $(date "+%F %T"):  $1
}
function debug {
  if [ ! -z "$DEBUG" ]; then
	if [ "$DEBUG" == "yes" ]; then
		echo -e DEBUG: $(date "+%F %T"):  $1 >> $log
	fi
  fi
}


function backup() {
	e "Backup config file: $httpd_conf to: $backup_dir$1_$name" >> $log
	cp -f $httpd_conf $tmp/httpd.back >> $log 2>&1	 
	cp -f $httpd_conf $backup_dir$1"_"$name >> $log 2>&1
}
function rollback() {
	e "Starting rollback.." >> $log
	cp -f $tmp/httpd.back $httpd_conf >> $log 2>&1
}
function test_config() { 

	configtest=`/etc/init.d/httpd configtest 2>&1`
	debug "Configtest returned: ${configtest}"
	st1=`echo $configtest | wc -l`
	st2=`echo $configtest | awk '{ print $2 }'`
	e "Testing config, wc: $st1; status: $st2" >> $log 
	if [ "$st1" -gt "1" ] || [ "$st2" != "OK" ]; then
		e "Error occured during configtest" >> $log
		rollback
		exit 1
	fi

}

function e_httpd_access_log() {
	e "Starting access log..." >> $log
	backup "enable"	
	sed -e 's/\#CustomLog logs\/access_log common/CustomLog logs\/access_log common/gi' $httpd_conf > $tmp/httpd.conf	
	cp -f $tmp/httpd.conf $httpd_conf >> $log 2>&1
	test_config
	touch $lock_file 
	apache_reload
}
function d_httpd_access_log() {
 	e "Stoping access log..." >> $log
        backup "disable"
        sed -e 's/\CustomLog logs\/access_log common/#CustomLog logs\/access_log common/gi' $httpd_conf > $tmp/httpd.conf
        cp -f $tmp/httpd.conf $httpd_conf >> $log 2>&1	
	test_config
	rm -rf $lock_file
	apache_reload
}

function apache_reload() {
	e "Starting apache reload" >> $log
	/etc/init.d/httpd reload >> $log 2>&1
}

function apache_restart() {
	e "Starting apache restart" >> $log
	killall -9 httpd
	/etc/init.d/httpd start >> $log 2>&1
}

function log_server_status() {
	e "Logging server status" >> $log
	curl http://127.0.0.1/server-status >> $server_status_log 2>&1
}

#Checking first limit end trying to enable access log

e "Checking apache limit with current active connections $active" >> $log

if [ "$active" -ge  "$limit1" ]; then
	log_server_status
#	e_httpd_access_log
	debug "Enable access log depricated"
else 
	if [ -a /var/log/httpd/access_log.lock ]; then  #Trying to disable access log
		#d_httpd_access_log
		debug "Diable access log, depricated"
	fi
fi

if [ "$active" -ge  "$limit2" ] || [ -z "$active" ]; then
	log_server_status
	apache_restart
fi



