# weeve-agent-installer

Bash script to download and run the weeve-agent.

# Developers - manually starting the weeve agent

1. Install docker [git@github.com:weeveiot/weeve-agent-installer.git](https://docs.docker.com/engine/install/ubuntu/)
2. Make a folder in the home folder `mkdir weeve-agent`
3. Copy the agent to the instance
   1. scp -i ~/.ssh/agent-testing.pem $LOCAL "ubuntu@18.216.187.87:/home/ubuntu/weeve-agent"
   2. Make it executable
4. Similarly, copy the configuration and bootstrap certificates to the instance, same folder
5. Set the node name `node_name=TestNodeMarch`
6. And add it to the configuration `echo "ARG_NODENAME=--name $node_name" >> ./weeve-agent/weeve-agent.argconf`
7. Run the agent manually `./weeve-agent-x86_64 -v --broker tls://asnhp33z3nubs-ats.iot.us-east-1.amazonaws.com:8883 --subClientId nodes/awsdev --pubClientId manager/awsdev --publish status --heartbeat 30 --name TestNodeMarch2022`

Upon first execution;
The weeve agent bootstraps.
The thing name will be the environment followed by the ID, for example; `awsdev_f5adbd1a-d4b7-4485-b5f4-2b901a92c80f`.
The certificate is created and uploaded to S3
# NOTE
It is possible to run multiple instances of the weeve agent in a single host. Each process would be running independently and be bootstrapped with as a dedicated IoT thing.

# NOTE
To delete the IoT thing, call the API mutation deleteNode. This will remove the;
- things in IoT core
- node and deployments in DB
- certs in bucket

# NOTE

(For registering with the script) The Github personal access key is required to download the contents for the agents. Please make sure the access key is stored in a file named ".weeve-agent-secret" in the same directory where the script is launched.

# RUN

```bash
curl -s https://raw.githubusercontent.com/weeveiot/weeve-agent-installer/<branch>/weeve-agent-installer.sh | sh -s NodeName=<name of the node>

```
