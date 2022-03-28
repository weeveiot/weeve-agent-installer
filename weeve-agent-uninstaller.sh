sudo systemctl stop weeve-agent
sudo systemctl daemon-reload
sudo rm /lib/systemd/system/weeve-agent.service
sudo rm /lib/systemd/system/weeve-agent.argconf
sudo rm -r weeve-agent