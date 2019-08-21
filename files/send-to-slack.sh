#!/bin/bash

# Treat unset variables as an error when substituting.
set -u

USER_SLACK_NAME=""
USER_SLACK_ID=""
MESSAGE_TO_SEND=""
FILE_TO_SEND=""
SLACK_TOKEN=""
DEFAULT_SLACK_CHANNEL="openvpn"


#######################################################################
# Parse arguments

while [ $# -gt 0 ]
do
  case "$1" in
    -s|--slack)
      USER_SLACK_NAME="$2"
      shift 2
    ;;

    -s|--slack-id)
      USER_SLACK_ID="$2"
      shift 2
    ;;

    -t|--token)
      SLACK_TOKEN="$2"
      shift 2
    ;;

    -m|--message)
      MESSAGE_TO_SEND="$2"
      shift 2
    ;;

    -f|--file)
      FILE_TO_SEND="$2"
      shift 2
    ;;

    *)
      # Non option argument
      break # Finish for loop
    ;;
  esac

done


#######################################################################
# Subroutines

error() {
  echo "[ERROR] $@" >&2
}

warn() {
  echo "[WARN] $@" >&2
}

info() {
  echo "[INFO] $@"
}


#######################################################################
# Validate settings

[[ -z "$USER_SLACK_NAME" && -z "$USER_SLACK_ID" ]] && {
  error "User slack name and ID is missed. Run script with option --slack-id <USER_SLACK_ID> or --slack <USER_SLACK_NAME>"
  exit 1
}

[[ -z "$SLACK_TOKEN" ]] && {
  error "Slack token is missed. Run script with option --slack <SLACK_TOKEN>"
  exit 1
}


#######################################################################
# Program body

if [[ -z "$USER_SLACK_ID" ]]; then
  info "Searching slack id for slack username: $USER_SLACK_NAME"
  SLACK_CHANNEL=$(curl -s "https://slack.com/api/users.list?token=${SLACK_TOKEN}" | \
    python -c "import sys, json;
  members=json.load(sys.stdin)[\"members\"];
  print {m[\"name\"]: m[\"id\"] for m in members}[\"${USER_SLACK_NAME}\"]" 2>/dev/null || echo "$DEFAULT_SLACK_CHANNEL")
else
  SLACK_CHANNEL="$USER_SLACK_ID"
fi

if [[ -n "$FILE_TO_SEND" ]]; then
  curl -F file=@"$FILE_TO_SEND" \
       -F channels=${SLACK_CHANNEL} \
       -F token=${SLACK_TOKEN} https://slack.com/api/files.upload || exit 1
elif [[ -n "$MESSAGE_TO_SEND" ]]; then
  curl -F channel=${SLACK_CHANNEL} \
       -F token=${SLACK_TOKEN} \
       -F "attachments=[{\"fallback\": \"$MESSAGE_TO_SEND\", \"color\": \"danger\", \"text\": \"$MESSAGE_TO_SEND\"}]" https://slack.com/api/chat.postMessage || exit 1
fi
