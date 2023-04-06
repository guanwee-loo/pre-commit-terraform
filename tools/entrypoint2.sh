#!/usr/bin/env bash
#exit on error
set -e

readonly USERBASE="run"
readonly BASHPATH="/bin/bash"
readonly HOMEPATH="/home"

## Use this hard coded values - refer to install-talisman.bash script
export TALISMAN_HOME="/opt/app-root/src/.talisman/bin"
alias talisman="/opt/app-root/src/.talisman/bin/talisman_linux_amd64"


function echo_error_and_exit {
  echo -e "ERROR: " "$@" >&2
  exit 1
}

# make sure entrypoint is running as root
if [[ $(id -u) -ne 0 ]]; then
  echo_error_and_exit "Container must run as root. Use environment variable USERID to set user.\n" 
fi

# make sure USERID makes sense as UID:GID
# it looks like the alpine distro limits UID and GID to 256000, but
# could be more, so we accept any valid integers
USERID=${USERID:-"0:0"}
if [[ ! $USERID =~ ^[0-9]+:[0-9]+$ ]]; then
  echo_error_and_exit "USERID environment variable invalid, format is userid:groupid.  Received: \"$USERID\""
fi

# separate uid and gid
uid=${USERID%%:*}
gid=${USERID##*:}

# if requested UID:GID is root, go ahead and run without other processing
[[ $USERID == "0:0" ]] && exec pre-commit "$@"
