#!/bin/sh

LOG_FILE=un-installer.log

# logger
log() {
  echo '[' "$(date +"%Y-%m-%d %T")" ']:' INFO "$@" | tee -a "$LOG_FILE"
}

sudo systemctl daemon-reload

CURRENT_DIRECTORY=$(pwd)
WEEVE_AGENT_DIRECTORY="$CURRENT_DIRECTORY"/weeve-agent

SERVICE_FILE=/lib/systemd/system/weeve-agent.service

ARGUMENTS_FILE=/lib/systemd/system/weeve-agent.argconf

if RESULT=$(systemctl is-active weeve-agent 2>&1); then
sudo systemctl stop weeve-agent
sudo systemctl daemon-reload
log weeve-agent service stopped
else
log weeve-agent service not running
fi

if [ -f "$SERVICE_FILE" ]; then
sudo rm "$SERVICE_FILE"
log "$SERVICE_FILE" removed
else
log "$SERVICE_FILE" doesnt exists
fi

if [ -f "$ARGUMENTS_FILE" ]; then
sudo rm "$ARGUMENTS_FILE"
log "$ARGUMENTS_FILE" removed
else
log "$ARGUMENTS_FILE" doesnt exists
fi

if [ -d "$WEEVE_AGENT_DIRECTORY" ] ; then
rm -r "$WEEVE_AGENT_DIRECTORY"
log "$WEEVE_AGENT_DIRECTORY" removed
else
log "$WEEVE_AGENT_DIRECTORY" doesnt exists
fi

log done