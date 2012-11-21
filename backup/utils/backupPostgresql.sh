#!/bin/sh

# Script performs database rsync into temp directory with low database stop time

# USER VARIABLES
TEMPDIR=/var/lib/pgsql/archive/archive/temp				# Temp directory
LOCALDIR=/var/lib/pgsql/9.1/data					# Folder to be backed up
POSTGRESQL="postgresql-9.1"						# Postgresql service name
DEMO="on"								# DEMO mode

# PATH VARIABLES
SH=/bin/sh                                                              # Location of the bash bin in the production server!!!!
CP=/bin/cp;                                                             # Location of the cp bin
FIND=/usr/bin/find;                                                     # Location of the find bin
ECHO=/bin/echo;                                                         # Location of the echo bin
MK=/bin/mkdir;                                                          # Location of the mk bin
SSH=/usr/bin/ssh;                                                       # Location of the ssh bin
DATE=/bin/date;                                                         # Location of the date bin
RM=/bin/rm;                                                             # Location of the rm bin
GREP=/bin/grep;                                                         # Location of the grep bin
RSYNC=/usr/bin/rsync;                                		        # Location of the rsync bin
TOUCH=/bin/touch;  

function e {
  echo "============================================="
  echo $(/bin/date "+%F %T"):  $1
  echo "============================================="
}

function die {
  e "Error: $1" >&2
  e "Exiting.."
  exit 1;
}


RSYNC+=" -ahiv --progress --delete-after --inplace"

if [ ! -z "$DEMO" ]; then
	if [ "$DEMO" == "on" ]; then
		e "Running in DEMO mode, rsync started with -n key(DRY RUN)"
		RSYNC+=" -n"
	fi
fi			
RSYNC+=" --exclude=postmaster.pid"

# CREATING NECESSARY FOLDERS
if [ ! -d $TEMPDIR ];
then
        e "Creating temp dir: $TEMPDIR"
        $MK -p $TEMPDIR
fi


function stop_db {
	e "Stoping database"

	e "service ${POSTGRESQL} stop"
	
	if [ -z "$DEMO" ] || [ "$DEMO" != "on" ]; then 
		e "Running..."
		service ${POSTGRESQL} stop	
	else
		e "Running in DEMO mode, nothing stoped.. =)"
	fi
}

function start_db {
        e "Starting database"
	
	e "service ${POSTGRESQL} start"
	
	if [ -z "$DEMO" ] || [ "$DEMO" != "on" ]; then
                e "Running..."
		service ${POSTGRESQL} start     
        else
                e "Running in DEMO mode, nothing started.. =)"
        fi 
}

function first_stage {
	before="$($DATE +%s)"
	e "Starting first stage of sync"
	# =================================
	e "Running command: $RSYNC $LOCALDIR $TEMPDIR"
	
	$RSYNC $LOCALDIR $TEMPDIR	

	# =================================
	after="$($DATE +%s)"
	elapsed_seconds="$(/usr/bin/expr $after - $before)"
	e "Done first stage, elapsed time: $elapsed_seconds s."
}

function second_stage {
        before="$($DATE +%s)"
        e "Starting second stage of sync"
        # =================================
	stop_db

        e "Running command: $RSYNC $LOCALDIR $TEMPDIR" 

        $RSYNC $LOCALDIR $TEMPDIR

	start_db
        # =================================
        after="$($DATE +%s)"
        elapsed_seconds="$(/usr/bin/expr $after - $before)"
        e "Done second stage, elapsed time: $elapsed_seconds s."
}

e "Starting Database backup"

first_stage 
second_stage 

