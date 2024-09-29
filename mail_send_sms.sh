#!/usr/bin/env bash

# Phone number and message
PHONE_NUMBER="4344098567"  # Replace with the recipient's phone number
MESSAGE="Hello, this is a test message from bash!"  # The message you want to send
SUBJECT="Test Message"

# List of carrier email-to-SMS gateways
CARRIERS=(
    "$PHONE_NUMBER@txt.att.net"         # AT&T
    "$PHONE_NUMBER@messaging.sprintpcs.com"  # Sprint
    "$PHONE_NUMBER@tmomail.net"         # T-Mobile
    "$PHONE_NUMBER@vtext.com"           # Verizon
    "$PHONE_NUMBER@text.republicwireless.com"  # Republic Wireless
    "$PHONE_NUMBER@sms.mycricket.com"   # Cricket Wireless
    "$PHONE_NUMBER@vmobl.com"           # Virgin Mobile
    "$PHONE_NUMBER@text.plusgsm.pl"     # Plus GSM (international example)
)

# Function to send email
send_sms() {
    local recipient="$1"
    echo "$MESSAGE" | mail -s "$SUBJECT" "$recipient"
    if [ $? -eq 0 ]; then
        echo "Message sent to $recipient"
        return 0
    else
        echo "Failed to send to $recipient"
        return 1
    fi
}

# Try each carrier until the message is successfully sent
for carrier in "${CARRIERS[@]}"; do
    send_sms "$carrier"
    if [ $? -eq 0 ]; then
        echo "SMS successfully sent."
        exit 0
    fi
done

echo "Failed to send SMS to all carriers."
exit 1
