#!/bin/sh
# chkconfig: 2345 89 11

APP_NAME="nfsdirectorysharing"

APP_LONG_NAME="NFS directory sharing"
SRC=/opt/nfsshare/ruptela
DST=/opt/nfsshare


DEBUG=1
. /opt/serverscripts/utils/functions.sh

SERVER_ADDRES="loadbalancer"

function is_mounted {
        local ret_msg
        local ret_st
        local dv="ruptela/cfg"


        if [ ! -z "$1" ]; then
                dv=$1
        fi
        debug "Checkind device $dv for mounted state"

        ret_msg=`cat /proc/mounts | grep $dv`

        ret_st=$?

        debug "Command returned($ret_st): $ret_msg"

        return $ret_st
}

function mount_nfs_folder {
	local mount_f
	local mount_t
	local ret_st
	local result
	local ex_code
        if [ ! -z "$1" ]; then
                mount_f=$1
        fi
        if [ ! -z "$2" ]; then
                mount_t=$2
        fi

	if is_mounted $mount_t; then
	        e "Device ($mount_t) is already mounted"
	else
        	debug "Device ($mount_t) is unmounted"
		result=`nc -zv -w5 $SERVER_ADDRES 2049 2>/dev/null`
		ret_st=$?
		if [[ $ret_st == "0" ]];
		then
		       debug "Service up!"
	               debug "Trying to mount device ($mount_t)"
        	       mount $SERVER_ADDRES:$mount_f $mount_t -o soft,timeo=900,retrans=3,vers=3,proto=tcp 
	               ret_st=$?
                       debug "Mount state: $ret_st"
        	       if [ $ret_st != "0" ]; then
	                       debug "Device ($mount_t) mount failed. Check configuration."
	               else
        	               debug "Device ($mount_t) successfully mounted"
	               fi
		else
		  debug "Service down"
		fi
	fi

    return $ret_st
}

start() {
    mount_nfs_folder $SRC $DST
    ret_st=$?

    return $ret_st

#    mount_nfs_folder "/opt/nfsshare/ruptela" "/opt/nfsshare"
}

stopit() {
    local ex_code
    umount $DST 2>/dev/null
    ret_st=$?
    if [ $ret_st == "0" ]; then
	e "Device ($DST) succesfully unmounted"
    else
        e "Device ($DST) unmount fail, maybe not mounted ?"
    fi
    return $ret_st
    #umount /opt/services/ruptela/fw 2>/dev/null
    #ex_code=$?
    #if [ $ex_code == "0" ]; then
    #    e "Device (/opt/services/ruptela/fw) succesfully unmounted"
    #else
    #    e "Device (/opt/services/ruptela/fw) unmount fail, maybe not mounted ?"
    #fi
}


status() {
        if is_mounted $DST; then
                e "Device ($DST) is mounted"
                return 0
        else
		    e "Device ($DST) is unmounted"
            return 1
	fi

        #if is_mounted "/opt/services/ruptela/fw"; then
        #        e "Device (/opt/services/ruptela/fw) is mounted"
        #else
        #        e "Device (/opt/services/ruptela/fw) is unmounted"
        #fi

}
case "$1" in

    'start')
        start
        exit $?
        ;;

    'stop')
        stopit "0"
        exit $?
        ;;

    'restart')
        stopit "0"
        sleep 1
        start
        exit $?
        ;;

    'status')
        status
        exit $?
        ;;

    *)
        echo "Usage: $0 { start | stop | restart | status }"
        exit 1
        ;;
esac

exit 0
