#!/bin/bash
################################################################################
# Backup2Mount.sh v1.1
#
# Backs up directories to mount locations using rsync and cron.
#
# Place script in /etc/cron.daily/ to run once a day.
# Check logfile for errors: /var/log/Backup2Mount.log
#
# Maintained By: Ryan Jacobs <ryan.mjacobs@gmail.com>
# August 18, 2014 -> File creation.
# August 28, 2014 -> Remove function keyword for compatibility with other shells.
#  Sept. 27, 2014 -> Add QUIET variable. Improve log functions.
#   Nov. 11, 2014 -> More descriptive "run as root" message.
#   Dec. 03, 2014 -> Fix "extra slash on path" bug.
################################################################################

       QUIET=false
     LOGFILE="/var/log/Backup2Mount.log"
    LOCKFILE="/var/lock/Backup2Mount.lock"
MNT_LOCATION="/mnt/EXT4_Storage/"
BAK_LOCATION="/mnt/EXT4_Storage/Delta_Home_Backup/"

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

    if ! $QUIET; then
        notify-send -t 15000 -u $msglevel "Backup2Mount" "$string"
    fi
}

# Usage: bak <folder>
# Backup folder to $BAK_LOCATION
bak() {
    # if necessary, remove extra slash so we don't screw up rsync
    path=$(echo $1 | sed 's/\/$//g')

    log "Backing up: $path ..."
    start_time=$(date +%s.%N)
    /usr/bin/rsync -auz --delete "$path" "$BAK_LOCATION"
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

## Mainline ##
checks
if mkdir $LOCKFILE &>/dev/null; then
    log "Created lock."
    bak "/home/ryan/storage"
    bak "/home/ryan/working"
    rmdir $LOCKFILE &&\
        log          "Removed lock." ||\
        notify error "Was unable to remove lock."
else
    notify error "There is already a lock for Backup2Mount.\n\nIf you're sure that it is not already running, you can remove\n/var/lock/Backup2Mount.lock"
    exit 1
fi
