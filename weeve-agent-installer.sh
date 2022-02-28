#!/bin/sh

log=installer.log

sh write-log.sh "Read command line arguments ..." | tee -a $log

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
sh write-log.sh "node_name is required. | Argument Name: NodeName" | tee -a $log
exit 0
fi

sh write-log.sh "All arguments are set" | tee -a $log
sh write-log.sh "Name of the node: $node_name" | tee -a $log


sh write-log.sh "Validating if docker is installed and running ..." | tee -a $log

if result=$(systemctl is-active docker 2>&1); then
  sh write-log.sh "Docker is running." | tee -a $log
else
  sh write-log.sh "Returned by the command: $result" | tee -a $log
  sh write-log.sh "Docker is not running, is docker installed?" | tee -a $log
  exit 0
fi

sh write-log.sh "Creating directory ..." | tee -a $log
mkdir weeve-agent

sh write-log.sh "Detecting the architecture ..." | tee -a $log
arch=$(uname -m)
sh write-log.sh "Architecture is $arch" | tee -a $log

if [ "$arch" = x86_64 -o "$arch" = aarch64 ]; then
  if result=$(cd ./weeve-agent \
  && curl -sO https://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@raw.githubusercontent.com/nithinsaii/to_transfer/master/binaries/weeve-agent-$arch 2>&1); then
    sh write-log.sh "Executable downloaded." | tee -a $log
    chmod u+x ./weeve-agent/weeve-agent-$arch
    sh write-log.sh "Changes file permission" | tee -a $log
  else
    sh write-log.sh "Returned by the command: $result" | tee -a $log
    sh write-log.sh "Error while downloading the executable !" | tee -a $log
    sudo rm -r weeve-agent
    exit 0
  fi
else
  sh write-log.sh "Architecture $arch is not supported !" | tee -a $log
  sudo rm -r weeve-agent
  exit 0
fi

sh write-log.sh "Downloading the dependencies ..." | tee -a $log

for dependency in AmazonRootCA1.pem 4be43aa6f1-certificate.pem.crt 4be43aa6f1-private.pem.key nodeconfig.json weeve-agent.service weeve-agent.argconf
do
if result=$(cd ./weeve-agent \
&& curl -sO https://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@raw.githubusercontent.com/nithinsaii/to_transfer/master/weeve-agent/$dependency 2>&1); then
  sh write-log.sh "$dependency downloaded." | tee -a $log
else
  sh write-log.sh "Returned by the command: $result" | tee -a $log
  sh write-log.sh "Error while downloading the dependencies !" | tee -a $log
  rm -r weeve-agent
  exit 0
fi
done
sh write-log.sh "Dependencies downloaded." | tee -a $log

sh write-log.sh "Adding the node name argument ..." | tee -a $log
echo "ARG_NODENAME=--name $node_name" >> ./weeve-agent/weeve-agent.argconf

binary_name="weeve-agent-$arch"
current_directory=$(pwd)

working_directory="WorkingDirectory=$current_directory/weeve-agent"

binary_path="ExecStart=$current_directory/weeve-agent/$binary_name "
arguments='$ARG_VERBOSE $ARG_BROKER $ARG_SUB_CLIENT $ARG_PUB_CLIENT $ARG_PUBLISH $ARG_HEARTBEAT $ARG_NODENAME'
exec_start="$binary_path$arguments"

sh write-log.sh "Adding the binary path to service file ..." | tee -a $log
echo "$working_directory" >> ./weeve-agent/weeve-agent.service
echo "$exec_start" >> ./weeve-agent/weeve-agent.service
sh write-log.sh "Starting the service ..." | tee -a $log

if result=$(sudo mv weeve-agent/weeve-agent.service /lib/systemd/system/ \
&& sudo mv weeve-agent/weeve-agent.argconf /lib/systemd/system/ \
&& sudo systemctl enable weeve-agent \
&& sudo systemctl start weeve-agent 2>&1); then
  sh write-log.sh "weeve-agent service is up, you will be prompted once weeve-agent is connected." | tee -a $log
  # sleep 20
  # log_content=$(cat ./weeve-agent/Weeve_Agent.log)
  # sub="Sending update >> Topic"
  # if [[ "$log_content" == *$sub* ]];then
  #   sh write-log.sh "weeve-agent is connected." | tee -a $log
  # fi
else
  sh write-log.sh "Returned by the command: $result" | tee -a $log
  sh write-log.sh "Error while starting the weeve-agent service!" | tee -a $log
  sudo systemctl stop weeve-agent
  sudo systemctl daemon-reload
  sudo rm /lib/systemd/system/weeve-agent.service
  sudo rm /lib/systemd/system/weeve-agent.argconf
  sudo rm -r weeve-agent
  exit 0
fi