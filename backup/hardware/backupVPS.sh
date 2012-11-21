#!/bin/bash
 
VEIDS="103"

VZ_CONF="/etc/vz/conf/"             # the path to your openvz $VEID.conf files
VZ_PRIVATE="/vz/root/"           # the path to the running VE's
LOCAL_DIR="/vz/pgsql/cluster/archive/dump/"           # the local rsync cache / destination directory
DB_DIR="/vz/pgsql2/"
# The remote host and path that this script will rsync the VE's to.
REMOTE_HOST=""
REMOTE_DIR="/vz/vzfs/backup/"

# Default rsync flags (please note the potentially unsafe delete flags).
# You can also remove the v flag to get less verbose logging.
RSYNC_DEFAULT="rsync -raHi --delete-after --delete-excluded"

# Exclude these directories from backup (space delimited).
# I left /var/log in the backup because when doing a full restore
# it's necessary that this directory structure is present.
#RSYNC_EXCLUDE="/var/lib/pgsql/data/pg_xlog"

# Path to vzctl executable
VZCTL="vzctl"

# Nice debugging messages...
function e {
  echo -e $(date "+%F %T"):  $1
}
function die {
  e "Error: $1" >&2
  exit 1;
}

# Make sure all is sane
[ ! -d "${VZ_CONF}" ]    && die "\$VZ_CONF directory doesn't exist. ($VZ_CONF)"
[ ! -d "${VZ_PRIVATE}" ] && die "\$VZ_PRIVATE directory doesn't exist. ($VZ_PRIVATE)"
[ ! -d "${LOCAL_DIR}" ]  && die "\$LOCAL_DIR directory doesn't exist. ($LOCAL_DIR)"

e "`hostname` - VZ backup for containers $VEIDS started." > /tmp/vzbackuptimes
# Loop through each VEID
for VEID in $VEIDS; do

  VEHOSTNAME=`vzlist -o hostname $VEID -H`
  echo ""
  e "Beginning backup of VEID: $VEID";

  # Build up the --exclude string for the rsync command
  RSYNC="${RSYNC_DEFAULT}"
  
  if [ ! -z "$RSYNC_EXCLUDE" ]; then
  	for path in $RSYNC_EXCLUDE; do
    		RSYNC+=" --exclude=${VEID}${path}"
  	done;
  fi

  e "Commencing initial ${RSYNC} ${VZ_PRIVATE}${VEID} ${LOCAL_DIR}"
  [ ! -d "${VZ_PRIVATE}${VEID}" ] && die "\$VZ_PRIVATE\$VEID directory doesn't exist. (${VZ_PRIVATE}${VEID})"
  e "Rsync commented.."
  #${RSYNC} ${VZ_PRIVATE}${VEID} ${LOCAL_DIR}
  e "Starting database backup"
  e "Starting ${RSYNC} ${VZ_PRIVATE}${VEID}/var/lib/pgsql/ ${LOCAL_DIR}pgsql/${VEID}/pgsql/"

  ${RSYNC} ${VZ_PRIVATE}${VEID}/var/lib/pgsql/ ${LOCAL_DIR}pgsql/${VEID}/pgsql/
 
  # If the VE is running, suspend, re-rsync and then resume it ...
  if [ -n "$(${VZCTL} status ${VEID} | grep running)" ]; then

    e "Stoping DB on VEID: $VEID"
    before="$(date +%s)"
    #${VZCTL} chkpnt $VEID --suspend
    e "Running ${VZCTL} exec ${VEID} service postgresql stop"
    
    ${VZCTL} exec ${VEID} service postgresql stop	
 
    e "Commencing second pass rsync ..."
    e "Rsync commented"
    #${RSYNC} ${VZ_PRIVATE}${VEID} ${LOCAL_DIR}
	
    e "Running second pass DB rsync"
    ${RSYNC} ${VZ_PRIVATE}${VEID}/var/lib/pgsql/ ${LOCAL_DIR}/pgsql/${VEID}/pgsql/

    e "Resuming DB on VEID: $VEID"
    #${VZCTL} chkpnt $VEID --resume
    e "Running ${VZCTL} exec ${VEID} service postgresql start"
    
    ${VZCTL} exec ${VEID} service postgresql start 

    after="$(date +%s)"
    elapsed_seconds="$(expr $after - $before)"

    e "Done."
    e "Container ${VEID} ($VEHOSTNAME) was down $elapsed_seconds seconds during backup process." >> ${LOCAL_DIR}/vzbackuptimes

  else
    e "# # # Skipping suspend/re-rsync/resume, as the VEID: ${VEID} is not curently running."
  fi

  # Copy VE config files over into the VE storage/cache area
  if [ ! -d "${LOCAL_DIR}${VEID}/etc/vzdump" ]; then
    e "Creating directory for openvz config files: mkdir ${LOCAL_DIR}${VEID}/etc/vzdump"
    mkdir ${LOCAL_DIR}${VEID}/etc/vzdump
  fi

  e "Copying main config file: cp ${VZ_CONF}${VEID}.conf ${LOCAL_DIR}${VEID}/etc/vzdump/vps.conf"
  [ ! -f "${VZ_CONF}${VEID}.conf" ] && die "Unable to find ${VZ_CONF}${VEID}.conf"
  cp ${VZ_CONF}${VEID}.conf ${LOCAL_DIR}${VEID}/etc/vzdump/vps.conf

  for ext in start stop mount umount; do
    if [ -f "${VZ_CONF}${VEID}.${ext}" ]; then
      e "Copying other config file: cp ${VZ_CONF}${VEID}.${ext} ${LOCAL_DIR}${VEID}/etc/vzdump/vps.${ext}"
      cp ${VZ_CONF}${VEID}.${ext} ${LOCAL_DIR}${VEID}/etc/vzdump/vps.${ext}
    fi
  done;

  # Run the remote rsync
  if [ -n "${REMOTE_HOST}" ] && [ -n "${REMOTE_DIR}" ]; then
	
	NOW=`date '+%Y-%m'-%d_%H:%M`
    	NOW=${REMOTE_DIR}increment/${NOW}
    
    e "Commencing remote ${RSYNC} --backup --backup-dir=${NOW} ${LOCAL_DIR} ${REMOTE_HOST}:${REMOTE_DIR}current/"

   
    ssh ${REMOTE_HOST} mkdir $NOW
 
    ${RSYNC} --backup --backup-dir=${NOW} ${LOCAL_DIR} ${REMOTE_HOST}:${REMOTE_DIR}current/
    

    e "Done"

    #e "Making incremental backup"
    
 
    #e "Making directory: ssh ${REMOTE_HOST} mkdir $NOW"
    
    #ssh ${REMOTE_HOST} mkdir $NOW
    
    #e "Trying to ssh ${REMOTE_HOST} cp -al ${REMOTE_DIR}current/* $NOW"

    #ssh ${REMOTE_HOST} cp -al ${REMOTE_DIR}current/* $NOW

  fi

  e "Done."
done;
e "`hostname` - VZ backup for containers $VEIDS complete!" >> ${LOCAL_DIR}/vzbackuptimes
# Email a log of the backup process to some email address. Can be modified slightly to use native "mail" command
# if sendmail is installed and configured locally.
#cat /tmp/vzbackuptimes | sendEmail -f root@`hostname` -t someuser@example.com -u "`hostname` VZ backup statistics." -s mail.example.com #(put your open relay here)
#echo
#cat /tmp/vzbackuptimes
#rm /tmp/vzbackuptimes
