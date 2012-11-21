#!/bin/sh

. /opt/serverscripts/utils/functions.sh

CMD="ssh"
SERVERS=~/.servers
max=0

        usage()
        {
cat << EOF
usage: $0 [-h][-f filename] command

This is multiple ssh script

OPTIONS:
    -h      Show this message
    -f      Servers file
    -i      Key file
EOF
        }

while getopts “hf:i:” OPTION
do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
         f)
             SERVERS=$OPTARG
             ;;
	 i)
	     KEYFILE=$OPTARG
	     ;;
         ?)
             usage
             exit
             ;;
     esac
     if [ $OPTIND -gt $max ]

        then
                let "max=$OPTIND-1"

        fi
done

shift $max

if [[ -z "$@" ]]; then
        usage
        exit
fi

if [ ! -f $SERVERS ]
        then
            error "File $SERVERS does not exist"
            exit
fi

	if [ -f $KEYFILE ]; then
		CARGS="-i $KEYFILE"
	else
		error "Key file: $KEYFILE not found"
		exit 1
	fi


        for i in $(sed '/^ *#/d;s/#.*//' $SERVERS) ; do
                C="$CMD $CARGS"
                if [[ "$i" =~ ':' ]]; then
                        C+=" -p $(echo $i | cut -d':' -f2)"
                        i=$(echo $i | cut -d':' -f1)
                fi
                C+=" root@$i"

                
                e "Running: $C $@"
		$C "$@"
        done
