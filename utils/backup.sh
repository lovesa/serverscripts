#!/bin/sh

. /opt/serverscripts/utils/functions.sh

function backup {
        local dt=$(date "+%F-%H")
	local hn=$(hostname)

        if [ -z "$_LOCAL_BACKUP_DIR" ]; then
                error "\$_LOCAL_BACKUP_DIR variable not set"
                return 1
        fi
        if [ ! -d $_LOCAL_BACKUP_DIR ]; then
                error "Backup directory $_LOCAL_BACKUP_DIR not found"
                return 1
        fi
        if [ -z "$1" ]; then
                error "Nothing to backup"
                return 1
        fi

        if [ ! -f $1 ] && [ ! -d $1 ]; then
                error "File/Directory $1 not found"
                return 1
        fi

        if [ -d $1 ]; then
                LARGS="-r"
        fi

        mkdir -p $_LOCAL_BACKUP_DIR/$dt-$hn

        cp -p $LARGS $1 $_LOCAL_BACKUP_DIR/$dt-$hn/
                
}

backup $1
