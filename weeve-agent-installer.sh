#!/bin/sh

LOG_FILE=installer.log

# logger
log() {
  echo '[' "$(date +"%Y-%m-%d %T")" ']:' INFO "$@" | tee -a $LOG_FILE
}

# function to clean-up the contents on failure at any point
# note that this function will be called even at successful ending of the script hence the condition check on variable
trap cleanup EXIT

# if in case the user have deleted the weeve-agent.service and did not reload the systemd daemon
sudo systemctl daemon-reload

cleanup() {
  if [ "$PROCESS_COMPLETE" = false ]; then
    log cleaning up the contents ...
    sudo systemctl stop weeve-agent
    sudo systemctl daemon-reload
    sudo rm /lib/systemd/system/weeve-agent.service
    sudo rm /lib/systemd/system/weeve-agent.argconf
    rm -r ./weeve-agent
  fi
}

PROCESS_COMPLETE=false

log Read command line arguments ...

KEY=$(echo "$@" | cut --fields 1 --delimiter='=')
VALUE=$(echo "$@" | cut --fields 2 --delimiter='=')

if [ "$KEY" = NodeName ] ; then
  NODE_NAME="$VALUE"
fi

if [ -z "$NODE_NAME" ]; then
log NODE_NAME is required
read -p "Give a node name: " NODE_NAME
fi

log All arguments are set
log Name of the node: "$NODE_NAME"

log Checking if a instance of weeve-agent is already running ...

CURRENT_DIRECTORY=$(pwd)

WEEVE_AGENT_DIRECTORY="$CURRENT_DIRECTORY"/weeve-agent
SERVICE_FILE=/lib/systemd/system/weeve-agent.service
ARGUMENTS_FILE=/lib/systemd/system/weeve-agent.argconf

if [ -d "$WEEVE_AGENT_DIRECTORY" ] || [ -f "$SERVICE_FILE" ] || [ -f "$ARGUMENTS_FILE" ]; then
  log Detected some weeve-agent contents!
  log Proceeding with the un-installation of the existing instance of weeve-agent ...
  cleanup
  log Continuing with the installation ...
else
  log No weeve-agent contents found, proceeding with the installation ...
fi

log Github Personal Access Token is required to continue!
log Follow the steps :
log - Create a file named '.weeve-agent-secret'
log - Paste the Token into the file

read -p "Give the absolute path to the file: " SECRET_FILE

# checking for the file containing access key
if [ -f "$SECRET_FILE" ];then
log Reading the access key ...
ACCESS_KEY=$(cat "$SECRET_FILE")
else
log File not found!!!
exit 0
fi

log Validating if docker is installed and running ...

# checking if docker is running
if RESULT=$(systemctl is-active docker 2>&1); then
  log Docker is running.
else
  log Docker is not running, is docker installed?
  log Returned by the command: "$RESULT"
  log To install docker, visit https://docs.docker.com/engine/install/
  exit 0
fi

log Creating directory ...
mkdir weeve-agent

log Detecting the architecture ...
ARCH=$(uname -m)
log Architecture is "$ARCH"

# detecting the architecture and downloading the respective weeve-agent binary
case "$ARCH" in
  "i386" | "i686") BINARY_NAME=weeve-agent-386
  ;;
  "x86_64") BINARY_NAME=weeve-agent-amd64
  ;;
  "arm" | "armv7l") BINARY_NAME=weeve-agent-arm
  ;;
  "aarch64" | "aarch64_be" | "armv8b" | "armv8l") BINARY_NAME=weeve-agent-arm64
  ;;
  *) log Architecture "$ARCH" is not supported !
  exit 0
  ;;
esac

if RESULT=$(cd ./weeve-agent \
&& curl -sO https://raw.githubusercontent.com/weeveiot/weeve-agent-binaries/master/"$BINARY_NAME" 2>&1); then
  log Executable downloaded.
  chmod u+x ./weeve-agent/"$BINARY_NAME"
  log Changes file permission
else
  log Error while downloading the executable !
  log Returned by the command: "$RESULT"
  exit 0
fi

log Downloading the dependencies ...

# downloading the dependencies with personal access key since its stored in private repository
for DEPENDENCIES in AmazonRootCA1.pem 1d77ae9afd-certificate.pem.crt 1d77ae9afd-private.pem.key nodeconfig.json weeve-agent.service weeve-agent.argconf
do
if RESULT=$(cd ./weeve-agent \
&& curl -sO https://"$ACCESS_KEY"@raw.githubusercontent.com/nithinsaii/weeve-agent-dependencies--demo/master/$DEPENDENCIES 2>&1); then
  log $DEPENDENCIES downloaded.
else
  log Error while downloading the dependencies !
  log Returned by the command: "$RESULT"
  rm -r weeve-agent
  exit 0
fi
done
log Dependencies downloaded.

# appending the argument for node name to weeve-agent.argconf
log Adding the node name argument ...
echo "ARG_NODENAME=--name $NODE_NAME" >> ./weeve-agent/weeve-agent.argconf

# appending the required strings to the .service to point systemd to the path of the binary
# following are the lines appended to weeve-agent.service
# WorkingDirectory=/home/nithin/weeve-agent
# ExecStart=/home/nithin/weeve-agent/weeve-agent-x86_64 $ARG_VERBOSE $ARG_BROKER $ARG_SUB_CLIENT $ARG_PUB_CLIENT $ARG_PUBLISH $ARG_HEARTBEAT $ARG_NODENAME

WORKING_DIRECTORY="WorkingDirectory=$CURRENT_DIRECTORY/weeve-agent"

BINARY_PATH="ExecStart=$CURRENT_DIRECTORY/weeve-agent/$BINARY_NAME "
ARGUMENTS='$ARG_VERBOSE $ARG_BROKER $ARG_SUB_CLIENT $ARG_PUB_CLIENT $ARG_PUBLISH $ARG_HEARTBEAT $ARG_NODENAME'
EXEC_START="$BINARY_PATH$ARGUMENTS"

log Adding the binary path to service file ...
echo "$WORKING_DIRECTORY" >> ./weeve-agent/weeve-agent.service
echo "$EXEC_START" >> ./weeve-agent/weeve-agent.service

log Starting the service ...

# moving .service and .argconf to systemd path and starting the service
if RESULT=$(sudo mv weeve-agent/weeve-agent.service /lib/systemd/system/ \
&& sudo mv weeve-agent/weeve-agent.argconf /lib/systemd/system/ \
&& sudo systemctl enable weeve-agent \
&& sudo systemctl start weeve-agent 2>&1); then
  log weeve-agent service should be up, you will be prompted once weeve-agent is connected.
else
  log Error while starting the weeve-agent service!
  log For good measure please check the access key in .weeve-agent-secret and also if the access key has expired in github
  log Returned by the command: "$RESULT"
  exit 0
fi

sleep 5

# parsing the weeve-agent log for heartbeat message to verify if the weeve-agent is connected
# on successful completion of the script $PROCESS_COMPLETE is set to true to skip the clean-up on exit
if RESULT=$(tail -f ./weeve-agent/Weeve_Agent.log | sed '/Sending update >> Topic/ q' 2>&1);then
  log weeve-agent is connected.
  log start deploying edge-applications through weeve-manager.
  PROCESS_COMPLETE=true
else
  log failed to start weeve-agent
  log Returned by the command: "$RESULT"
fi