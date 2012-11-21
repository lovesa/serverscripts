#!/bin/sh
# chkconfig: 2345 89 10

function start {
	
	USER_DATA=`/usr/bin/curl -s http://169.254.169.254/latest/user-data | grep '@HOSTNAME@'`
	if [ ! -z "$USER_DATA" ]; then
		host=`echo $USER_DATA | awk '{print $2}'`
	fi
	IPV4=`/usr/bin/curl -s http://169.254.169.254/latest/meta-data/public-ipv4`
	hn=`hostname`

	if [ ! -z "$host" ]; then
		# Set the host name
		export OLD_HOSTNAME=$hn

		hostname $host
		echo $host > /etc/hostname
		echo $host
	fi
}

function stopit {
	if [ ! -z "$OLD_HOSTNAME" ]; then
		hostname $OLD_HOSTNAME
		echo $OLD_HOSTNAME > /etc/hostname
                echo $OLD_HOSTNAME
	fi
}

case "$1" in

    'start')
        start
        ;;

    'stop')
        stopit
        ;;

    'status')
        hostname
        ;;

    *)
        echo "Usage: $0 { start | stop | status }"
        exit 1
        ;;
esac

exit 0

