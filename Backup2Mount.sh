#!/bin/bash
################################################################################
# Backup2Mount.sh v1.2
#
# Back up directories to mount locations using rsync and cron.
# Check logfile for errors: /var/log/Backup2Mount.log
#
# Maintained By: Ryan Jacobs <ryan.mjacobs@gmail.com>
# August 18, 2014 -> File creation.
# August 28, 2014 -> Remove function keyword for compatibility with other shells.
#  Sept. 27, 2014 -> Add QUIET variable. Improve log functions.
#   Nov. 11, 2014 -> More descriptive "run as root" message.
#   Dec. 03, 2014 -> Fix "extra slash on path" bug.
#   Dec. 03, 2014 -> Convert the script to use command-line arguments.
################################################################################

# Script Constants
SCRIPT_NAME=$0
LOGFILE="/var/log/Backup2Mount.log"
LOCKFILE="/var/lock/Backup2Mount.lock"

# CLI Default Options
bak_dirname="Backup2Mount"
quiet_opt=false

# Usage: help_msg <output_to_stderr>
# Displays help information
help_msg() {
    printf "Back up directories to mount locations.\n"
    printf "Usage: $SCRIPT_NAME [options...] <mnt_dir> [folders_to_backup...]\n\n"

    printf "  -b BAK_DIRNAME    Name of the destination directory.\n"
    printf "  -h                Display this help message.\n"
    printf "  -q                Silence stdout log output.\n"
    printf "\n"

    printf "Examples:\n"
    printf "  $SCRIPT_NAME /mnt/bak_drive /home/stuff  Backup /home/stuff to /mnt/bak_drive\n"
    printf "\n"

    printf "Report bugs to <ryan.mjacobs@gmail.com>\n"
    exit 1
}

# Usage: log [error] <message>
# Write message to log
log() {
    if [ $# -ge 2 ] && [ "$1" == "error" ]; then
        printf "%s - ERROR: %s\n" "$(date +%F_%T)" "$2" | tee -a "$LOGFILE"
    else
        printf "%s - %s\n" "$(date +%F_%T)" "$1" | tee -a "$LOGFILE"
    fi
}

# Usage: notify [error] <message>
# Results in a notify-send and a call to log
notify() {
    if [ $# -ge 2 ] && [ "$1" == "error" ]; then
        string="$2"
        msglevel="critical"
        log error "$string"
    else
        string="$1"
        msglevel="normal"
        log "$string"
    fi

    if ! $quiet_opt; then
        notify-send -t 15000 -u $msglevel "$SCRIPT_NAME" "$string"
    fi
}

# Usage: bak <folder> <bak_location>
# Backup <folder> to <bak_location>
bak() {
    # if necessary, remove extra slash so we don't screw up rsync
    path=$(echo $1 | sed 's/\/$//g')
    bak_location=$2

    log "Backing up: $path ..."
    start_time=$(date +%s.%N)
    /usr/bin/rsync -auz --delete "$path" "$bak_location"
    bak_ret=$?
    end_time=$(date +%s.%N)
    time_diff=$(echo "$end_time - $start_time" | bc)

    if [ $bak_ret -eq 0 ]; then
        notify "Backup of $path complete!\n(took $time_diff)"
    else
        notify error "Backup of $path failed.\n(took $time_diff)"
    fi
}

# Usage: checks
# Run preliminary checks. Root user, required programs, and if device mounted.
checks() {
    # Check for root user
    if [ "$EUID" -ne 0 ]; then
        echo "error: you cannot perform this operation unless you are root."
        exit 1
    fi

    printf "\n" >> "$LOGFILE" # add newline to log file

    # Check for required programs
    log "Checking for required programs..."
    required_programs=( "tee" "date" "mountpoint" "printf" "rsync" "bc" )
    for p in "${required_programs[@]}"; do
        if ! hash "$p" &>/dev/null; then
            log error "$p is required. Program check failed."
            exit 1
        fi
    done
    log "Required programs check complete!"

    # Check if MNT_LOCATION is mounted
    mountpoint -q $MNT_LOCATION
    if [ $? == 1 ]; then
        notify error "$MNT_LOCATION is not mounted! Quitting."
        exit 1
    else
        log "$MNT_LOCATION is mounted."
    fi
}
########################################
#             Mainline                 #
########################################

# get command-line flag arguments
while getopts "b:hq" opt; do
    case $opt in
        b) bak_dirname=$OPTARG ;;
        q) quiet_opt=true ;;

        h) help_msg ;;
    esac
done
shift $((OPTIND-1))

# get non-option arguments
mnt_dir=$1; shift 1
folders_to_backup="$@"

# verify arguments and options
if [ -z "$mnt_dir" ]; then
    notify error "'mnt_dir' not supplied"
    error=true
fi
if [ -z "$folders_to_backup" ]; then
    notify error "'folders_to_backup' not supplied"
    error=true
fi
if [ $error == true ]; then
    notify error "run '$SCRIPT_NAME -h' for help"
    exit 1
fi

# preliminary dep. and mount checks
checks

# create a lock and begin the backup
if mkdir $LOCKFILE &>/dev/null; then
    log "Created lock."

    # Backup each input directory
    for dir in "$folders_to_bak"; do
        bak "$dir" "$mnt_dir/$bak_dirname"
    done

    rmdir $LOCKFILE &&\
        log          "Removed lock." ||\
        notify error "Was unable to remove lock."
else
    notify error "There is already a lock for Backup2Mount.\n\nIf you're sure that it is not already running, you can remove\n/var/lock/Backup2Mount.lock"
    exit 1
fi
