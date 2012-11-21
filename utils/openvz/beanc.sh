#!/bin/bash
#####################################################################################################################
#
# This script is intended to check the failcounts in user_beancounters on a OpenVZ machine.
# Since there is no solid way to reset the failcounts, this script maintains a copy of the file and shows delta's
#
#
# Filename: beanc
# Version : 0.1
#
#
# License:
# -------
#
# By using this script you agree there are absolutely no limitations on using it. Ofcourse there are also
# absolutely no guarantees. Please review the code to make sure it will work for you as expected.
#
# Feel free to distribute and/or modify the script.
#
# Only thing I will not appreciate is that you change my name into yours, and act like you wrote this script
# But hey, why would you do that ?  And how will I ever know ?
#
# If you make changes, decide to distribute the script or feel the urge to give me feedback, please let me know.
#
#
# Author(s):
# ---------
#
# Written by Steven Broos, 7/7/2011 in a boring RHEL course
#          Steven@Bit-IT.be
#
#
# Usage:
# -----
#
# 1. Copy the file to a location in your path, for example '/sbin/'
# 2. Make sure the file can be executed ('chmod 500 /sbin/beanc')
# 3. Use the script ;-)  At first execution the reference file will be created in '/var/lib/beanc/'
#     Note that the script is written for intended use by root, and on the OpenVZ host system
#     Possibly this script wont work in a cron-job or inside a container. This has not been tested
#
#
# Options:
# -------
#
# 1. Show the beancounters
#
#          beanc show
#
#     this compares the contents of /proc/user_beancounters and the reference file, and shows you the delta value
#     if no reference file exists, a copy of the user_beancounters file is used.
#     to only show you the failcounts for 1 container, just add the ctid or container name to the command
#
#          beanc show mailserver
#          beanc show 102
#
# 2. To reset the failcounters for a container (or all containers):
#
#          beanc reset mailserver
#          beanc reset 102
#          beanc reset                   --> will reset failcounters for all containers
#
#     Confirmation will be asked.
#
# 3. It is also possible to only show the failcounters > 0
#
#          beanc brief
#
# 4. If for some reason you want to manually initialize the reference file, you can execute
#
#          beanc init
#
#     This will check if the app-directory exists (/var/lib/beanc) and create it if necessary
#     It also creates a reference file (/var/lib/beanc/user_beancounters)
#     BEWARE, this command will overwrite any existing reference file !
#
 
 
#####################################################################################################################
####                                                                                                             ####
####  Declaration of some variables. Feel free to adjust                                                         ####
####                                                                                                             ####
#####################################################################################################################
 
 
rspath='/var/lib/beanc'
rsfile="$rspath/user_beancounters"
lines=24
 
 
#####################################################################################################################
####                                                                                                             ####
####  Function declarations. See at the bottom of the script for execution                                       ####
####                                                                                                             ####
#####################################################################################################################
 
 
# show brief help message
 
function help ()
{
        echo "$0 { reset | show | brief | init } [ <vzid> | <vzname> ]"
        exit 0
}
 
# check existence of path and reference file, and create if necessary
# This function is executed by every start of the script
 
function init ()
{
        if [ ! -d "$rspath" ] || [ "$1" != "" ]
        then
                mkdir -p "$rspath"
        fi
        if [ ! -f "$rsfile" ] || [ "$1" != "" ]
        then
                cat /proc/user_beancounters > "$rsfile"
        fi
}
 
# Reset the failcounters by putting the current values from /proc/user_beancounters into the reference file
# either for all containers (cat > ref), or for one container (block per block)
 
function reset ()
{
        if [ "$1" == "" ]
        then
                echo -n "Reset failcounts for all containers ? [y/N] "
                read -n 1 yn
                echo
                if [ "$yn" == "y" ]
                then
                        cat /proc/user_beancounters > "$rsfile"
                fi
        else
                echo -n "Reset failcounts for container '`vzname $1`' ($1) ? [y/N] "
                read -n 1 yn
                echo
                if [ "$yn" == "y" ]
                then
                        mv "$rsfile" "${rsfile}_"
                        for ctid in `vzlist -Ho ctid`
                        do
                                if [ $ctid -eq $1 ]
                                then
                                        echo "Resetting '`vzname $ctid`' ($ctid)"
                                        cat /proc/user_beancounters | getblock $ctid >> "$rsfile"
                                else
                                        echo "Keeping '`vzname $ctid`' ($ctid)"
                                        cat "${rsfile}_" | getblock $ctid >> "$rsfile"
                                fi
                        done
                        rm -f "${rsfile}_"
                fi
        fi
}
 
# Get one or more lines from the middle of the given text : returns the 'head' of a 'tail"
# $1 : start at line
# $2 : give this much lines (optional, default 1)
# example : cat /path/file | getline 10 5
 
function getline ()
{
        start=$1
        length=$2
 
        if [ "$length" == "" ]
        then
                length=1
        fi
 
        cat - | head -n $(($start+$length-1)) | tail -n $length
}
 
# Get all beancounter values for a container
# $1 : ctid
# example : cat /proc/user_beancounters | getblock 102
 
function getblock ()
{
        cat - > "$rspath/tmp"
        start=`cat -n "$rspath/tmp" | grep " $1:" | awk '{ print $1 }'`
        echo start $start
        cat "$rspath/tmp" | getline $start $lines
        rm -f "$rspath/tmp"
}
 
# Show the contents from /proc/user_beancounters, and substitute the failcounts by a delta with the failcounts in
# the reference file
# $1 : ctid (optional, if none given all running containers are processed)
# example : show 102
 
function show ()
{
        if [ "$1" == "" ]
        then
                for ctid in `vzlist -Ho ctid`
                do
                        show $ctid
                done
        else
                cstart=`cat /proc/user_beancounters -n | grep " $1:" | awk '{ print $1 }'`
                hstart=`cat "$rsfile" -n | grep " $1:" | awk '{ print $1 }'`
 
                for ln in `seq 0 $(($lines-1))`
                do
                        current=`cat /proc/user_beancounters | getline $(($cstart+$ln))`
                        if [ "$hstart" == "" ]
                        then
                                history=''
                        else
                                history=`cat "$rsfile" | getline $(($hstart+$ln))`
                        fi
 
                        if [ $ln -eq 0 ]
                        then
                                resource=`echo "$current" | awk '{ print $2 }'`
                                held=`echo "$current" | awk '{ print $3 }'`
                                maxheld=`echo "$current" | awk '{ print $4 }'`
                                barrier=`echo "$current" | awk '{ print $5 }'`
                                limit=`echo "$current" | awk '{ print $6 }'`
				currfcnt=`echo "$current" | awk '{ print $7 }'`
                                histfcnt=`echo "$history" | awk '{ print $7 }'`
 
                                fgcolor white
                                echo ' ----------------------------------------------------------------------------------------------------------------------
--'
                                printf "|%14s : %-12s %89s |\n" $1 `vzname $1` "`vzfqdn $1` (`vzip $1`)"
                                printf "|%14s%21s%21s%21s%21s%21s |\n" resource held maxheld barrier limit failcnt
                                echo ' ----------------------------------------------------------------------------------------------------------------------
--'
                                fgcolor reset
                        else
                                resource=`echo "$current" | awk '{ print $1 }'`
                                held=`echo "$current" | awk '{ print $2 }'`
                                maxheld=`echo "$current" | awk '{ print $3 }'`
                                barrier=`echo "$current" | awk '{ print $4 }'`
                                limit=`echo "$current" | awk '{ print $5 }'`
                                currfcnt=`echo "$current" | awk '{ print $6 }'`
				histfcnt=`echo "$history" | awk '{ print $6 }'`
                        fi
                        if [ "$histfcnt" == "" ]
                        then
                                failcnt=$currfcnt
                        else
                                failcnt=$(($currfcnt-$histfcnt))
                        fi
                        printf ' '
                        if [ $failcnt -gt 0 ]
                        then
                                bgcolor red
                                fgcolor white
                                echo -en '*'
                        else
                                fgcolor green
                                echo -en ' '
                        fi
                        printf "%13s%21s%21s%21s%21s%21s %.s" $resource $held $maxheld $barrier $limit $failcnt "($histfcnt-$currfcnt)"
                        fgcolor reset
                        bgcolor reset
                        echo
                done
        fi
}
 
# Shows only counters > 0, by grepping on '|' and '-' (for the header), and '*' (for the matching failcounter)
# If no '*' has been found, nothing for that container will be shown
 
function showbrief ()
{
        echo 'Calculating ...'
        for ctid in `vzlist -Ho ctid`
        do
                result=`show $ctid`
                matches=`echo -en "$result" | grep '*' | wc -l`
                if [ $matches -gt 0 ]
                then
                        echo -en "$result" | grep -e '|' -e '*' -e '-'
                fi
        done
        echo 'Done!'
}
 
# This function returns the ctid for a container.
# $1 : container-name or even the ctid itself, since you cannot know what value the user has given
 
function vzid ()
{
        vzlist -o name,ctid | grep -e "^$1 " -e " $1$" | awk '{ print $2 }'
}
 
# Returns the IP for the given ctid
# $1 : ctid
 
function vzip ()
{
        vzlist -o ctid,ip | grep " $1 " | awk '{ print $2 }'
}
 
# Returns the fully qualified domain name for the given ctid
# $1 : ctid
 
function vzfqdn ()
{
        vzlist -o ctid,hostname | grep " $1 " | awk '{ print $2 }'
}
 
# Returns the short name for the given ctid
# $1 : ctid
 
function vzname ()
{
        vzlist -o ctid,name | grep " $1 " | awk '{ print $2 }'
}
 
# This function outputs the escape code for the specified textcolor
# $1 : Color by name (black, blue, ...)
#      Or reset to revert to the terminal's default colors
# example : fgcolor red; echo 'red text'; fgcolor reset
 
function fgcolor ()
{
        case $1 in
                'black') echo -en "\033[1;30m" ;;
                'green') echo -en "\033[1;32m" ;;
                'red') echo -en "\033[1;31m" ;;
                'cyan') echo -en "\033[1;36m" ;;
                'white') echo -en "\033[1;37m" ;;
                'reset') tput sgr0 ;;
        esac
}
 
# This function outputs the escape code for the specified backgroundcolor
# $1 : Color by name (black, blue, ...)
#      Or reset to revert to the terminal's default colors
# example : bgcolor green; echo 'highlighted text'; bgcolor reset
 
function bgcolor ()
{
        case $1 in
                black) echo -en "\033[0;40m" ;;
                green) echo -en "\033[0;42m" ;;
                red) echo -en "\033[0;41m" ;;
                cyan) echo -en "\033[0;46m" ;;
                white) echo -en "\033[0;47m" ;;
                reset) tput sgr0 ;;
        esac
}
 
 
#####################################################################################################################
####                                                                                                             ####
####  Execution                                                                                                  ####
####                                                                                                             ####
#####################################################################################################################
 
 
# If no options are given, show a brief help message
 
if [ "$1" == "" ]
then
        help
fi
 
# Check initialisation
 
init
 
# Get container ID (either by name or ID)
 
vzid=`vzid $2`
 
# If a container has been specified ($2) but none was found, give a warning and exit
 
if [ "$vzid" == "" ] && [ "$2" != "" ]
then
        echo "Container $2 not running"
        exit 1
fi
 
# Check what to do and call the right functions
 
case $1 in
        'init')
                init 1
                ;;
        'show')
                # If no container has been specifief, a lot of output can be expected
                # Automatically send it through 'less'. option '-R' makes sure formattion will be kept
 
                if [ "$2" == "" ]
                then
                        show $vzid #| less -R
                else
                        show $vzid
                fi
                ;;
        'brief')
                showbrief
                ;;
        'reset')
                reset $vzid
                ;;
        *)
                help;
esac
