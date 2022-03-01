# weeve-agent-installer

Bash script to download and run the weeve-agent.

# NOTE

Personal access key is required to download the contents for the agents.
Please make sure the access key is stored in a file named ".weeve-agent-secret" in the same directory where the script is launched.

# RUN

```bash
curl -s https://raw.githubusercontent.com/weeveiot/weeve-agent-installer/<branch>/weeve-agent-installer.sh | bash -s NodeName=<name of the node>

```
