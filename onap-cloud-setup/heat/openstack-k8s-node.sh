#!/bin/bash

printenv

mkdir -p /opt/config
echo "__rancher_ip_addr__" > /opt/config/rancher_ip_addr.txt

HOST_IP=$(hostname -I)
echo $HOST_IP `hostname` >> /etc/hosts

DOCKER_VERSION=17.03.2
KUBECTL_VERSION=1.11.2
HELM_VERSION=2.9.1

# setup root access - default login: oom/oom - comment out to restrict access too ssh key only
sed -i 's/PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
service sshd restart
echo -e "oom\noom" | passwd root

apt-get update
curl https://releases.rancher.com/install-docker/$DOCKER_VERSION.sh | sh
mkdir -p /etc/systemd/system/docker.service.d/
cat > /etc/systemd/system/docker.service.d/docker.conf << EOF
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd -H fd:// --live-restore --insecure-registry=nexus3.onap.org:10001 --insecure-registry=10.254.188.33:4567
EOF
systemctl daemon-reload
systemctl restart docker
apt-mark hold docker-ce

IP_ADDY=`ip address |grep ens|grep inet|awk '{print $2}'| awk -F / '{print $1}'`
HOSTNAME=`hostname`

echo "$IP_ADDY $HOSTNAME" >> /etc/hosts

docker login -u docker -p docker nexus3.onap.org:10001

sudo apt-get install make -y

sudo curl -LO https://storage.googleapis.com/kubernetes-release/release/v$KUBECTL_VERSION/bin/linux/amd64/kubectl
sudo chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl
sudo mkdir ~/.kube
wget http://storage.googleapis.com/kubernetes-helm/helm-v${HELM_VERSION}-linux-amd64.tar.gz
sudo tar -zxvf helm-v${HELM_VERSION}-linux-amd64.tar.gz
sudo mv linux-amd64/helm /usr/local/bin/helm

# Fix virtual memory allocation for onap-log:elasticsearch:
echo "vm.max_map_count=262144" >> /etc/sysctl.conf
sysctl -p

sleep 100

# install nfs
apt-get -y install linux-image-extra-$(uname -r) jq nfs-common

# Configure NFS
mkdir -p /dockerdata-nfs
echo "__rancher_ip_addr__:/dockerdata-nfs /dockerdata-nfs nfs auto,nofail,noatime,nolock,intr,tcp,actimeo=1800 0 0" | tee -a /etc/fstab

while [ ! -e /dockerdata-nfs/rancher_agent_cmd.sh ]; do
    mount /dockerdata-nfs
    echo "Waiting for /dockerdata-nfs to be mounted.. and NFS cluster to be ready.."
    sleep 5
done

# Install Rancher Agent
cp /dockerdata-nfs/rancher_agent_cmd.sh .
sed -i "s/docker run/docker run -e CATTLE_AGENT_IP=${HOST_IP}/g" rancher_agent_cmd.sh
source rancher_agent_cmd.sh

exit 0
