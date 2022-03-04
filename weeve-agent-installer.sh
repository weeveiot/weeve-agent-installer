#!/bin/sh

logfile=installer.log

# logger
log() {
  echo '[' "$(date +"%Y-%m-%d %T")" ']:' INFO "$@" | tee -a $logfile
}

# function to clean-up the contents on failure at any point
# note that this function will be called even at successful ending of the script hence the condition check on variable
trap cleanup EXIT

cleanup() {
  if [ "$process_complete" = false ]; then
    log cleaning up the contents ...
    sudo systemctl stop weeve-agent
    sudo systemctl daemon-reload
    sudo rm /lib/systemd/system/weeve-agent.service
    sudo rm /lib/systemd/system/weeve-agent.argconf
    rm -r ./weeve-agent
  fi
}

process_complete=false

log Read command line arguments ...

key=$(echo "$@" | cut --fields 1 --delimiter='=')
value=$(echo "$@" | cut --fields 2 --delimiter='=')

if [ "$key" = NodeName ] ; then
  node_name="$value"
fi

if [ -z "$node_name" ]; then
log node_name is required. | Argument Name: NodeName
exit 0
fi

log All arguments are set
log Name of the node: "$node_name"

secret_file=.weeve-agent-secret

# checking for the file containing access key
if [ -f "$secret_file" ];then
log Reading the access key ...
access_key=$(cat "$secret_file")
else
log Please create and file named '.weeve-agent-secret' and append the access key of the github into the file!!!
exit 0
fi

log Validating if docker is installed and running ...

# checking if docker is running
if result=$(systemctl is-active docker 2>&1); then
  log Docker is running.
else
  log Docker is not running, is docker installed?
  log Returned by the command: "$result"
  exit 0
fi

log Creating directory ...
mkdir weeve-agent

log Detecting the architecture ...
arch=$(uname -m)
log Architecture is "$arch"

# detecting the architecture and downloading the respective weeve-agent binary
if [ "$arch" = x86_64 ] || [ "$arch" = aarch64 ]; then
  if result=$(cd ./weeve-agent \
  && curl -sO https://raw.githubusercontent.com/weeveiot/weeve-agent-binaries/master/weeve-agent-"$arch" 2>&1); then
    log Executable downloaded.
    chmod u+x ./weeve-agent/weeve-agent-"$arch"
    log Changes file permission
  else
    log Error while downloading the executable !
    log Returned by the command: "$result"
    exit 0
  fi
else
  log Architecture "$arch" is not supported !
  exit 0
fi

log Downloading the dependencies ...

# downloading the dependencies with personal access key since its stored in private repository
for dependency in AmazonRootCA1.pem 4be43aa6f1-certificate.pem.crt 4be43aa6f1-private.pem.key nodeconfig.json weeve-agent.service weeve-agent.argconf
do
if result=$(cd ./weeve-agent \
&& curl -sO https://"$access_key"@raw.githubusercontent.com/weeveiot/weeve-agent-dependencies/master/$dependency 2>&1); then
  log $dependency downloaded.
else
  log Error while downloading the dependencies !
  log Returned by the command: "$result"
  rm -r weeve-agent
  exit 0
fi
done
log Dependencies downloaded.

# appending the argument for node name to weeve-agent.argconf
log Adding the node name argument ...
echo "ARG_NODENAME=--name $node_name" >> ./weeve-agent/weeve-agent.argconf

# appending the required strings to the .service to point systemd to the path of the binary
# following are the lines appended to weeve-agent.service
# WorkingDirectory=/home/nithin/weeve-agent/weeve-agent
# ExecStart=/home/nithin/weeve-agent/weeve-agent/weeve-agent-x86_64 $ARG_VERBOSE $ARG_BROKER $ARG_SUB_CLIENT $ARG_PUB_CLIENT $ARG_PUBLISH $ARG_HEARTBEAT $ARG_NODENAME
binary_name="weeve-agent-$arch"
current_directory=$(pwd)

working_directory="WorkingDirectory=$current_directory/weeve-agent"

binary_path="ExecStart=$current_directory/weeve-agent/$binary_name "
arguments='$ARG_VERBOSE $ARG_BROKER $ARG_SUB_CLIENT $ARG_PUB_CLIENT $ARG_PUBLISH $ARG_HEARTBEAT $ARG_NODENAME'
exec_start="$binary_path$arguments"

log Adding the binary path to service file ...
echo "$working_directory" >> ./weeve-agent/weeve-agent.service
echo "$exec_start" >> ./weeve-agent/weeve-agent.service

log Starting the service ...

# moving .service and .argconf to systemd path and starting the service
if result=$(sudo mv weeve-agent/weeve-agent.service /lib/systemd/system/ \
&& sudo mv weeve-agent/weeve-agent.argconf /lib/systemd/system/ \
&& sudo systemctl enable weeve-agent \
&& sudo systemctl start weeve-agent 2>&1); then
  log weeve-agent service should be up, you will be prompted once weeve-agent is connected.
else
  log Error while starting the weeve-agent service!
  log For good measure please check the access key in .weeve-agent-secret and also if the access key has expired in github
  log Returned by the command: "$result"
  exit 0
fi

sleep 5

# parsing the weeve-agent log for heartbeat message to verify if the weeve-agent is connected
# on successful completion of the script $process_complete is set to true to skip the clean-up on exit
if result=$(tail -f ./weeve-agent/Weeve_Agent.log | sed '/Sending update >> Topic/ q' 2>&1);then
  log weeve-agent is connected.
  log start deploying edge-applications through weeve-manager.
  process_complete=true
else
  log failed to start weeve-agent
  log Returned by the command: "$result"
fi