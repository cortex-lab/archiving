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

# Current tape ID file
TAPE_ID_FILE=$INPUT_DIR/tape_id.txt

# Logging directory
LOG_BASE=/var/log/archiving

# Tape device (nst0 for non-rewind rather than st0)
TAPE="/dev/nst0"

# Archive logfile and contents files
LOG_FILE=$LOG_BASE/tape.log
CONTENTS_BASE=$LOG_BASE/tapes

# Path to binaries
TAR=/bin/tar
MT=/bin/mt
MKDIR=/bin/mkdir

# ------------------------------------------------------------------------
# Functions
# ------------------------------------------------------------------------

# Determine the directory to back up next
next_dir(){
	OLDEST_DIR=$(find * -maxdepth 0 -type d -printf '%T@\t%p\n' | sort -r | tail -n 1 | sed 's/[0-9]*\.[0-9]*\t//')
	DIRSIZE=$(du -s $OLDEST_DIR | cut -f1)
	debug "Next directory detected: $OLDEST_DIR, with $DIRSIZE bytes"

	OLDEST_DIR="${OLDEST_DIR#"${OLDEST_DIR%%[![:space:]]*}"}"   # remove leading whitespace characters
	OLDEST_DIR="${OLDEST_DIR%"${OLDEST_DIR##*[![:space:]]}"}"   # remove trailing whitespace characters

	if [ $OLDEST_DIR ]; then
		debug "Next directory is $OLDEST_DIR"
		return 0
	else
		debug "No next directory."
		return 1
	fi
}

# Logs input to console and to file.
log(){
	# Datetime in a sensible log format (2016-09-03 17:34:49)
	NOW=$(date +"%Y-%d-%m %T")
	echo "$NOW: $1" | tee >&3
}

# Call with log_tape FOLDERNAME FOLDERSIZE
log_tape(){
	# If the file doesn't exist, write some headers.
	if [ ! -f $TAPE_LOG ]; then
		debug "$TAPE_LOG not found, writing headers"
		echo "Date,Folder,Size" >> $TAPE_LOG || error_exit "Can't write to tape contents log at $TAPE_LOG"
	fi

	# For the log, generate an ISO-8601 datetime (who doesn't like ISO standards?)
	NOW=$(date +%Y-%m-%dT%H:%M:%S%z)
	echo "$NOW,$1,$2" >> $TAPE_LOG
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

debug "Looking for tape ID in $TAPE_ID_FILE"

TAPE_ID=$(cat $TAPE_ID_FILE) || error_exit "Can't find tape ID"
TAPE_LOG="$CONTENTS_BASE/$TAPE_ID.csv"

log "Tape ID detected as $TAPE_ID. Log file location at $TAPE_LOG"

cd $INPUT_DIR || error_exit "Cannot change directory to $INPUT_DIR"

log "Advancing to end of tape..."
$MT -f $TAPE eom || error_eject "Cannot advance to end of tape"

while next_dir; do
	log "Backing up $OLDEST_DIR..."
	TAR_STDERR=$($TAR -cvf $TAPE --totals $OLDEST_DIR 2>&1>&3 || error_eject "Cannot perform backup")
        log "$OLDEST_DIR complete. $TAR_STDERR"

	# Now let's check to see if the size of the previous tar archive is correct
        TOTALBYTES=$(echo $TAR_STDERR | grep "Total bytes written: " | grep -Eo '[0-9]{1,}' | head -1)
	if [ "$TOTALBYTES" -ge "$DIRSIZE" ]; then
		log_tape $OLDEST_DIR $TOTALBYTES
		debug "Successful backup, now deleting $OLDEST_DIR. Total $TOTALBYTES is greater than $DIRSIZE"
		rm -r $OLDEST_DIR || error_exit "Cannot remove $OLDEST_DIR. This has been successfully backed up. Please manually delete."
	else
		error_eject "FAIL. Backing up $OLDEST_DIR Total $TOTALBYTES is not greater than $DIRSIZE"
	fi
done

log "Archive complete."
cd $OLD