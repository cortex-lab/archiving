#!/bin/bash
# movetotape.sh
#
# BASH shell script for moving contents of a directory to tape
# and keeping a log of moved files and tape ID.
# Can be run manually or automatically by cron.
#
# Max Hunter, CortexLab, 2016
#
DEBUG=true

# Input directory
INPUT_DIR=/mnt/data/toarchive/
# INPUT_DIR=/Users/nippoo/Development/archiving/input

# Current tape ID file
TAPE_ID_FILE=$INPUT_DIR/tape_id

# Logging directory
LOG_BASE=/var/log/archiving
# LOG_BASE=/Users/nippoo/Development/archiving/log

# Tape device (nst0 for non-rewind rather than st0)
TAPE="/dev/nst0"

# Archive logfile and contents files
LOG_FILE=$LOG_BASE/tape.log
CONTENTS=$LOG_BASE/tapes/$TAPE_ID.csv

# Path to binaries
TAR=/bin/tar
MT=/bin/mt
MKDIR=/bin/mkdir

# ------------------------------------------------------------------------
# Functions
# ------------------------------------------------------------------------

# Determine the directory to back up next
next_dir(){
	OLDEST_DIR=$(find . -maxdepth 1 -type d -printf '%T@\t%p\n' | sort -r | tail -n 1 | sed 's/[0-9]*\.[0-9]*\t//')
	DIRSIZE=$(du -sb $OLDEST_DIR | cut -f1)
	debug "$OLDEST_DIR is $DIRSIZE bytes"
}

# Logs input to console and to file.
log(){
	# Datetime in a sensible log format (2016-09-03 17:34:49)
	NOW=$(date +"%Y-%d-%m %T")
	echo "$NOW: $1" | tee /dev/fd/3
}

# Debug level logging
debug(){
	if $DEBUG; then
		log "Debug: $1"
	fi
}

error_exit()
{
	log "Aborting: $1"
	exit 1
}

error_eject()
{
	log "Ejecting and aborting: $1"
	$MT -f $TAPE eject
	exit 1
}


# ------------------------------------------------------------------------
# Main script logic
# ------------------------------------------------------------------------

# Set up stdout + stderr to logfile, and /dev/fd/3 to console
exec 3>&1 1>>${LOG_FILE} 2>&1

# First, let's try writing to the logfile.
log "Starting archive process."

OLD=$(pwd)

cd $INPUT_DIR || error_exit "Cannot change directory to $INPUT_DIR"

log "Advancing to end of tape..."
$MT -f $TAPE eom || error_eject "Cannot advance to end of tape"

while next_dir; do
	log "Backing up $OLDEST_DIR..."
	TAR_STDERR=$($TAR -cvf $TAPE --totals $OLDEST_DIR 2>&1 > /dev/tty || error_eject "Cannot perform backup")
        log "$OLDEST_DIR complete. $TAR_STDERR"

	# Now let's check to see if the size of the previous tar archive is correct
        TOTALBYTES=$(echo $TAR_STDERR | grep "Total bytes written: " | grep -Eo '[0-9]{1,}' | head -1)
	if [ "$TOTALBYTES" -ge "$DIRSIZE" ]; then
		debug "Successful backup; total $TOTALBYTES is greater than $DIRSIZE"
		rm -r $OLDEST_DIR
	else
		error_eject "FAIL. Total $TOTALBYTES is not greater than $DIRSIZE"
	fi
done

log "Archive complete."
cd $OLD