#!/bin/sh

. /opt/serverscripts/utils/functions.sh

DEBUG=1

if [ -z "$EC2_HOME" ]; then
	error "EC2_HOME is not set"
	exit 1
fi

ec2_attach_volume="$EC2_HOME/bin/ec2-attach-volume"
ec2_delete_volume="$EC2_HOME/bin/ec2-delete-volume"
ec2_create_volume="$EC2_HOME/bin/ec2-create-volume"
ec2_describe_instances="$EC2_HOME/bin/ec2-describe-instances"

shift=4                         #Volume name shift persist in Centos, if you choose /dev/sda in Amazon, device /dev/sde will be attached in Centos
devlet=4                        #Centos device bytes count /dev/xvdN whole device name consists of 4 bytes
diskprefix="sd"                 #Amazon disk prefix /dev/sdN
defaultec2zone="eu-west-1a"     #Default ec2 zone

snapfile=$1
ec2startdev=$2
ec2zone=$3

volumes_bak_path="./volumes_$(date "+%F_%H_%M").lst"
partitions_bak_path="./partitions_$(date "+%F_%H_%M").lst"

MY_INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

function test {

	if [ -z "$MY_INSTANCE_ID" ]; then
        	error "Can not determine amazon instance id"
        	exit 1
	fi

	if [ -z "$snapfile" ]; then
		error "Please specify ec2 snapshot list file"
		exit 1
	fi

	if [ ! -f $snapfile ]; then
		error "EC2 snapshot list file $snapfile not found"
		exit 1
	fi
	
	if [ -z "$ec2startdev" ]; then
		error "Please specify amazon device start letter. HINT! /dev/sdN, N is start letter"
		exit 1
	fi

	if [[ ! $ec2startdev =~ ^[a-z]$ ]]; then
		error "Device start letter must be 1 byte between [a-z]"
		exit 1
	fi

	if [ -z $ec2zone ]; then
		error "Ec2 zone not specified, Using default $defaultec2zone"
		ec2zone=$defaultec2zone
	fi

}

function create_volumes {
	local ret_msg
        local ret_st

	test 

	e "Creating volumes in $ec2zone zone"

	volumes=""

	for snap in $(cat $snapfile); do
		if [ ! -z "$snap" ]; then
			e "Creating volume from snapshot $snap"
			debug "$ec2_create_volume --snapshot $snap -z $ec2zone"
			ret_msg=`$ec2_create_volume --snapshot $snap -z $ec2zone`
			ret_st=$?

			if [ $ret_st -ne 0 ]; then
				error "Error during volume creation($ret_st): $ret_msg"
				exit 1
			fi

			ret_msg=`echo $ret_msg | awk '{print $2}'`

			e "Created volume $ret_msg"
			volumes="$volumes $ret_msg"
		fi
	done

	echo $volumes > $volumes_bak_path

	e "Volume creation complete"
}
function attach_volumes {
	local ret_msg
	local ret_st
	local disk="${diskprefix}${ec2startdev}"
	local lvolumes=$1
	local wcount
	local tmp
	local tmp2

	test

	if [ -z "$lvolumes" ]; then
		error "Created volume list is empty"
		exit 1
	fi
	e "Starting attach proccess"

	debug "$ec2_describe_instances $MY_INSTANCE_ID | grep $disk"

	ret_msg=`$ec2_describe_instances $MY_INSTANCE_ID | grep $disk`
	
	if [ ! -z "$ret_msg" ]; then
		error "Disk $disk is attached to current instance. Please specify another EC2 device start letter"
		return 1
	fi

	
	wcount=`echo $lvolumes | wc -w`	

	tmp=`ord $ec2startdev`
	
	let tmp=$tmp+$shift

	let tmp2=$tmp+$wcount
	
	
	if [ $tmp2 -gt 122 ]; then
		error "Voulmes ($lvolumes) could not be attached, because last attached device could exceed allowed device names"
		error "Starting device: /dev/xvd$(chr $tmp), Last device: /dev/xvd$(chr $tmp2)"
		return 1 
	fi

	
		
}

function delete_volumes {

	local lvolumes=$1
	
	test 

	e "Starting deletion of volumes"

	if [ -z "$lvolumes" ]; then
		error "Created volume list is empty"
                exit 1
	fi

	for volume in $(echo $lvolumes); do
		if [ ! -z "$volume" ];then
			e "Delete volume $volume"
			$ec2_delete_volume $volume		
		fi
	done

}

e "Starting procedure for instance: $MY_INSTANCE_ID"

create_volumes

e "Volumes created: $volumes"

if attach_volumes "$volumes"; then
	e "Volumes attached"
else
	delete_volumes "$volumes"
fi
