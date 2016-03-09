#!/bin/bash
# movetotape.sh
#
# BASH shell script for moving contents of a directory to tape
# and keeping a log of moved files and tape ID.
# Can be run manually or automatically by cron.
#
# Max Hunter, CortexLab, 2016
#

# Input directory
INPUT_DIR=/mnt/data/toarchive/

# Current tape ID file
TAPE_ID_FILE=$INPUT_DIR/tape_id

# Logging directory
LOG_BASE=/var/log/archiving

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
next_directory(){
	pushd $INPUT_DIR
	# logic goes here
	popd
}

# Logs input to console and to file.
log(){
	# Datetime in a sensible log format (2016-09-03 17:34:49)
	NOW=$(date +"%Y-%d-%m %T")
	echo "$NOW: $1" | tee /dev/fd/3
}

# ------------------------------------------------------------------------
# Main script logic
# ------------------------------------------------------------------------

# Set up stdout + stderr to logfile, and /dev/fd/3 to console
exec 3>&1 1>>${LOG_FILE} 2>&1

# First, let's try writing to the logfile.
log "Starting archive process."
