#!/bin/sh

DEBIAN="Debian"
RASPBIAN="Raspbian"
UBUNTU="Ubuntu"
FEDORA="fedora"
CENTOS="centos"

if [ -f /etc/fedora-release ]
then
DISTRO="fedora"
elif [ -f /etc/centos-release ] || [ -f /etc/redhat-release ]
then
DISTRO="centos"
elif [ -f /etc/os-release ]
then
    STRING=$(cat /etc/issue)
    case $STRING in
        *"$DEBIAN"*)
        DISTRO="debian"
        ;;
        *"$RASPBIAN"*)
        DISTRO="debian"
        ;;
        *"$UBUNTU"*)
        DISTRO="ubuntu"
        ;;
    esac
fi

echo "The distribution is $DISTRO"

if [ "$DISTRO" = "$FEDORA" ] || [ "$DISTRO" = "$CENTOS" ]
then
    package_manager="dnf"
    # utils="dnf-plugins-core"
    # cmddiff=" config-manager"
else
    package_manager="apt-get"
fi
echo "The package manager for $DISTRO is $package_manager"

# .rpm
# DISTRO= rhel/centos/fedora
# package_manager= yum/dnf
# utils= yum-utils/dnf-plugins-core
if [ "$DISTRO" = "$CENTOS" ] || [ "$DISTRO" = "$FEDORA" ]
then
sudo "$package_manager" remove docker \
    docker-client \
    docker-client-latest \
    docker-common \
    docker-latest \
    docker-latest-logrotate \
    docker-logrotate \
    docker-engine \
    podman \
    runc \
    docker-selinux \
    docker-engine-selinux \
    docker-engine
sudo "$package_manager" install -y dnf-plugins-core
sudo "$package_manager" config-manager --add-repo https://download.docker.com/linux/"$DISTRO"/docker-ce.repo
sudo "$package_manager" install docker-ce docker-ce-cli containerd.io
sudo systemctl start docker
sudo docker run hello-world

#.deb
# DISTRO= debian/raspbian/ubuntu
else
sudo apt-get remove docker docker-engine docker.io containerd runc -y
sudo apt-get update
sudo apt-get install \
    ca-certificates \
    curl \
    gnupg \
    lsb-release -y
curl -fsSL https://download.docker.com/linux/"$DISTRO"/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/$DISTRO \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -y
sudo apt-get install docker-ce docker-ce-cli containerd.io -y
sudo docker run hello-world
fi
echo "Adding user to docker group"
sudo groupadd docker
sudo usermod -aG docker "$USER"
newgrp docker