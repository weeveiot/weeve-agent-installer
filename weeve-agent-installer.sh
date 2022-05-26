#!/bin/sh

LOG_FILE=installer.log

# logger
log() {
  echo '[' "$(date +"%Y-%m-%d %T")" ']:' INFO "$@" | tee -a "$LOG_FILE"
}

# function to clean-up the contents on failure at any point
# note that this function will be called even at successful ending of the script hence the condition check on variable
trap cleanup EXIT

# if in case the user have deleted the weeve-agent.service and did not reload the systemd daemon
systemctl daemon-reload

CURRENT_DIRECTORY=$(pwd)
WEEVE_AGENT_DIRECTORY="$CURRENT_DIRECTORY"/weeve-agent

SERVICE_FILE=/lib/systemd/system/weeve-agent.service

ARGUMENTS_FILE=/lib/systemd/system/weeve-agent.argconf

CLEANUP="true"

cleanup() {
  if [ "$CLEANUP" = "true" ]; then

    log cleaning up the contents ...

    if RESULT=$(systemctl is-active weeve-agent 2>&1); then
    systemctl stop weeve-agent
    systemctl daemon-reload
    log weeve-agent service stopped
    else
    log weeve-agent service not running
    fi

    if [ -f "$SERVICE_FILE" ]; then
    rm "$SERVICE_FILE"
    log "$SERVICE_FILE" removed
    else
    log "$SERVICE_FILE" doesnt exists
    fi

    if [ -f "$ARGUMENTS_FILE" ]; then
    rm "$ARGUMENTS_FILE"
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

  fi
}

log Read command line arguments ...

for ARGUMENT in "$@"
do
  KEY=$(echo "$ARGUMENT" | cut --fields 1 --delimiter='=')
  VALUE=$(echo "$ARGUMENT" | cut --fields 2 --delimiter='=')

  case "$KEY" in
    "token") TOKEN_FILE="$VALUE" ;;
    "environment") ENV="$VALUE" ;;
    "nodename")  NODE_NAME="$VALUE" ;;
    *)
  esac
done

# validating the arguments
if [ -z "$TOKEN_FILE" ]; then
log Missing argument! | argument name: token
log -----------------------------------------------------------------------
log If you already do not have .weeve-agent-secret file with the token
log Follow the steps :
log 1. Create a file named .weeve-agent-secret
log 2. Paste the Github Personal Access Token into the above mentioned file
log For more info checkout the README 
log ------------------------------------------------------------------------
CLEANUP="false"
exit 0
fi

# looking for the file containing the github access token
if [ -f "$TOKEN_FILE" ];then
log Reading the access key ...
ACCESS_KEY=$(cat "$TOKEN_FILE")
else
log .weeve-agent-secret not found in the given path!!!
exit 0
fi

if [ -z "$ENV" ]; then
read -r -p "Which environment do you want the node to be registered on: " ENV
fi

if [ -z "$NODE_NAME" ]; then
read -r -p "Give a node name: " NODE_NAME
fi

log All arguments are set
log Environment is set to "$ENV"
log Name of the node is set to "$NODE_NAME"

# checking for existing agent instance
if [ -d "$WEEVE_AGENT_DIRECTORY" ] || [ -f "$SERVICE_FILE" ] || [ -f "$ARGUMENTS_FILE" ]; then
  log Detected some weeve-agent contents!
  read -r -p "Proceeding with the installation will cause REMOVAL of the existing contents of weeve-agent! Do you want to proceed? y/n: " RESPONSE
  if [ "$RESPONSE" = "y" ] || [ "$RESPONSE" = "yes" ]; then
  log Proceeding with the removal of existing weeve-agent contents ...
  cleanup
  else
  log exiting ...
  CLEANUP="false"
  exit 0
  fi
fi

# checking if docker is running
log Validating if docker is installed and running ...

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
  log Changed file permission
else
  log Error while downloading the executable !
  log Returned by the command: "$RESULT"
  exit 0
fi

log Downloading the dependencies ...

# downloading the dependencies with personal access key since its stored in private repository
for DEPENDENCIES in AmazonRootCA1.pem aws"$ENV"-certificate.pem.crt aws"$ENV"-private.pem.key nodeconfig.json weeve-agent.service weeve-agent.argconf
do
if RESULT=$(cd ./weeve-agent \
&& curl -sO https://"$ACCESS_KEY"@raw.githubusercontent.com/weeveiot/weeve-agent-dependencies/master/$DEPENDENCIES 2>&1); then
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
printf "ARG_SUB_CLIENT=--subClientId nodes/aws%s\n" "$ENV" >> ./weeve-agent/weeve-agent.argconf
printf "ARG_PUB_CLIENT=--pubClientId manager/aws%s\n" "$ENV" >> ./weeve-agent/weeve-agent.argconf
printf "ARG_ROOT_CERT=--rootcert AmazonRootCA1.pem\n" >> ./weeve-agent/weeve-agent.argconf
printf "ARG_CERT=--cert aws%s-certificate.pem.crt\n" "$ENV" >> ./weeve-agent/weeve-agent.argconf
printf "ARG_KEY=--key aws%s-private.pem.key\n" "$ENV" >> ./weeve-agent/weeve-agent.argconf
printf "ARG_NODENAME=--name %s" "$NODE_NAME" >> ./weeve-agent/weeve-agent.argconf

# appending the required strings to the .service to point systemd to the path of the binary
# following are the lines appended to weeve-agent.service
# WorkingDirectory=/home/admin/weeve-agent
# ExecStart=/home/admin/weeve-agent/weeve-agent-x86_64 $ARG_VERBOSE $ARG_BROKER $ARG_SUB_CLIENT $ARG_PUB_CLIENT $ARG_PUBLISH $ARG_HEARTBEAT $ARG_NODENAME

WORKING_DIRECTORY="WorkingDirectory=$CURRENT_DIRECTORY/weeve-agent"

BINARY_PATH="ExecStart=$CURRENT_DIRECTORY/weeve-agent/$BINARY_NAME "
ARGUMENTS='$ARG_VERBOSE $ARG_HEARTBEAT $ARG_BROKER $ARG_PUBLISH $ARG_SUB_CLIENT $ARG_PUB_CLIENT $ARG_ROOT_CERT $ARG_CERT $ARG_KEY $ARG_NODENAME'
EXEC_START="$BINARY_PATH$ARGUMENTS"

log Adding the binary path to service file ...
echo "$WORKING_DIRECTORY" >> ./weeve-agent/weeve-agent.service
echo "$EXEC_START" >> ./weeve-agent/weeve-agent.service

log Starting the service ...

# moving .service and .argconf to systemd path and starting the service
if RESULT=$(mv weeve-agent/weeve-agent.service /lib/systemd/system/ \
&& mv weeve-agent/weeve-agent.argconf /lib/systemd/system/ \
&& systemctl enable weeve-agent \
&& systemctl start weeve-agent 2>&1); then
  log weeve-agent service should be up, you will be prompted once weeve-agent is connected.
else
  log Error while starting the weeve-agent service!
  log For good measure please check the access key in .weeve-agent-secret and also if the access key has expired in github
  log Returned by the command: "$RESULT"
  exit 0
fi

sleep 5

# parsing the weeve-agent log for heartbeat message to verify if the weeve-agent is connected
# on successful completion of the script $CLEANUP is set to false to skip the clean-up on exit
if RESULT=$(tail -f ./weeve-agent/Weeve_Agent.log | sed '/ON connect >> connected >> registered : true/ q' 2>&1);then
  log weeve-agent is connected.
  log start deploying edge-applications through weeve-manager.
  CLEANUP="false"
else
  log failed to start weeve-agent
  log Returned by the command: "$RESULT"
fi