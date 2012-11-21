#!/bin/sh

. /opt/serverscripts/utils/functions.sh

DYNAMICLIST=/etc/nginx/dynamic_list.conf
STATICLIST=/etc/nginx/static_list.conf
BACKUPDIR=/etc/nginx/backup

#DEBUG=1

function test {
	if [ ! -f $DYNAMICLIST ]; then
		error "Dynamic list $DYNAMICLIST not found"
		exit 1
	fi
	
	if [ ! -f $STATICLIST ]; then
		error "Static list $STATICLIST not found"
		exit 1
	fi

	if [ ! -d $BACKUPDIR ]; then
		error "Backup directory $BACKUPDIR not found"
		exit 1
	fi
}

function backup {
	local date=$(date "+%F_%H-%M")
	
	test

	debug "Backuping old configs"
	
	debug "cp $DYNAMICLIST $BACKUPDIR/dynamic_list.$date.conf"
	cp $DYNAMICLIST $BACKUPDIR/dynamic_list.$date.conf
	
	debug "cp $DYNAMICLIST $BACKUPDIR/dynamic_list.$date.conf"
	cp $DYNAMICLIST $BACKUPDIR/static_list.$date.conf
	
	return $?	
}

function add {
	local ret_st
	local ret_msg
	local pattern_d
	local pattern_s
	
	if [ -z $1 ]; then
		error "Please specify new server ip"
		return 1
	fi
	
	ret_msg=`cat $DYNAMICLIST | grep '\#@NEWLINE@'`
	ret_st=$?
	ret_msg=`cat $STATICLIST | grep '\#@NEWLINE@'`
	let ret_st=$ret_st + $?
	
	if [ $ret_st -ne 0 ]; then
		error "New line delimiter was not found in list files"
		return 1
	fi	
	
	test	
	
	pattern_d="\tserver $1:9000 max_fails=3 fail_timeout=720s;\n"
	pattern_s="\tserver $1:80 max_fails=3 fail_timeout=30s;\n"	

	e "You are attempting to add dynamic server:"
	e "$pattern_d"
	e "You are attempting to add static server:"
	e "$pattern_s"
		
	if read -p "Are you sure? " in &&
		[ ".$in" == ".yes" ]; then
			if backup; then
				sed -i "/\#@NEWLINE@/ s/\$/ \n${pattern_d}/g" $DYNAMICLIST
				sed -i "/\#@NEWLINE@/ s/\$/ \n${pattern_s}/g" $STATICLIST
				
				service nginx reload
				ret_st=$?
				if [ $ret_st -ne 0 ]; then
					error "Nginx reload failed($ret_st)"
					return 1
				fi
				
				return 0
			else
				error "Backup failed!"
				return 1
			fi
	else
		error "NO! Exiting"
		return 0
	fi
#	sed -i '/\#@NEWLINE@/ s/$/ \nsome sort of text here\n/g'

}

function status {
	test

	e "Enabled dynamic nodes list:"
	cat $DYNAMICLIST | grep 'server'
	e "Enabled static nodes list:"
	cat $STATICLIST | grep "server"
	
	return 0
}

function delete {
	local ret_msg
	local ret_st
	
	
	if [ -z $1 ]; then
                error "Please specify new server ip"
                return 1
        fi
	
	test
	
	e "Deleteting $1 server from pool"
	
	ret_msg=`cat $DYNAMICLIST | grep "$1"`
	ret_st=$?
	if [ $ret_st -ne 0 ]; then
		e "Node $1 not found in nodes lists"
		return 1
	fi

	e "You are attempintg to delete this lines from configs:"

	cat $DYNAMICLIST | grep "$1"
        cat $STATICLIST | grep "$1"
	
	if read -p "Are you sure?" in &&
                [ ".$in" == ".yes" ]; then
                        if backup; then
				sed -i "s/.*server $1.*//g" $DYNAMICLIST
				sed -i "s/.*server $1.*//g" $STATICLIST
				
				service nginx reload
                                ret_st=$?
                                if [ $ret_st -ne 0 ]; then
                                        error "Nginx reload failed($ret_st)"
                                        return 1
                                fi

				return 0
			else
				error "Backup failed, sorry"
				return 1
			fi
        else
		error "NO! Exiting!"
		return 0
	fi

	

}

# See how we were called.
case "$1" in
    status)
	status
    	RETVAL=$?
    ;;
    add)
	add $2 $3
	RETVAL=$?
    ;;
    delete)
	delete $2
	RETVAL=$?
    ;;
    *)
        echo $"Usage: $prog {status | add | delete}"
        RETVAL=2
esac

exit $RETVAL
#read -p "Slave node count is $pr_inc, do you really want to execute sql? " in
