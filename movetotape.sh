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
	return
}

# Logs input to console and to file.
log(){
	# Datetime in a sensible log format (2016-09-03 17:34:49)
	NOW=$(date +"%Y-%d-%m %T")
	echo "$NOW: $1" | tee /dev/fd/3
}

# Debug level
debug(){
	if [[ $DEBUG ]]; then
		log $1
	fi
}

# ------------------------------------------------------------------------
# Main script logic
# ------------------------------------------------------------------------

# Set up stdout + stderr to logfile, and /dev/fd/3 to console
exec 3>&1 1>>${LOG_FILE} 2>&1

# First, let's try writing to the logfile.
log "Starting archive process."

pushd $INPUT_DIR

while next_dir; do
	log $NEXT_DIR
	# log "Next directory: $ND"
done

popd