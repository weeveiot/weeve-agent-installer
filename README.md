# weeve-agent-installer

Bash script to download and run the weeve-agent.

# NOTE

Personal access token is required to download the contents for the agents.
Please make sure to create a file named ".weeve-agent-secret" in the same directory where the script is launched and append the token to the file.

# RUN

```bash
curl -s https://raw.githubusercontent.com/weeveiot/weeve-agent-installer/dev/weeve-agent-installer.sh | sh -s NodeName=<name of the node>

```
