# weeve-agent-installer

Bash script to download and run the weeve-agent.

# Quickstart for developers

1. Install docker [git@github.com:weeveiot/weeve-agent-installer.git](https://docs.docker.com/engine/install/ubuntu/)
   1.
2. mkdir weeve-agent
3. Copy the agent to the instance
   1. scp -i ~/.ssh/agent-testing.pem $LOCAL "ubuntu@18.216.187.87:/home/ubuntu"
   2. Make it executable
4. Copy the dependencies to the instance
5. Set the node name `node_name=TestNodeMarch`
6. And add it to the configuration `echo "ARG_NODENAME=--name $node_name" >> ./weeve-agent/weeve-agent.argconf`
7. Run the agent manually `./weeve-agent-x86_64 -v --broker tls://asnhp33z3nubs-ats.iot.us-east-1.amazonaws.com:8883 --subClientId nodes/awsdev --pubClientId manager/awsdev --publish status --heartbeat 30 --name TestNodeMarch2022`


# NOTE

It is possible to run multiple instances of the weeve agent. They would be

# NOTE

Personal access key is required to download the contents for the agents.
Please make sure the access key is stored in a file named ".weeve-agent-secret" in the same directory where the script is launched.

# RUN

```bash
curl -s https://raw.githubusercontent.com/weeveiot/weeve-agent-installer/<branch>/weeve-agent-installer.sh | sh -s NodeName=<name of the node>

```
