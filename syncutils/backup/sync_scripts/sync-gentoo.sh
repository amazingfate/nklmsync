#!/bin/bash

# ================= Configuration Begin ===================
SYNC_SYS="gentoo"

# Filesystem locations for the sync operations
SYNC_DEST="/ftp/ftp/gentoo"
SYNC_LOG_DIR="/ftp/syncutils/sync_logs"

# Set the format of the log file name(e.g. archlinux_19700101-08.log)
SYNC_LOG_FILE="${SYNC_LOG_DIR}/${SYNC_SYS}_$(date +%Y%m%d-%H).log"

# Choose LFTP or RSYNC to sync
SYNC_MODE="RSYNC"

# Set the sync server(source) to use
LFTP_SRC="http://mirrors.tuna.tsinghua.edu.cn/gentoo"

RSYNC_SRC="rsync://mirrors.4.tuna.tsinghua.edu.cn/gentoo"
RSYNC_SRC_IPv6="rsync://mirrors.6.tuna.tsinghua.edu.cn/gentoo"
# RSYNC_SRC="rsync://mirrors.ustc.edu.cn/gentoo"
# RSYNC_SRC="rsync://202.38.95.110/gentoo" # ip of ustc
# RSYNC_SRC_IPv6="rsync://mirrors.ustc.edu.cn/gentoo"
# RSYNC_SRC="rsync://mirror.bjtu.edu.cn/gentoo"
# RSYNC_SRC_IPv6="rsync://mirror6.bjtu.edu.cn/gentoo"

# lftp command and options
LFTP_CMD="lftp -f"
LFTP_FILE_DIR="/ftp/syncutils/sync_update_state"
LFTP_FILE="${LFTP_FILE_DIR}/lftp-${SYNC_SYS}"
LFTP_OPT="mirror --continue --verbose"
LFTP_DELETE="--delete"
LFTP_EXCLUDE="--exclude-glob .* --exclude experimental/ --exclude releases/ --exclude-glob Archive-Update-in-Process*"

# rsync command and options
RSYNC_CMD="rsync"
RSYNC_OPT="--recursive --times --verbose --links --hard-links --stats --no-p --no-o --no-g"
RSYNC_DELETE="--delete --delete-excluded --delete-after"
RSYNC_EXCLUDE="--exclude=.* --exclude=/experimental/ --exclude=/releases/ --exclude=Archive-Update-in-Process*"

# Whether to use --dry_run: perform a trial run with no changes made
# Set to "true" when testing
LFTP_DRY_RUN=false
RSYNC_DRY_RUN=false

# Whether to use --progress: show progress during transfer
# Set to "true" will generate a large log file
RSYNC_PROGRESS=true

# Whether to use --ipv6
# Normally, use IPv6 will faster
RSYNC_IPv6=true

if ${LFTP_DRY_RUN} ; then
    LFTP_OPT="${LFTP_OPT} --dry-run"
fi
if ${RSYNC_DRY_RUN} ; then
    RSYNC_OPT="${RSYNC_OPT} --dry-run"
fi
if ${RSYNC_PROGRESS} ; then
    RSYNC_OPT="${RSYNC_OPT} --progress"
fi
if ${RSYNC_IPv6} ; then
    RSYNC_OPT="${RSYNC_OPT} --ipv6"
    RSYNC_SRC=${RSYNC_SRC_IPv6}
fi

# Full sync command
if [ ${SYNC_MODE} == "LFTP" ] ; then
    # Make lftp file
    echo "${LFTP_OPT} ${LFTP_DELETE} ${LFTP_EXCLUDE} ${LFTP_SRC} ${SYNC_DEST}" > ${LFTP_FILE}
    SYNC_CMD_FULL="${LFTP_CMD} ${LFTP_FILE}"
else
    SYNC_CMD_FULL="${RSYNC_CMD} ${RSYNC_OPT} ${RSYNC_DELETE} ${RSYNC_EXCLUDE} ${RSYNC_SRC} ${SYNC_DEST}"
fi
# ================= Configuration End =====================

# ================= Sync Begin ============================
# Create the log file and insert a timestamp marking sync begin
touch "${SYNC_LOG_FILE}"
echo "===================================================" >> ${SYNC_LOG_FILE}
echo ">> Starting sync on $(date --rfc-2822)" >> ${SYNC_LOG_FILE}
echo ">> ---" >> ${SYNC_LOG_FILE}
echo "" >> ${SYNC_LOG_FILE}

# Sync a complete mirror
echo ">> Using the following command:" >> ${SYNC_LOG_FILE}
echo "${SYNC_CMD_FULL}" >> ${SYNC_LOG_FILE}
if [ ${SYNC_MODE} == "LFTP" ] ; then
    echo "${LFTP_FILE}:" >> ${SYNC_LOG_FILE}
    cat ${LFTP_FILE} >> ${SYNC_LOG_FILE}
fi

echo ">> Sync Infomation" >> ${SYNC_LOG_FILE}

# sync command
${SYNC_CMD_FULL} >> ${SYNC_LOG_FILE} 2>&1
SYNC_RETURN_CODE=$?

echo "" >> ${SYNC_LOG_FILE}

if [ ${SYNC_RETURN_CODE} == 0 ] ; then
    # Insert another timestamp marking sync end
    echo ">> ---" >> ${SYNC_LOG_FILE}
    echo ">> Finished sync on $(date --rfc-2822)" >> ${SYNC_LOG_FILE}
    echo "===================================================" >> ${SYNC_LOG_FILE}
else
    echo ">> ---" >> ${SYNC_LOG_FILE}
    echo ">> Error! Aborted sync on $(date --rfc-2822)" >> ${SYNC_LOG_FILE}
    echo "===================================================" >> ${SYNC_LOG_FILE}
    exit ${SYNC_RETURN_CODE}
fi

if [ ${SYNC_MODE} == "LFTP" ] ; then
    rm ${LFTP_FILE}
fi
# ================= Sync End ==============================
