# Make sure umask is sane
umask 022

# Set up a default search path.
PATH="/sbin:/usr/sbin:/bin:/usr/bin"
export PATH

######################## DEFAULT STATIC VARIABLES ####
_AL_PID_DIR=/var/run/
_AL_LOCK_DIR=/var/lock/subsys
######################################################

if [ -r /opt/serverscripts/utils/environment ]; then
	. /opt/serverscripts/utils/environment
fi

_AL_CFG_PHP=someconfig.php

if [ -f /opt/serverscripts/utils/smsrelay.php ]; then
	_AL_SP_PHONE=$_AL_DEF_SP_PHONE
	_AL_SMS_RELAY=/opt/serverscripts/utils/smsrelay.php
fi

########################### DYNAMIC VARIABLES #####

_AL_SCRIPT_NAME=$(basename $(readlink -nf $0))
_AL_PID=`pgrep $_AL_SCRIPT_NAME | awk '{print $1}' | head -1`

if [ ! -z "$_AL_PID_DIR" ]; then
	_AL_PID_FILE="${_AL_PID_DIR}${_AL_SCRIPT_NAME}"
fi

if [ ! -z "$_AL_LOCK_DIR" ]; then
	_AL_LOCK_FILE="${_AL_LOCK_DIR}${_AL_SCRIPT_NAME}"
fi

###################################################

fn_exists() { 				  #Function check if function exists
  # appended double quote is an ugly trick to make sure we do get a string -- if $1 is not a known command, type does not output anything
  [ `type -t $1`"" == 'function' ]
}

al_reinit() {
	_AL_SCRIPT_NAME=$(basename $(readlink -nf $0))
	_AL_PID=`pgrep $_AL_SCRIPT_NAME`
	_AL_PID_FILE="${_AL_PID_DIR}${_AL_SCRIPT_NAME}"
	_AL_LOCK_FILE="${_AL_LOCK_DIR}${_AL_SCRIPT_NAME}"
}




### Report functions ############################################################################
#################################################################################################

function sp_report_phone() {
	if [ ! -z "$_AL_SP_PHONE" ]; then
		if [ ! -z "$1" ]; then
			echo -e "$1\n" >> /tmp/smsrelay.log
			nohup $_AL_SMS_RELAY $_AL_SP_PHONE "$(hostname) $1" >> /tmp/smsrelay.log 2>&1 &
		fi
	fi 
}

#### Echo functions #############################################################################
#################################################################################################
### Functions require $DEFLOG to be set if you want to write log to file
### Otherwice message would apear in the STDOUT
### Logger supports $RUNUSER variable to be set for su $RUNUSER commands
### Pacemaker OCF functions also supported
#################################################################################################

function aleks_logger() {				#Output logger, $DEGLOG must be defined
        local data				#otherwice logs to STDOUT
	local ocf_level

        if [ -z "$1" ]; then
                data="[Empty set]"      
        else
                data=$1
        fi

	if [ -z "$2" ]; then
		ocf_level="info"
	else
		ocf_level=$2
	fi
	
                if [ ! -z "$DEFLOG" ]; then  # If log file exists and writable
                        if [ ! -z "$(echo $DEFLOG | grep '%')"  ]; then
                                if [ ! -z "$RUNUSER" ]; then
					su -c "echo -e \"$data\" | rotatelogs -l $DEFLOG 86400" $RUNUSER
				else
					echo -e "$data" | rotatelogs -l $DEFLOG 86400
				fi
                        else
				if [ ! -z "$RUNUSER" ]; then
					su -c "echo -e \"$data\" >> $DEFLOG" $RUNUSER
				else
                                	echo -e "$data" >> $DEFLOG
				fi
                        fi
                else
			echo -e "$data"
		fi

	if [ ! -z "$ALLOWOUT" ]; then	
		if [ "$ALLOWOUT" == "1" ]; then
			echo -e "$data"
		fi
        fi
       
	if fn_exists "ocf_log"; then  #OCF required output fog Pacemaker
        	ocf_log $ocf_level $data
        fi
}


function debug() { 			    #Debug function, variable $DEBUG must be set in script
	local data
	local ec

        if [ ! -z "$DEBUG" ]; then
		ec="**DEBUG[$(date "+%F %T")] : "

		if [ ! -z "$_AL_PREFIX" ]; then
			ec+="[$_AL_PREFIX] : "
		fi

		if [ -z "$1" ]; then
			while read data
			do
				ec+="$data\n"
			done
		else
			ec+=$1 
		fi
		aleks_logger "$ec" "debug"
        fi
}

function e() {				   	#Echo function 
	local data
	local ec

	ec="*INFO[$(date "+%F %T")] : "

	if [ ! -z "$_AL_PREFIX" ]; then
        	ec+="[$_AL_PREFIX] : "
        fi

	if [ -z "$1" ]; then
        	while read data
		do
			ec+="$data\n"
		done
	else
		ec+=$1
	fi
	aleks_logger "$ec"

}

function error() {                             #Error function 
        local data
        local ec

        ec="!!!ERROR[$(date "+%F %T")] : "
	
	if [ ! -z "$_AL_PREFIX" ]; then
        	ec+="[$_AL_PREFIX] : "
        fi

        if [ -z "$1" ]; then
                while read data
                do
                        ec+="$data\n"
                done
        else
                ec+=$1
        fi
        aleks_logger "$ec" "err"

        if [ ! -z "$2" ]; then  
  		if [ ! -z "$_AL_REPORT_ERROR" ]; then
			if fn_exists "sp_report_phone"; then
				sp_report_phone "$1"
			fi	
		fi

              exit $2
        fi

}

########################## MAITENANCE FUNCTIONS ##########################################

checkpid () {
        debug "Running check_pid"
	
        if [ ! -z "$1" ]
        then
        	debug "PID: $1"
                kill -0 $1 2>&1 # >/dev/null 2>&1
                return $?
        else
                debug "No PID specified"
                return 1
        fi
}

al_check_pidf () {
	local PIDF
	if [ "X$1" == "X" ]; then
		PIDF=$_AL_PID_FILE
	else
		PIDF=$1
	fi

        if [ -f "$PIDF" ]
        then
                kill -0 `cat $PIDF` 2>&1 # >/dev/null 2>&1
                return $?
        else
                return 1
        fi
}

al_create_pid_file () {
	local PIDF
	local PID

	if [ "X$1" == "X" ]; then
                PIDF=$_AL_PID_FILE
        else
                PIDF=$1
        fi
	
	if [ "X$2" == "X" ]; then
                PID=$_AL_PID
        else
                PIDF=$2
        fi

	if ! al_check_pidf $PIDF; then
		if [ ! -e "$PID" ]; then
			debug "Creating PIDF with PID: $PID"
			echo "$PID" > $PIDF
			return 1
		else
			error "No PID specified"
			exit 1
		fi
	else
		error "PID file $PIDF exists! HINT may be process is running?"
		return 0
	fi
}

al_delete_pid_file () {
	local PIDF

        if [ "X$1" == "X" ]; then
                PIDF=$_AL_PID_FILE
        else
                PIDF=$1
        fi

        if al_check_pidf $PIDF; then
        	unlink $PIDF 2>&1
		return 1
	else
                error "NO PID file $PIDF exists!"
                return 0
        fi

}

al_is_locked() {
	local LOCKF

	if [ "X$1" == "X" ]; then
                LOCKF=$_AL_LOCK_FILE
        else
                LOCKF=$1
        fi
	if [ -f $LOCKF ]; then
		return 0
	else
		return 1
	fi
}

al_lock() {
	local LOCKF

        if [ "X$1" == "X" ]; then
                LOCKF=$_AL_LOCK_FILE
        else
                LOCKF=$1
        fi
	
	touch $LOCKF 2>&1

}

al_unlock() {
	local LOCKF

        if [ "X$1" == "X" ]; then
                LOCKF=$_AL_LOCK_FILE
        else
                LOCKF=$1
        fi

	unlink $LOCKF 2>&1
}

function pool_ip() {
        local ret_msg
        local ret_st
        local Q
        local PING
	
	if [ -z "$_AL_CFG_PHP" ]; then
		if [ -z "$1"]; then
			error "No config file specified for pool ip detection"
			exit 1
		else
			_AL_CFG_PHP=$1
		fi
	fi
# Pool address determination 
        if [ -f $_AL_CFG_PHP ]; then
                #Trying to get pool address frm config
                debug "Trying to ger pool address"

                ret_msg=`cat $_AL_CFG_PHP | grep "'db' => array (" -A 5 | grep "'host'" | sed -n "s/'host'.*'\(.*\)'.*/\1/p" | tr -d ' '`

                debug "Pool address: $ret_msg"

                if [ "X$ret_msg" != "X" ]; then
                        # Trying to ping 
                        debug "Trying to ping host: $ret_msg"
                        PING=`ping -q -n -c 2 ${ret_msg} | grep "packet loss" | cut -d " " -f 6 | cut -d "%" -f1`
                        ret_st=$?
                
                        debug "Packet lost: ${PING}"

                        if [ $? -eq 0 ]; then
                                if [ $PING -gt 50 ]; then
                                        error "Can not ping host ${ret_msg}"
                                        exit 1
                                else
                                        debug "Node ${ret_msg} is good, using it"
                                        AL_POOL=$ret_msg
                                fi
                        else
                                error "Failed to ping, returned $ret_st"
                                exit 1
                        fi

                fi
        fi

        if [ -z "$AL_DEFPOOL" ]; then
                AL_DEFPOOL="localhost"
        fi

        if [ "X$AL_POOL" == "X" ]; then
                AL_POOL=$AL_DEFPOOL
        fi

        AL_PSQL="psql -h $AL_POOL"
}

chr() {
  printf \\$(printf '%03o' $1)
}

ord() {
  printf '%d' "'$1"
}

