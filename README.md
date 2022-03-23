# weeve-agent-installer

Bash script to download and run the weeve-agent.

# REQUIREMENT TO RUN THE SCRIPT

(For registering with the script) The Github personal access key is required to download the contents for the agents. Please make sure the access key is stored in a file named ".weeve-agent-secret" in the same directory where the script is launched.

# RUN

```bash
curl -s https://raw.githubusercontent.com/weeveiot/weeve-agent-installer/<branch>/weeve-agent-installer.sh | sh -s NodeName=<name of the node>

```

# Developers - manually starting the weeve agent

1. Install docker [docker installation for ubuntu](https://docs.docker.com/engine/install/ubuntu/)
2. Make a folder in the home folder `mkdir weeve-agent`
3. Copy the agent to the instance
   1. scp -i ~/.ssh/agent-testing.pem <path-to-agent-binary> "ubuntu@<ip>:/home/ubuntu/weeve-agent"
   2. Make it executable `chmod u+x weeve-agent/<agent-binary-name>`
4. Similarly, copy the configuration and bootstrap certificates to the instance, same folder
5. To run the agent in the foreground `./weeve-agent/<agent-binary-name> -v --broker tls://asnhp33z3nubs-ats.iot.us-east-1.amazonaws.com:8883 --subClientId nodes/awsdev --pubClientId manager/awsdev --publish status --heartbeat 30 --name <name-of-the-node>`
6. To run the agent as systemd service
   1. Add it to the configuration `echo "ARG_NODENAME=--name <name-of-the-node>" >> ./weeve-agent/weeve-agent.argconf`
   2. Add the following to weeve-agent.service
      1. `echo "WorkingDirectory=/home/ubuntu/weeve-agent" >> ./weeve-agent/weeve-agent.service`
      2. `echo "ExecStart=/home/ubuntu/weeve-agent/<agent-binary-name> $ARG_VERBOSE $ARG_BROKER $ARG_SUB_CLIENT $ARG_PUB_CLIENT $ARG_PUBLISH $ARG_HEARTBEAT $ARG_NODENAME" >> ./weeve-agent/weeve-agent.service`
   3. Move weeve-agent.service `sudo mv weeve-agent/weeve-agent.service /lib/systemd/system/`
   4. Move weeve-agent.argconf `sudo mv weeve-agent/weeve-agent.argconf /lib/systemd/system/`
   5. Enable the service to start at start-up `sudo systemctl enable weeve-agent`
   6. Start the service `sudo systemctl start weeve-agent`

Upon first execution;
The weeve agent bootstraps.
The thing name will be the environment followed by the ID, for example; `awsdev_f5adbd1a-d4b7-4485-b5f4-2b901a92c80f`.
The certificate is created and uploaded to S3

# NOTE

It is possible to run multiple instances of the weeve agent in a single host. Each process would be running independently and be bootstrapped with as a dedicated IoT thing.

# DELETING A NODE

To delete the IoT thing, call the API mutation deleteNode. This will remove the:

- things in IoT core
- node and deployments in DB
- certs in bucket
