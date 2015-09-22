#!/bin/bash

function lock() {
	if [ $# -ne 1 ];then
		"Process Name missing!"
		exit -1
	fi
	NAME=$1
	LOCKFILE=/tmp/$NAME.lock.$BASHPID
	if [ -f $LOCKFILE ];then
		echo "Lockfile $LOCKFILE exists!"
		exit -1	
	else
		for PREV_LOCK_FILE in  /tmp/$NAME.lock.*
			do
				if [ -f $PREV_LOCK_FILE ]; then
					echo "Lockfile $PREV_LOCK_FILE from previous process exists"
					PREV_PID=$(echo $PREV_LOCK_FILE | cut -d'.' -f 3 )
					echo "Checking for process id $PREV_PID"
					if [ -n "$PREV_PID" ] && [ -e /proc/$PREV_PID ];then
						echo "Process $PREV_PID is still running!"
						exit -1
					else
						echo "Process seems dead. Removing stale lock file"
						rm $PREV_LOCK_FILE
					fi
				fi
			done
		touch $LOCKFILE
	fi
	
}

function unlock() {
	if [ $# -ne 1 ];then
		"Process Name missing!"
		exit -1
	fi
	NAME=$1
	LOCKFILE=/tmp/$NAME.lock.$BASHPID
	rm $LOCKFILE
}
