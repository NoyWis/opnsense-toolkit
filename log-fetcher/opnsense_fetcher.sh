#!/bin/bash
# Pull parsed connection logs from OPNsense and ship them to a log server.
# A file is deleted on the firewall only after it was copied successfully.
# Configure via environment (or edit the defaults); intended to run from cron.

OPNSENSE_SSH="ssh -p ${OPNSENSE_SSH_PORT:-22} ${OPNSENSE_USER:-root}@${OPNSENSE_HOST:?set OPNSENSE_HOST}"
REMOTE_USER="${REMOTE_USER:?set REMOTE_USER}"
REMOTE_HOST="${REMOTE_HOST:?set REMOTE_HOST}"
REMOTE_DIR="${REMOTE_DIR:-/opt/opnsense-logs}"
SOURCE_DIR="${SOURCE_DIR:-/var/log/parsed_connections}"
LOCAL_TMP="${LOCAL_TMP:-/tmp/opnsense_logs}"
LOG_FILE="${LOG_FILE:-$HOME/opnsense_fetcher.log}"
mkdir -p "$LOCAL_TMP"

files=$($OPNSENSE_SSH "find $SOURCE_DIR -maxdepth 1 -name 'connections_*.txt' -type f" 2>/dev/null)
[ -z "$files" ] && exit 0

for file in $files; do
    filename=$(basename "$file")
    $OPNSENSE_SSH "cat '$file'" > "$LOCAL_TMP/$filename"
    if [ -s "$LOCAL_TMP/$filename" ]; then
        if scp "$LOCAL_TMP/$filename" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/"; then
            $OPNSENSE_SSH "rm -f '$file'"
            echo "$(date): sent $filename" >> "$LOG_FILE"
        else
            echo "$(date): ERROR sending $filename" >> "$LOG_FILE"
        fi
    fi
    rm -f "$LOCAL_TMP/$filename"
done
