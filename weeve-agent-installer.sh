#!/bin/sh

set -o pipefail

logfile=installer.log

log() {
        echo '[' `date +"%Y-%m-%d %T"` ']:' INFO "$@" | tee -a $logfile
}

trap cleanup EXIT

cleanup() {
  if [ "$process_complete" = false ]; then
    $(sudo systemctl stop weeve-agent
      sudo systemctl daemon-reload
      sudo rm /lib/systemd/system/weeve-agent.service
      sudo rm /lib/systemd/system/weeve-agent.argconf
      sudo rm -r ./weeve-agent)
  fi
}

process_complete=false

log Read command line arguments ...

for argument in "$@"
do
  key=$(echo $argument | cut --fields 1 --delimiter='=')
  value=$(echo $argument | cut --fields 2 --delimiter='=')

  case "$key" in
    "NodeName")  node_name="$value" ;;
    *)
  esac
  #  echo "Key: $key | Value: $value"
done

if [ -z "$node_name" ]; then
log node_name is required. | Argument Name: NodeName
exit 0
fi

log All arguments are set
log Name of the node: $node_name


log Validating if docker is installed and running ...

if result=$(systemctl is-active docker 2>&1); then
  log Docker is running.
else
  log Docker is not running, is docker installed?
  log Returned by the command: $result
  exit 0
fi

log Creating directory ...
mkdir weeve-agent

log Detecting the architecture ...
arch=$(uname -m)
log Architecture is $arch

if [ "$arch" = x86_64 -o "$arch" = aarch64 ]; then
  if result=$(cd ./weeve-agent \
  && curl -sO https://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@raw.githubusercontent.com/nithinsaii/to_transfer/master/binaries/weeve-agent-$arch 2>&1); then
    log Executable downloaded.
    chmod u+x ./weeve-agent/weeve-agent-$arch
    log Changes file permission
  else
    log Error while downloading the executable !
    log Returned by the command: $result
    exit 0
  fi
else
  log Architecture $arch is not supported !
  exit 0
fi

log Downloading the dependencies ...

for dependency in AmazonRootCA1.pem 4be43aa6f1-certificate.pem.crt 4be43aa6f1-private.pem.key nodeconfig.json weeve-agent.service weeve-agent.argconf
do
if result=$(cd ./weeve-agent \
&& curl -sO https://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@raw.githubusercontent.com/nithinsaii/to_transfer/master/weeve-agent/$dependency 2>&1); then
  log $dependency downloaded.
else
  log Error while downloading the dependencies !
  log Returned by the command: $result
  rm -r weeve-agent
  exit 0
fi
done
log Dependencies downloaded.

log Adding the node name argument ...
echo "ARG_NODENAME=--name $node_name" >> ./weeve-agent/weeve-agent.argconf

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

if result=$(sudo mv weeve-agent/weeve-agent.service /lib/systemd/system/ \
&& sudo mv weeve-agent/weeve-agent.argconf /lib/systemd/system/ \
&& sudo systemctl enable weeve-agent \
&& sudo systemctl start weeve-agent 2>&1); then
  log weeve-agent service should be up, you will be prompted once weeve-agent is connected.
else
  log Error while starting the weeve-agent service!
  log Returned by the command: $result
  exit 0
fi

sleep 5
if result=$(tail -f ./weeve-agent/Weeve_Agent.log | sed '/Sending update >> Topic/ q' 2>&1);then
  log failed to start weeve-agent
  log Returned by the command: $result
else
  log weeve-agent is connected.
  log start deploying edge-application through weeve-manager.
  process_complete=true
fi