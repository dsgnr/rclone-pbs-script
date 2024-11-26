#!/bin/bash

# Variables
PING_KEY="${PING_KEY:-}"
TASK="${TASK:-}"
THREADS=45
ENABLE_HEALTHCHECK="${ENABLE_HEALTHCHECK:-false}"  # Set to "false" by default if not set
log_messages=""  # Variable to store all log messages

# Function to log messages with timestamps and append to log_messages
write_msg() {
    local message="$1"
    local timestamped_msg="$(date +"%Y-%m-%d %H:%M:%S") - $message"

    # Print to console
    echo "$timestamped_msg"

    # Append to log_messages
    log_messages="$log_messages$timestamped_msg"$'\n'
}

# Function to notify health check endpoint
call_healthcheck() {
    local status="$1"
    local log_data="${2:-}"  # Optional log data, empty by default

    # Skip health check if PING_KEY or TASK is missing
    if [ -z "$PING_KEY" ] || [ -z "$TASK" ]; then
        write_msg "Skipping health check due to missing PING_KEY or TASK"
        return
    fi

    local url="https://hc-ping.com/$PING_KEY/$TASK/$status"

    # Skip if health checks are disabled
    if [ "$ENABLE_HEALTHCHECK" != "true" ]; then
        write_msg "Health check call skipped (ENABLE_HEALTHCHECK is set to false)"
        return
    fi

    # Determine HTTP method and data based on log_data presence
    if [ -n "$log_data" ]; then
        # Send POST request with log data if provided
        curl -fsS -m 10 --retry 5 -o /dev/null -X POST -d "$log_data" "$url"
    else
        # Send simple GET request otherwise
        curl -fsS -m 10 --retry 5 -o /dev/null "$url"
    fi
}

# Function to calculate and display the duration
duration() {
    local label="$1"
    local total_seconds="$2"

    local hours=$((total_seconds / 3600))
    local minutes=$(( (total_seconds % 3600) / 60 ))
    local seconds=$((total_seconds % 60))

    write_msg "$label completed in ${hours}h ${minutes}m ${seconds}s"
}

# Validate input arguments
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <source> <destination>"
    echo "  <source> is an absolute local directory path, e.g., /mnt/backup/veeam"
    echo "  <destination> is a relative path, e.g., backup/mybackup"
    exit 1
fi

# Set source and destination variables
SOURCE="$1"
DEST="$2"

# Path to the rclone config file
BASEDIR=$(dirname "$0")
CONFIG="$BASEDIR/.rclone.conf"

# Start time
START=$(date +%s)

# Log start of operation
write_msg "Starting rclone sync from $SOURCE to $DEST"
write_msg "Using configuration file: $CONFIG"

# Rclone command
RCLONE_CMD="rclone sync --progress --stats-one-line --stats=30s --fast-list --transfers=$THREADS --checkers=$THREADS --config=$CONFIG $SOURCE $DEST --delete-after"
write_msg "Executing command: $RCLONE_CMD"

# Send "start" health check notification if enabled
call_healthcheck "start"

# Execute rclone and capture error code
eval "$RCLONE_CMD"
ERROR_CODE=$?

# Calculate and log duration
END=$(date +%s)
duration "rclone sync" $((END - START))

# Error handling
if [ "$ERROR_CODE" -ne 0 ]; then
    write_msg "Error: rclone sync failed with exit code $ERROR_CODE."
    call_healthcheck "log" "rclone sync failed with exit code $ERROR_CODE"
else
    write_msg "rclone sync completed successfully."
    call_healthcheck "log" "rclone sync completed successfully"
fi

# Optionally send the accumulated log messages to the health check endpoint or save to file
if [ "$ENABLE_HEALTHCHECK" = "true" ]; then
    call_healthcheck "log" "$log_messages"
fi

# Send health check status based on the outcome
call_healthcheck "$ERROR_CODE"

# Exit with the rclone command's exit code
exit "$ERROR_CODE"
