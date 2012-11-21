#/bin/sh -x
. /opt/serverscripts/utils/functions.sh

datadir=$1
desthost=$2
destdir=$3
DEFLOG=/var/log/pgpool/recovery.log
ROPTS="-vCaWih --progress --delete-after"
ALLOWOUT=1
DEBUG=1

REXCL="--exclude postmaster.pid"
REXCL+=" --exclude postmaster.opts --exclude pg_log --exclude pg_xlog"
REXCL+=" --exclude basebackup.sh"
REXCL+=" --exclude pgpool_remote_start"
REXCL+=" --exclude postgresql.conf"
REXCL+=" --exclude pg_hba.conf"
REXCL+=" --exclude pg_ident.conf"
REXCL+=" --exclude recovery.conf"

e "==============================================="
e "Starting recovery process on $desthost by user $(id -un)"
e "==============================================="

e "Trying to kill postgress if running"
e "Executing ssh $desthost /etc/init.d/postgresql-9.1 stop" 

ret_msg=`ssh $desthost "/etc/init.d/postgresql-9.1 status" 2>&1`

ret_st=$?

debug "Postgres status($ret_st): $ret_msg"

if [ "X$ret_msg" != "X" ]; then
	egrep_rez=`echo "$ret_msg" | egrep "dead|not running|stopped"`
	
	if [ "X$egrep_rez" == "X" ]; then
		ssh $desthost "/etc/init.d/postgresql-9.1 stop" >> $DEFLOG 2>&1
 
		if [ $? -ne 0 ]; then
   			error "Can not stop postgres during basebackup or postgres error" 1
		fi

		
	else
		e "Postgres stopped ($egrep_rez)"
	fi
else
	error "Empty status with error($ret_st) during basebackup status check" 1
fi

e "Running sql: SELECT pg_start_backup('Streaming Replication', true)"

psql -c "SELECT pg_start_backup('Streaming Replication', true)" postgres >> $DEFLOG 2>&1

e "Running rsync $ROPTS $REXCL $datadir/ $desthost:$destdir/"

before="$(date +%s)"

rsync $ROPTS $REXCL $datadir/ $desthost:$destdir/ >> $DEFLOG 2>&1

if [ $? -ne 0 ] || [ $? -ne 24 ]; then
	error "Rsync error during basebackup" 1
fi 


after="$(date +%s)"
elapsed_seconds="$(expr $after - $before)"

e "Done rsync. Elapsed time: $elapsed_seconds s."


#rsync -v -C -a -W -i -h --progress --delete --exclude postmaster.pid \
#--exclude postmaster.opts --exclude pg_log --exclude pg_xlog \
#--exclude basebackup.sh \   
#--exclude pgpool_remote_start \
#--exclude postgresql.conf \
#--exclude recovery.conf $datadir/ $desthost:$destdir/ >> $LOG 2>&1


#ssh -T localhost mv $destdir/recovery.done $destdir/recovery.conf

e "Running several ssh commands on $desthost"

e "rm -rf $destdir/pg_xlog"
ssh $desthost "rm -rf $destdir/pg_xlog" >> $DEFLOG 2>&1
e "mkdir $destdir/pg_xlog"
ssh $desthost "mkdir $destdir/pg_xlog" >> $DEFLOG 2>&1
e "chmod 700 $destdir/pg_xlog"
ssh $desthost "chmod 700 $destdir/pg_xlog" >> $DEFLOG 2>&1
e "rm $destdir/recovery.done"
ssh $desthost "rm $destdir/recovery.done" >> $DEFLOG 2>&1
e "Creating recovery.conf"

cat > $datadir/recovery.$desthost <<EOF
standby_mode          = 'on'
primary_conninfo      = 'host=$(hostname) port=5432'
trigger_file = '/var/log/pgpool/trigger'
EOF

e "Trying to scp"
scp $datadir/recovery.$desthost $desthost:$destdir/recovery.conf >> $DEFLOG 2>&1
if [ $? -ne 0 ]; then
	error "SCP error during basebackup"
fi

psql -c "SELECT pg_stop_backup()" postgres

e "===================================================="
e "Stoping recovery..."
e "===================================================="

exit 0
