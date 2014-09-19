#!/bin/bash
################################################################################
# Backup2Mount.sh v1.0
#
# Backs up directories to mount locations using rsync and cron.
# Place script in /etc/cron.daily/.
# If backup fails, check logfile for errors: /var/log/Backup2Mount.log
#
# Maintained By: Ryan Jacobs <ryan.mjacobs@gmail.com>
# August 18, 2014 -> File creation.
# August 28, 2014 -> Remove function keyword for compatibility with other shells.
#
# Bugs:
#   - Running the bash function `bak "/home/user/"` will cause the contents of
#     the directory user to backed up and not the whole folder.
#     This is because of rsync. MAKE SURE TO OMIT EXTRA SLASH.
################################################################################

     LOGFILE="/var/log/Backup2Mount.log"
    LOCKFILE="/var/lock/Backup2Mount.lock"
MNT_LOCATION="/mnt/EXT4_Storage/"
BAK_LOCATION="/mnt/EXT4_Storage/Delta_Home_Backup/"

log()        { printf "%s - %s\n"        "$(date +%F_%T)" "$@" | tee -a "$LOGFILE"; }
log_notify() { printf "%s - %s\n"        "$(date +%F_%T)" "$@" | tee -a "$LOGFILE"; notify-send -t 15000 -u normal   "Backup2Mount" "$@"; }
log_error()  { printf "%s - ERROR: %s\n" "$(date +%F_%T)" "$@" | tee -a "$LOGFILE"; notify-send -t 30000 -u critical "Backup2Mount" "ERROR: $@"; }

bak() {
    log_notify "Backing up: $1 ..."
    start_time=$(date +%s.%N)
    /usr/bin/rsync -auz --delete "$1" "$BAK_LOCATION"
    bak_ret=$?
    end_time=$(date +%s.%N)
    time_diff=$(echo "$end_time - $start_time" | bc)

    if [ $bak_ret -eq 0 ]; then
        log_notify "Backup of $1 complete!\n(took $time_diff)"
    else
        log_error "Backup of $1 failed.\n(took $time_diff)"
    fi
}

checks() {
    # Check for root user
    if [ "$EUID" -ne 0 ]; then
        echo "Please run as root."
        exit 1
    fi

    printf "\n" >> "$LOGFILE" # add newline to log file

    # Check for required programs
    log "Checking for required programs..."
    required_programs=( "tee" "date" "mountpoint" "printf" "rsync" "bc" )
    for p in "${required_programs[@]}"; do
        if ! hash "$p" &>/dev/null; then
            log_error "$p is required. Program check failed."
            exit 1
        fi
    done
    log "Required programs check complete!"

    # Check if MNT_LOCATION is mounted
    mountpoint -q $MNT_LOCATION
    if [ $? == 1 ]; then
        log_error "$MNT_LOCATION is not mounted! Quitting."
        exit 1
    else
        log "$MNT_LOCATION is mounted."
    fi
}

### Mainline ###
checks
if mkdir $LOCKFILE &>/dev/null; then
    log "Successfully created lock."
    bak "/home/ryan/storage"
    bak "/home/ryan/working"
    rmdir $LOCKFILE &&\
        log       "Successfully removed lock." ||\
        log_error "Was unable to remove lock."
else
    log_error "There is already a lock for Backup2Mount.\n\nIf you're sure that it is not already running, you can remove\n/var/lock/Backup2Mount.lock"
    exit 1
fi
