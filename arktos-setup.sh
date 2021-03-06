#!/bin/bash

####################

echo Setup: Install go \(currently limited to version 1.13.9\)

sudo apt-get update -y && sudo apt-get dist-upgrade -y
sudo apt-get install build-essential -y -q

cd /tmp
wget https://dl.google.com/go/go1.13.9.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.13.9.linux-amd64.tar.gz
rm -rf go1.13.9.linux-amd64.tar.gz

####################

echo Setup: Install bazel

sudo apt install g++ unzip zip -y -q
sudo apt-get install openjdk-8-jdk -y -q
cd /tmp
wget https://github.com/bazelbuild/bazel/releases/download/0.26.1/bazel-0.26.1-installer-linux-x86_64.sh
chmod +x bazel-0.26.1-installer-linux-x86_64.sh
./bazel-0.26.1-installer-linux-x86_64.sh --user

####################

echo Setup: Enlist arktos

cd ~
git clone https://github.com/CentaurusInfra/arktos.git ~/go/src/k8s.io/arktos
cd ~/go/src/k8s.io
ln -s ./arktos kubernetes

git config --global credential.helper 'cache --timeout=3600000'

####################

echo Setup: Install etcd

cd ~/go/src/k8s.io/arktos/
git tag v1.15.0
./hack/install-etcd.sh

####################

echo Setup: Install Docker

sudo apt-get update -y -q
sudo apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common -y -q
    
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo apt-key fingerprint 0EBFCD88
sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
   
sudo apt-get update -y -q
sudo apt-get install docker-ce docker-ce-cli containerd.io -y -q
sudo gpasswd -a $USER docker

####################

echo Setup: Install crictl

cd /tmp
wget https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.17.0/crictl-v1.17.0-linux-amd64.tar.gz
sudo tar -zxvf crictl-v1.17.0-linux-amd64.tar.gz -C /usr/local/bin
rm -f crictl-v1.17.0-linux-amd64.tar.gz

touch /tmp/crictl.yaml
echo runtime-endpoint: unix:///run/containerd/containerd.sock >> /tmp/crictl.yaml
echo image-endpoint: unix:///run/containerd/containerd.sock >> /tmp/crictl.yaml
echo timeout: 10 >> /tmp/crictl.yaml
echo debug: true >> /tmp/crictl.yaml
sudo mv /tmp/crictl.yaml /etc/crictl.yaml

sudo mkdir -p /etc/containerd
sudo rm -rf /etc/containerd/config.toml
sudo containerd config default > /tmp/config.toml
sudo mv /tmp/config.toml /etc/containerd/config.toml
sudo systemctl restart containerd

####################

echo Setup: Install miscellaneous

sudo apt install awscli -y -q
sudo apt install jq -y -q

####################

echo Setup: Install Containerd

cd $HOME
wget https://github.com/containerd/containerd/releases/download/v1.4.2/containerd-1.4.2-linux-amd64.tar.gz
cd /usr
sudo tar -xvf $HOME/containerd-1.4.2-linux-amd64.tar.gz
sudo rm -rf $HOME/containerd-1.4.2-linux-amd64.tar.gz

echo Setup: Replace Containerd

cd $HOME/go/src/k8s.io/arktos
wget -qO- https://github.com/CentaurusInfra/containerd/releases/download/tenant-cni-args/containerd.zip | zcat > /tmp/containerd
sudo chmod +x /tmp/containerd
sudo systemctl stop containerd
sudo mv /usr/bin/containerd /usr/bin/containerd.bak
sudo mv /tmp/containerd /usr/bin/
sudo systemctl restart containerd
sudo systemctl restart docker

####################

echo Setup: Setup profile

echo PATH=\"\$HOME/go/src/k8s.io/arktos/third_party/etcd:/usr/local/go/bin:\$HOME/go/bin:\$HOME/go/src/k8s.io/arktos/_output/bin:\$HOME/go/src/k8s.io/arktos/_output/dockerized/bin/linux/amd64:\$PATH\" >> ~/.profile
echo GOPATH=\"\$HOME/go\" >> ~/.profile
echo GOROOT=\"/usr/local/go\" >> ~/.profile
echo >> ~/.profile
echo alias kubectl=\'$HOME/go/src/k8s.io/arktos/cluster/kubectl.sh\'  >> ~/.profile
source "$HOME/.profile"

####################

echo Setup: Basic

cd ~/go/src/k8s.io/arktos/
make all WHAT=cmd/arktos-network-controller

sudo systemctl stop ufw
sudo systemctl disable ufw
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
sudo partprobe
sudo echo "vm.swappiness=0" | sudo tee --append /etc/sysctl.conf
sudo sysctl -p
IP_ADDR=$(hostname -I | awk '{print $1}')
HOSTNAME=$(hostname)
sudo sed -i '2s/.*/'$IP_ADDR' '$HOSTNAME'/' /etc/hosts
sudo rm -f /etc/resolv.conf
sudo ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf

#####################

sudo apt autoremove -y

echo Setup: Machine setup completed!

sudo reboot
