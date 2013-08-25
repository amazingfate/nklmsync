#!/bin/bash

# Make sure only 1 instance runs
SYNC_LOCK_DIR="/ftp/syncutils/sync_update_state"
SYNC_LOCK_FILE="${SYNC_LOCK_DIR}/mirror-updating"
if [ -e ${SYNC_LOCK_FILE} ] ; then
    exit 1
else
    touch ${SYNC_LOCK_FILE}
fi

# ================= Configuration Begin ===================
# Mirrors to sync
#   - prefix a mirror with a ! to disable it
MIRRORS=(archlinux rpmfusion gentoo gentoo-portage linuxmint ubuntu centos fedora epel rubygems)

# Location for log file
SYNC_LOG_DIR="/ftp/syncutils/sync_logs"

# Set the format of the log file name(e.g. sync-mirror_19700101.log)
SYNC_LOG_FILE="${SYNC_LOG_DIR}/sync-mirror_$(date +%Y%m%d).log"
# ================= Configuration End =====================

# ================= Sync Begin ============================
# Create the log file and insert a timestamp marking sync begin
echo "===================================================" >> ${SYNC_LOG_FILE}
echo ">> Starting sync on $(date --rfc-2822)" >> ${SYNC_LOG_FILE}
echo ">> ---" >> ${SYNC_LOG_FILE}
echo "" >> ${SYNC_LOG_FILE}

for mirror in ${MIRRORS[@]} ; do
    if [ ${mirror:0:1} == "!" ] ; then
        echo ">> [$(date "+%H:%M:%S")]Skip mirror ${mirror:1}" >> ${SYNC_LOG_FILE}
    else
        touch "${SYNC_LOCK_DIR}/updating-${mirror}"
        echo ">> [$(date "+%H:%M:%S")]Syncing mirror ${mirror} ..." >> ${SYNC_LOG_FILE}
        /ftp/syncutils/sync_scripts/sync-${mirror}.sh
        if [ $? == 0 ] ; then
           echo ">> [$(date "+%H:%M:%S")]Sync mirror ${mirror} DONE!" >> ${SYNC_LOG_FILE}
       else
           echo ">> [$(date "+%H:%M:%S")]Sync mirror ${mirror} *FAILED*! Please check the log file for details." >> ${SYNC_LOG_FILE}
       fi
        rm "${SYNC_LOCK_DIR}/updating-${mirror}"
    fi

    # Sleep 5 seconds after each mirror to avoid too many concurrent connections
    # to sync server if the TCP connection does not close in a timely manner
    sleep 5
done

# Insert another timestamp marking sync end
echo "" >> ${SYNC_LOG_FILE}
echo ">> ---" >> ${SYNC_LOG_FILE}
echo ">> Finished sync on $(date --rfc-2822)" >> ${SYNC_LOG_FILE}
echo "===================================================" >> ${SYNC_LOG_FILE}
# ================= Sync End ==============================

rm ${SYNC_LOCK_FILE}
