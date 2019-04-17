#!/bin/bash

printenv

mkdir -p /opt/config
echo "__k8s_vm_ips__" > /opt/config/k8s_vm_ips.txt

DOCKER_VERSION=17.03.2
RANCHER_VERSION=1.6.25
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
ExecStart=/usr/bin/dockerd -H fd:// --insecure-registry=nexus3.onap.org:10001
EOF
systemctl daemon-reload
systemctl restart docker
apt-mark hold docker-ce

IP_ADDY=`ip address |grep ens|grep inet|awk '{print $2}'| awk -F / '{print $1}'`
HOSTNAME=`hostname`

echo "$IP_ADDY $HOSTNAME" >> /etc/hosts

docker login -u docker -p docker nexus3.onap.org:10001

sudo apt-get install make -y

sudo docker run -d --restart=unless-stopped -p 8080:8080 --name rancher_server rancher/server:v$RANCHER_VERSION
sudo curl -LO https://storage.googleapis.com/kubernetes-release/release/v$KUBECTL_VERSION/bin/linux/amd64/kubectl
sudo chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl
sudo mkdir ~/.kube

wget http://storage.googleapis.com/kubernetes-helm/helm-v${HELM_VERSION}-linux-amd64.tar.gz
sudo tar -zxvf helm-v${HELM_VERSION}-linux-amd64.tar.gz
sudo mv linux-amd64/helm /usr/local/bin/helm

# nfs server
sudo apt-get install nfs-kernel-server -y

sudo mkdir -p /nfs_share
sudo chown nobody:nogroup /nfs_share/

# configure NFS master

wget https://onap.readthedocs.io/en/beijing/_downloads/master_nfs_node.sh
chmod +x master_nfs_node.sh

ARGS=""
for K8S_VM_IP in $(tr -d ',[]' < /opt/config/k8s_vm_ips.txt); do
    ARGS+="$K8S_VM_IP "
done
echo $ARGS

sudo ./master_nfs_node.sh $ARGS

# Configure Rancher environment

sudo apt-get install jq --yes --force-yes

echo export RANCHER_IP=__rancher_private_ip_addr__ > api-keys-rc
source api-keys-rc

sleep 50
until curl -s -o projects.json -H "Accept: application/json" http://$RANCHER_IP:8080/v2-beta/projects; do
    sleep 10
done
OLD_PID=$(jq -r '.data[0].id' projects.json)

curl -s -H "Accept: application/json" -H "Content-Type: application/json" -d '{"accountId":"1a1"}' http://$RANCHER_IP:8080/v2-beta/apikeys > apikeys.json
echo export RANCHER_ACCESS_KEY=`jq -r '.publicValue' apikeys.json` >> api-keys-rc
echo export RANCHER_SECRET_KEY=`jq -r '.secretValue' apikeys.json` >> api-keys-rc
source api-keys-rc

curl -s -u "${RANCHER_ACCESS_KEY}:${RANCHER_SECRET_KEY}" -X DELETE -H 'Content-Type: application/json' "http://$RANCHER_IP:8080/v2-beta/projects/$OLD_PID"

until [ ! -z "$TEMPLATE_ID" ] && [ "$TEMPLATE_ID" != "null" ]; do
    sleep 5
    curl -s -H "Accept: application/json" http://$RANCHER_IP:8080/v2-beta/projectTemplates?name=Kubernetes > projectTemplatesKubernetes.json
    TEMPLATE_ID=$(jq -r '.data[0].id' projectTemplatesKubernetes.json)
done

curl -s -u "${RANCHER_ACCESS_KEY}:${RANCHER_SECRET_KEY}" -X POST -H 'Content-Type: application/json' -d '{ "name":"oom", "projectTemplateId":"'$TEMPLATE_ID'" }' "http://$RANCHER_IP:8080/v2-beta/projects" > project.json
PID=`jq -r '.id' project.json`
echo export RANCHER_URL=http://$RANCHER_IP:8080/v1/projects/$PID >> api-keys-rc
source api-keys-rc

until [ $(jq -r '.state' project.json) == "active" ]; do
    sleep 5
    curl -s -H "Accept: application/json" http://$RANCHER_IP:8080/v1/projects/$PID > project.json
done

TID=$(curl -s -X POST -H "Accept: application/json" -H "Content-Type: application/json" http://$RANCHER_IP:8080/v1/projects/$PID/registrationTokens | jq -r '.id')
touch token.json
while [ $(jq -r .command token.json | wc -c) -lt 10 ]; do
    sleep 5
    curl -s -X GET -H "Accept: application/json" http://$RANCHER_IP:8080/v1/projects/$PID/registrationToken/$TID > token.json
done
jq -r .command token.json > rancher_agent_cmd.sh
chmod +x rancher_agent_cmd.sh

# Distribute data to NFS slaves
cp rancher_agent_cmd.sh /dockerdata-nfs

# Configure kubectl locally
KUBETOKEN=$(echo -n 'Basic '$(echo -n "$RANCHER_ACCESS_KEY:$RANCHER_SECRET_KEY" | base64 -w 0) | base64 -w 0)

# create .kube/config
cat > ~/.kube/config <<EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    api-version: v1
    insecure-skip-tls-verify: true
    server: "https://__rancher_ip_addr__:8080/r/projects/$PID/kubernetes:6443"
  name: "oom"
contexts:
- context:
    cluster: "oom"
    user: "oom"
  name: "oom"
current-context: "oom"
users:
- name: "oom"
  user:
    token: "$KUBETOKEN"
EOF

export KUBECONFIG=/root/.kube/config
kubectl config view

# wait for kubernetes to initialze
sleep 100
until [ $(kubectl get pods --namespace kube-system | tail -n +2 | grep -c Running) -ge 6 ]; do
    sleep 10
done

exit 0
