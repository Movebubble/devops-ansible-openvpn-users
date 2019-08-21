#!/bin/bash

# Treat unset variables as an error when substituting.
set -u

USER_EMAIL=""
KEY_SERVER="hkp://pool.sks-keyservers.net"


#######################################################################
# Parse arguments

while [ $# -gt 0 ]
do
  case "$1" in
    -e|--email)
      USER_EMAIL="$2"
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

[[ -z "$USER_EMAIL" ]] && {
  error "User email address is missed. Run script with option --email <EMAIL>"
  exit 1
}


#######################################################################
# Program body

EXISTING_KEYS_COUNT=$(gpg --list-keys "<${USER_EMAIL}>" 2>/dev/null| grep '^uid' | wc -l )
if (( 1 == $EXISTING_KEYS_COUNT )); then
  info "GPG key for email \"$USER_EMAIL\" already exists. Nothing to import."
  exit 0
elif (( 1 < $EXISTING_KEYS_COUNT )); then
  error "More than 1 key found on key server for email: $USER_EMAIL. Change email to the one that corresponds to one gpg key.\n"
  exit 1
fi

info "Search user gpg keys"
ERROR_FILE_GPG_SEARCG_KEY=$(mktemp)
GPG_PUB_KEY_ID=$(gpg --keyserver $KEY_SERVER --dry-run --batch --search-keys "$USER_EMAIL" 2>"$ERROR_FILE_GPG_SEARCG_KEY" | grep -v '(revoked)' | awk '/key /{print $5}' | sed 's/,//')
KEYS_COUNT=$(echo "$GPG_PUB_KEY_ID"| wc -l)

if [[ -z "$GPG_PUB_KEY_ID" ]]; then
  error "No keys found on key server for email: $USER_EMAIL. Will try to search it in 10 minutes.\n"
  cat "$ERROR_FILE_GPG_SEARCG_KEY"
  rm "$ERROR_FILE_GPG_SEARCG_KEY"
  exit 1
elif [[ "$KEYS_COUNT" != 1 ]]; then
  error "More than 1 key found on key server for email: $USER_EMAIL. Change email to the one that corresponds to one gpg key.\n"
  cat "$ERROR_FILE_GPG_SEARCG_KEY"
  rm "$ERROR_FILE_GPG_SEARCG_KEY"
  exit 1
else
  rm "$ERROR_FILE_GPG_SEARCG_KEY"
  info "Found key for email ${USER_EMAIL}: ${GPG_PUB_KEY_ID}."
fi

info "Importing the key from a key server."
gpg --keyserver $KEY_SERVER --recv-keys $GPG_PUB_KEY_ID || exit 1
