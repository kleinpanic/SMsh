#!/usr/bin/env bash

# Default message, subject, max jobs, sleep interval, and repeat count
DEFAULT_MESSAGE="Hello, this is a test message from bash!"
DEFAULT_SUBJECT="SMS"
MAX_JOBS=5             # Max number of concurrent processes
SLEEP_INTERVAL=2       # Rate limit (seconds between each message)
DRY_RUN=false          # Dry run (test mode) flag
REPEAT_COUNT=1         # Number of times to repeat the message

# Usage function to show correct usage
usage() {
    echo "Usage: $0 <phone_number|path_to_file.txt> [-m|--message \"custom message\"] [-s|--subject \"custom subject\"] [-i|--interactive] [--dry-run] [-r|--repeat count] [-c|--carrier \"carrier domain\"]"
    exit 1
}

# Check if msmtp is installed
if ! command -v msmtp &> /dev/null; then
    echo "msmtp could not be found. Please install msmtp and configure it."
    exit 1
fi

# Cleanup function to kill all child processes
cleanup() {
    echo "Caught signal, terminating child processes..."
    pkill -P $$  # Kill all child processes of the current script
    wait         # Wait for all child processes to exit
    echo "Exiting cleanly."
    exit 0
}

# Trap SIGINT (Ctrl-C) and SIGTERM
trap cleanup SIGINT SIGTERM

# Validate phone number (US only, assume 10 digits)
validate_phone_number() {
    local phone_number="$1"
    if [[ "$phone_number" =~ ^[0-9]{10}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Interactive mode to get inputs
interactive_mode() {
    read -p "Enter phone number or path to file: " INPUT
    read -p "Enter message (press Enter for default): " CUSTOM_MESSAGE
    read -p "Enter subject (press Enter for default): " CUSTOM_SUBJECT
    read -p "Enter repeat count (default is 1): " REPEAT_COUNT
}

# Extract command-line arguments
CUSTOM_MESSAGE=""
CUSTOM_SUBJECT=""
CARRIER_DOMAIN=""
INTERACTIVE_MODE=false

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -m|--message)
            shift
            CUSTOM_MESSAGE="$1"
            ;;
        -s|--subject)
            shift
            CUSTOM_SUBJECT="$1"
            ;;
        -i|--interactive)
            INTERACTIVE_MODE=true
            ;;
        --dry-run)
            DRY_RUN=true
            ;;
        -r|--repeat)
            shift
            REPEAT_COUNT="$1"
            ;;
        -c|--carrier)
            shift
            CARRIER_DOMAIN="$1"
            ;;
        *)
            INPUT="$1"
            ;;
    esac
    shift
done

# Run interactive mode if triggered
if [[ "$INTERACTIVE_MODE" == true ]]; then
    interactive_mode
fi

# Set the message and subject to use, either default or custom
MESSAGE="${CUSTOM_MESSAGE:-$DEFAULT_MESSAGE}"
SUBJECT="${CUSTOM_SUBJECT:-$DEFAULT_SUBJECT}"

# List of default carrier email-to-SMS gateways
CARRIERS=(
    "@txt.att.net"          # AT&T
    "@messaging.sprintpcs.com"  # Sprint
    "@tmomail.net"          # T-Mobile
    "@vtext.com"            # Verizon
    "@text.republicwireless.com"  # Republic Wireless
    "@sms.mycricket.com"    # Cricket Wireless
    "@vmobl.com"            # Virgin Mobile
    "@text.plusgsm.pl"      # Plus GSM (international example)
)

# Function to send email using msmtp
send_sms() {
    local phone_number="$1"
    for carrier in "${CARRIERS[@]}"; do
        local recipient="$phone_number$carrier"
        if $DRY_RUN; then
            echo "DRY RUN: Would send message to $recipient with subject '$SUBJECT' and message '$MESSAGE'"
        else
            echo -e "Subject:$SUBJECT\n\n$MESSAGE" | msmtp "$recipient" >/dev/null 2>&1
            if [ $? -eq 0 ]; then
                echo "Message sent to $recipient"
            else
                echo "Failed to send to $recipient"
            fi
        fi
        sleep $SLEEP_INTERVAL  # Rate limiting
    done
}

# Function to send SMS with the known carrier domain
send_sms_with_carrier() {
    local phone_number="$1"
    local recipient="$phone_number$CARRIER_DOMAIN"
    if $DRY_RUN; then
        echo "DRY RUN: Would send message to $recipient with subject '$SUBJECT' and message '$MESSAGE'"
    else
        echo -e "Subject:$SUBJECT\n\n$MESSAGE" | msmtp "$recipient" >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo "Message sent to $recipient"
        else
            echo "Failed to send to $recipient"
        fi
    fi
    sleep $SLEEP_INTERVAL  # Rate limiting
}

# Process a single phone number with optional carrier domain and repeat count
process_phone_number() {
    local phone_number="$1"
    if validate_phone_number "$phone_number"; then
        echo "Processing phone number: $phone_number"
        for ((i=1; i<=REPEAT_COUNT; i++)); do
            if [[ -n "$CARRIER_DOMAIN" ]]; then
                send_sms_with_carrier "$phone_number"
            else
                send_sms "$phone_number"
            fi
        done &
    else
        echo "Invalid phone number: $phone_number. Skipping."
    fi
}

# Process a .txt file with multiple phone numbers
process_file() {
    local file_path="$1"
    while IFS= read -r phone_number || [[ -n "$phone_number" ]]; do
        process_phone_number "$phone_number"
        # Limit number of concurrent processes
        while [[ $(jobs -r -p | wc -l) -ge $MAX_JOBS ]]; do
            sleep 1  # Wait for some jobs to finish before starting new ones
        done
    done < "$file_path"
}

# Wait for all background jobs (child processes) to finish
wait_for_jobs() {
    local job_count=$(jobs -r -p | wc -l)
    if [[ "$job_count" -gt 0 ]]; then
        echo "Waiting for $job_count SMS attempts to finish..."
        wait
    fi
}

# Argument validation
if [[ -z "$INPUT" ]]; then
    echo "Error: No phone number or file provided."
    usage
fi

# Determine if the argument is a phone number or a file
if [[ -f "$INPUT" ]]; then
    # It's a file, process each phone number in the file
    process_file "$INPUT"
elif validate_phone_number "$INPUT"; then
    # It's a valid phone number (10 digits), process it
    process_phone_number "$INPUT"
else
    # Invalid input, show usage
    echo "Invalid input. Please provide either a valid 10-digit phone number or a path to a .txt file."
    usage
fi

# Wait for all child processes to complete
wait_for_jobs

echo "All SMS attempts finished."

