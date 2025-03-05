# SMsh.sh

SMsh.sh is a Bash script for sending SMS messages via email-to-SMS gateways using **msmtp**. It supports sending messages to individual 10-digit phone numbers or to multiple numbers listed in a text file. With built-in options for custom messages, subjects, dry runs, and interactive mode, SMsh.sh provides a flexible way to send SMS notifications through your email service.

## Features

- **SMS via Email Gateways:** Leverage email-to-SMS gateways for various carriers.
- **Concurrent Processing:** Send messages concurrently with rate limiting.
- **Interactive Mode:** Prompt users for inputs interactively.
- **Customizable Options:** Override default message, subject, repeat count, and carrier domain.
- **Dry Run Mode:** Test the command without actually sending messages.
- **Signal Handling:** Cleanly handles SIGINT/SIGTERM and terminates child processes.

## Prerequisites

- **msmtp:** Ensure msmtp is installed and configured for your email service.
- **Bash:** The script is written for Bash and tested on Unix-like systems.

## Usage

```bash
./SMsh.sh <phone_number|path_to_file.txt> [options]
```

Options

    -m, --message "custom message"
    Set a custom message (default: "Hello, this is a test message from bash!").

    -s, --subject "custom subject"
    Set a custom subject (default: "SMS").

    -i, --interactive
    Run the script in interactive mode to prompt for inputs.

    --dry-run
    Run the script without sending any actual messages (test mode).

    -r, --repeat count
    Specify the number of times to repeat the message (default: 1).

    -c, --carrier "carrier domain"
    Use a specific carrier domain instead of the default list.

Examples

Send a test SMS to a single phone number:

./SMsh.sh 1234567890 --dry-run

Send a custom message to all numbers in a file:

./SMsh.sh numbers.txt -m "Your custom message" -s "Alert" -r 3

Future Improvements

See the TODO.md file for a list of planned enhancements.
License

This project is licensed under the MIT License.
