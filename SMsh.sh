#!/usr/bin/env bash
# SMsh.sh – Production-ready SMS sender via email-to-SMS gateways using msmtp
# Maintainer: Kline
# Version: 1.1.2
# Updated: 2025-04-29

set -o errexit
set -o nounset
set -o pipefail

ORIGINAL_ARGS=("$@")

#─── ASCII-Art Banner ───────────────────────────────────────────────────────────
cat <<'EOF'
                   __  '                       _             _                                  __  '           ,:'/¯/`:,       .·/¯/`:,'   
            ,·:'´/::::/'`;·.,             ,·´/:::::'`:,   ,:´/::::'`:,'                  ,·:'´/::::/'`;·.,      /:/_/::::/';    /:/_/::::';  
        .:´::::/::::/:::::::`;         '/  /:::::::::'`·/::/::::::::/'\             .:´::::/::::/:::::::`;   /:'     '`:/::;  /·´    `·,::'; 
       /:;:· '´ ¯¯'`^·-;::::/' ‘       /,·'´ ¯¯'`·;:::/:;·´ ¯ '`·;/:::i          /:;:· '´ ¯¯'`^·-;::::/' ‘ ;         ';:';  ;         ';:; 
      /·´           _   '`;/‘        /            '`;':/            \:::';        /·´           _   '`;/‘    |         'i::i  i         'i:';°
     'i            ;::::'`;*        ,'               `'               ';:::i°     'i            ;::::'`;*      ';        ;'::/¯/;        ';:;‘'
      `;           '`;:::::'`:,    ,'                                  ;::i‘'      `;           '`;:::::'`:,   'i        i':/_/:';        ;:';°
        `·,           '`·;:::::';  ;'       ,^,         ,:^,          'i::;°        `·,           '`·;:::::';  ;       i·´   '`·;       ;:/° 
      ,~:-'`·,           `:;::/' 'i        ;:::\       ;/   ',         'i:;'       ,~:-'`·,           `:;::/'  ';      ;·,  '  ,·;      ;/'   
     /:::::::::';           ';/   'i       'i::/  \     /      ;        ;/        /:::::::::';           ';/     ';    ';/ '`'*'´  ';    ';/' '‘  
   ,:~·- . -·'´          ,'´      ;      'i:/     `*'´       'i       ;/ °     ,:~·- . -·'´          ,'´        \   /          '\   '/'      
   '`·,               , ·'´        '`.    ,'                   '.     /         '`·,               , ·'´           '`'´             `''´   '    
        '`*^·–·^*'´'           ‘     `*´                      `'*'´                '`*^·–·^*'´'           ‘                      '          
EOF

#─── Colours ───────────────────────────────────────────────────────────────────
RED='\e[0;31m';    GREEN='\e[0;32m'
YELLOW='\e[0;33m'; BLUE='\e[0;34m'
CYAN='\e[0;36m';   BOLD='\e[1m'
RESET='\e[0m'

########## Config ##########
DEFAULT_MESSAGE="Hello, this is a test message from bash!"
DEFAULT_SUBJECT="SMS"
TEMP_EMAIL_MODE=false # if true, use disposable temp email. 
TEMP_EMAIL_CYCLE=0                  # Cycle interval in minutes; 0 = disabled.
TEMP_EMAIL_TS=0                     # Timestamp when current temp email was fetched
TEMP_EMAIL_ADDR=""                  # Current Disposable Email Addr 
SID_TOKEN=""                        # Session Token For Guerrilla Mail API
TEMP_MSMTP_RC="/tmp/msmtprc.$$"     # Temp msmtp config 
MAX_JOBS=5
SLEEP_INTERVAL=2
DRY_RUN=false
DEBUG=false
REPEAT_COUNT=1
CARRIER_DOMAIN=""
INTERACTIVE_MODE=false
DAEMON_MODE=false
NO_DAEMON=false
LOG_FILE="./smsh.log"
PID_FILE="./smsh.pid"
VERSION="1.1.2"

CARRIERS=(
  "@txt.att.net"
  "@messaging.sprintpcs.com"
  "@tmomail.net"
  "@vtext.com"
  "@text.republicwireless.com"
  "@sms.mycricket.com"
  "@vmobl.com"
  "@text.plusgsm.pl"
)

########## Usage ##########
usage() {
  cat <<EOF
Usage: $0 [options] <phone_number|path_to_file.txt>

Options:
  -m, --message "text"     Custom message (default: "$DEFAULT_MESSAGE")
  -s, --subject "text"     Custom subject (default: "$DEFAULT_SUBJECT")
  -r, --repeat N           Repeat count (default: $REPEAT_COUNT)
  -c, --carrier "@domain"  Specific carrier gateway
  -i, --interactive        Prompt interactively
      --dry-run            Preview without sending
  -x, --debug              Show verbose SMTP logs
  -d, --daemon             Run as background daemon
      --no-daemon          (internal) Skip re-daemonizing
  -V, --version            Print version and exit
  -h, --help               Show this help and exit
  -T, --temp-email N       Cycle a fresh temp-email every N minutes
EOF
  exit 1
}

########## Error & Cleanup ##########
error() { echo -e "${RED}Error at line $1. Exiting.${RESET}" >&2; exit 1; }
trap 'error ${LINENO}' ERR

cleanup() {
  echo -e "${YELLOW}Terminating…${RESET}"
  pkill -P $$ || true
  wait || true
  exit 0
}
trap cleanup SIGINT SIGTERM

########## Dependencies ##########
command -v msmtp >/dev/null 2>&1 || { echo -e "${RED}msmtp not found.${RESET}" >&2; exit 1; }

########## Helpers ##########
validate_phone() { [[ "$1" =~ ^[0-9]{10}$ ]]; }

interactive_mode() {
  read -rp "Enter phone or file: " INPUT
  read -rp "Message [${DEFAULT_MESSAGE}]: " CUSTOM_MESSAGE
  read -rp "Subject [${DEFAULT_SUBJECT}]: " CUSTOM_SUBJECT
  read -rp "Repeat [${REPEAT_COUNT}]: " REPEAT_COUNT
  read -rp "Carrier [${CARRIER_DOMAIN:-none}]: " CARRIER_DOMAIN
}

### Disposable-email support (Guerrilla Mail) ###
generate_temp_email() {
  local json addr
  json=$(curl -s 'https://api.guerrillamail.com/ajax.php?f=get_email_address')
  addr=$(echo "$json" | grep -oP '"email_addr":"\K[^"]+')
  SID_TOKEN=$(echo "$json" | grep -oP '"sid_token":"\K[^"]+')
  TEMP_EMAIL_ADDR="$addr"
  # use local clock to track when we fetched it
  TEMP_EMAIL_TS=$(date +%s)
  echo -e "${CYAN}→ New temp email: $addr${RESET}"
}

setup_temp_msmtprc() {
  # copy your real config, then just override the From:
  cp ~/.msmtprc "$TEMP_MSMTP_RC"
  echo -e "defaults\nfrom $TEMP_EMAIL_ADDR" >>"$TEMP_MSMTP_RC"
}

maybe_rotate_email() {
  # Skip rotation if temp-email mode is disabled
  if [[ "$TEMP_EMAIL_MODE" != true ]]; then
    return
  fi

  local now
  now=$(date +%s)
  # If we don’t have an address yet, or it's older than the cycle interval, rotate
  if [[ -z "$TEMP_EMAIL_ADDR" ]] || (( now - TEMP_EMAIL_TS >= TEMP_EMAIL_CYCLE * 60 )); then
    generate_temp_email
    setup_temp_msmtprc
  fi
}

send_sms_recipient() {
  local rcpt=$1

  if $DRY_RUN; then
    echo -e "${YELLOW}[DRY RUN]${RESET} To: ${rcpt}"
    return
  fi

  # rotate temp email and select msmtp config
  if $TEMP_EMAIL_MODE; then
    maybe_rotate_email
    MSMTP_ARGS=(--file "$TEMP_MSMTP_RC" -f "$TEMP_EMAIL_ADDR")
  else
    MSMTP_ARGS=()
  fi

  if $DEBUG; then
    echo -e "${CYAN}---- DEBUG: Sending to ${rcpt} ----${RESET}"
    echo -e "Subject:${SUBJECT}\n\n${MESSAGE}" \
      |msmtp -v "${MSMTP_ARGS[@]}" "$rcpt" 2>&1 \
      && echo -e "${GREEN}[DEBUG] Success${RESET}" \
      || echo -e "${RED}[DEBUG] Failed${RESET}"
  else
    # override ~/.msmtprc logfile and silence all output
    if echo -e "Subject:${SUBJECT}\n\n${MESSAGE}" \
         | msmtp "${MSMTP_ARGS[@]}" --logfile /dev/null "$rcpt" >/dev/null 2>&1; then
      echo -e "${GREEN}Message sent to ${rcpt}${RESET}"
    else
      echo -e "${RED}Message failed to ${rcpt}${RESET}"
    fi
  fi

  sleep "$SLEEP_INTERVAL"
}

send_all_carriers() {
  local phone=$1
  for gw in "${CARRIERS[@]}"; do
    send_sms_recipient "${phone}${gw}" &
    while (( $(jobs -r|wc -l) >= MAX_JOBS )); do sleep 1; done
  done
}

process_phone() {
  local ph=$1
  if validate_phone "$ph"; then
    echo -e "${BLUE}Processing phone number: $ph${RESET}"
    for ((i=1;i<=REPEAT_COUNT;i++)); do
      if [[ -n "$CARRIER_DOMAIN" ]]; then
        send_sms_recipient "${ph}${CARRIER_DOMAIN}" &
      else
        send_all_carriers "$ph"
      fi
    done
  else
    echo -e "${RED}Invalid phone: $ph${RESET}"
  fi
}

process_file() {
  local f=$1
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    process_phone "$line"
  done <"$f"
}

wait_jobs() {
  local cnt=$(jobs -r|wc -l)
  (( cnt>0 )) && { echo -e "${BLUE}Waiting for $cnt attempt(s)…${RESET}"; wait; }
}

########## Arg Parsing ##########
(( $#==0 )) && usage
while (( $#>0 )); do
  case $1 in
    -m|--message)    shift; CUSTOM_MESSAGE="$1"; shift ;;
    -s|--subject)    shift; CUSTOM_SUBJECT="$1"; shift ;;
    -r|--repeat)     shift; REPEAT_COUNT="$1"; shift ;;
    -c|--carrier)    shift; CARRIER_DOMAIN="$1"; shift ;;
    -i|--interactive) INTERACTIVE_MODE=true; shift ;;
    --dry-run)       DRY_RUN=true; shift ;;
    -x|--debug)      DEBUG=true; shift ;;
    -d|--daemon)     DAEMON_MODE=true; shift ;;
    --no-daemon)     NO_DAEMON=true; shift ;;
    -V|--version)    echo "SMsh.sh v$VERSION"; exit 0 ;;
    -h|--help)       usage ;;
    -T|--temp-email)
        shift
        TEMP_EMAIL_MODE=true
        TEMP_EMAIL_CYCLE="$1"
        shift
        ;;
    *)               INPUT="$1"; shift ;;
  esac
done

$INTERACTIVE_MODE && interactive_mode

MESSAGE="${CUSTOM_MESSAGE:-$DEFAULT_MESSAGE}"
SUBJECT="${CUSTOM_SUBJECT:-$DEFAULT_SUBJECT}"

# Basic sanity
[[ "$REPEAT_COUNT" =~ ^[1-9][0-9]*$ ]]   || { echo -e "${RED}Bad repeat:${REPEAT_COUNT}${RESET}"; exit 1; }
[[ "$MAX_JOBS"    =~ ^[1-9][0-9]*$ ]]   || { echo -e "${RED}Bad max jobs${RESET}"; exit 1; }
[[ "$SLEEP_INTERVAL" =~ ^[0-9]+$ ]]     || { echo -e "${RED}Bad sleep interval${RESET}"; exit 1; }
if [[ -n "$CARRIER_DOMAIN" && ! "$CARRIER_DOMAIN" =~ ^@[A-Za-z0-9._-]+$ ]]; then
  echo -e "${RED}Bad carrier domain${RESET}"; exit 1
fi

########## Daemon Mode ##########
if $DAEMON_MODE && ! $NO_DAEMON; then
  [[ -f $PID_FILE ]] && { echo -e "${RED}Already running (PID $(<"$PID_FILE"))${RESET}"; exit 1; }
  echo -e "${CYAN}Launching daemon…${RESET}"
  args=()
  for a in "${ORIGINAL_ARGS[@]}"; do [[ "$a" =~ ^-d|--daemon$ ]] || args+=( "$a" ); done
  args+=( --no-daemon )
  setsid bash "$0" "${args[@]}" >"$LOG_FILE" 2>&1 &
  echo $! >"$PID_FILE"
  echo -e "${CYAN}Daemon PID $(<"$PID_FILE") → log:$LOG_FILE${RESET}"
  exit 0
fi

########## Main ##########
[[ -z "${INPUT:-}" ]] && { echo -e "${RED}No phone or file given${RESET}"; usage; }

if [[ -f "$INPUT" ]]; then
  [[ -r "$INPUT" ]] || { echo -e "${RED}Cannot read $INPUT${RESET}"; exit 1; }
  process_file "$INPUT"
elif validate_phone "$INPUT"; then
  process_phone "$INPUT"
else
  echo -e "${RED}Invalid input: $INPUT${RESET}"; usage
fi

wait_jobs
echo -e "${GREEN}All SMS attempts finished.${RESET}"

