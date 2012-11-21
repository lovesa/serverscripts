#!/bin/sh

. /opt/serverscripts/utils/functions.sh

DEBUG=1

if [ -z "$EC2_HOME" ]; then
	error "EC2_HOME is not set"
	exit 1
fi

device=$1

create_snapshot="$EC2_HOME/bin/ec2-create-snapshot"
ec2_describe_instances="$EC2_HOME/bin/ec2-describe-instances"

shift=4                         #Volume name shift persist in Centos, if you choose /dev/sda in Amazon, device /dev/sde will be attached in Centos
devlet=4                        #Centos device bytes count /dev/xvdN whole device name consists of 4 bytes
diskprefix="sd"                 #Amazon disk prefix /dev/sdN

MY_INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

snaps_path="./backup_$(date "+%F_%H_%M").lst"

snaps=""

if [ -z "$MY_INSTANCE_ID" ]; then
        error "Can not determine amazon instance id"
        exit 1
fi

if [ -z "$device" ]; then
        error "Please enter device name from amazon"
        exit 1
fi

if [ ! -b /dev/$device ]; then
        error "Device $device is not a block device"
        exit 1
fi

ret_msg=`cat /proc/mdstat | grep $device | sed -e '/^md[0-9]*.*raid[0-9]* / s///g'`

if [ -z "$ret_msg" ]; then
        error "Device $device is not a software raid device"
        exit 1
fi

e "Device founded"

e "$ret_msg"

e "Searching for volumes ids"

node_description=`$ec2_describe_instances $MY_INSTANCE_ID`

volumes=""

if ! fn_exists "ord" || ! fn_exists "chr"; then
	error "ord or chr functions not found"
	exit 1
fi

for dev in $(echo $ret_msg); do
        dev=`echo $dev | cut -b -$devlet`
        dev=`echo $dev | cut -b ${devlet}-`
        dev=`ord $dev`
        let dev=$dev-$shift
        dev="${diskprefix}$(chr $dev)"
        found=`echo -e "$node_description" | grep $dev | awk '{print $3}'`
        if [ -z "$found" ]; then
                error "Error during amazon volume id search. Stopping"
                exit 1
        fi
        debug "Found: $found"
        volumes="$volumes $found"
done

mountpoint=`cat /proc/mounts | grep $device | awk '{print $2}'`

if [ -z "$mountpoint" ]; then
	error "Mount point for device $device not found, or device is not mounted"
	exit 1
fi

e "Starting backup for raid volume ($device on $mountpoint): $volumes"

debug "Freezing volume $mountpoint"

ret_msg=`fsfreeze -f $mountpoint`
ret_st=$?

if [ $ret_st -ne 0 ]; then
	error "Fs freeze failed($ret_st): $ret_msg"
	exit 1
fi

for id in $volumes; do
	if [ ! -z "$id" ]; then
		e "Backing up volume: $id"
		ret_msg=`${create_snapshot} $id --hide-tags -d "Snapshot for $(hostname)($MY_INSTANCE_ID), mountpoint: $mountpoint"`
		ret_st=$?

		if [ $ret_st -eq 0 ]; then
			snap_id=`echo $ret_msg | awk '{print $2}'`
			snaps="$snaps $snap_id"
		else
			error "Error during snapshot creation($ret_st): $ret_msg"
		fi
	fi
done

debug "Unfreezing volume"

ret_msg=`fsfreeze -u $mountpoint`
ret_st=$?

if [ $ret_st -ne 0 ]; then
        error "Fs unfreeze failed($ret_st): $ret_msg"
        exit 1
fi

echo $snaps > $snaps_path

