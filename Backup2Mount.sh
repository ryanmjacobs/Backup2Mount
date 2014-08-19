#!/bin/bash
################################################################################
# /etc/cron.daily/Backup2Mount.sh
#
# Maintained By: Ryan Jacobs <ryan.mjacobs@gmail.com>
# August 18, 2014 -> Initial creation.
#
# Bugs:
#   - Running `bak "/home/user/"` will cause the contents of user to backed up
#     and not the whole folder. This is because of rsync.
################################################################################

     LOGFILE="/var/log/Backup2Mount.log"
    LOCKFILE="/var/lock/Backup2Mount.lock"
BAK_LOCATION="/mnt/EXT4_Storage/Delta_Home_Backup/"

printf "\n" >> "$LOGFILE" # add newline to log file

function log() { printf "%s - %s\n" "$(date +%F_%T)" "$@" | tee -a "$LOGFILE"; }

function bak() {
    log "Beginning backup of $1..."
    start_time=$(date +%s.%N)
    /usr/bin/rsync -auz --delete "$1" "$BAK_LOCATION"
    bak_ret=$?
    end_time=$(date +%s.%N)
    time_diff=$(echo "$end_time - $start_time" | bc)

    if [ $bak_ret -eq 0 ]; then
        log "Backup of $1 completed successfully."
    else
        log "Error: Backup of $1 failed."
    fi
    log "Backup of $1 took $time_diff."
}

function checks() {
    # Check for required programs
    log "Checking for required programs..."
    required_programs=( "tee" "date" "mountpoint" "printf" "rsync" "bc" )
    for p in "${required_programs[@]}"; do
        if ! hash "$p" &>/dev/null; then
            log "Error: $p is required. Program check failed."
            exit 1
        fi
    done
    log "Required programs check complete!"

    # Check if EXT4_Storage is mounted
    mountpoint -q /mnt/EXT4_Storage
    if [ $? == 1 ]; then
        log "Error: /mnt/EXT4_Storage is not mounted! Quitting."
        exit 1
    else
        log "/mnt/EXT4_Storage is mounted."
    fi
}

### Mainline ###
if mkdir $LOCKFILE &>/dev/null; then
    checks
    (bak "/home/ryan/storage" && bak "/home/ryan/working") && exit 0 || exit 1
    rmdir $LOCKFILE
else
    log "Error: There is already a lockfile for Backup2Mount. If you're sure it is not already running, you can remove /var/lock/Backup2Mount.lock"
    exit 1
fi
