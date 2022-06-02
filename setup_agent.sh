#!/bin/bash

AGENT_HOSTNAME=$1

ARCH=arm
CNI_VERSION="1.1.1"

echo "Clearing out k3s..."
ssh $AGENT_HOSTNAME '[ -f /usr/local/bin/k3s-agent-uninstall.sh ] && k3s-uninstall.sh'


# TODO
#if [[ ! -x /opt/cni/bin/host-local ]] || [[ $(/opt/cni/bin/host-local -v) == "CNI host-local plugin v$CNI_VERSION" ]]; then
#	echo "Installing CNI plugins..."
#	mkdir -p /opt/cni/bin
#	curl -sL "https://github.com/containernetworking/plugins/releases/download/v$CNI_VERSION/cni-plugins-linux-$ARCH-v$CNI_VERSION.tgz" | tar xvz -C /opt/cni/bin
#fi

echo "Installing k3s..."
K3S_TOKEN=$(sudo cat /var/lib/rancher/k3s/server/node-token)
ssh $AGENT_HOSTNAME "curl -sfL https://get.k3s.io | K3S_URL=https://$(hostname):6443 K3S_TOKEN=${K3S_TOKEN} sh -"

echo "Attempting to get podCIDR for node $AGENT_HOSTNAME..."
POD_CIDR=$(kubectl get node $AGENT_HOSTNAME -o=jsonpath={.spec.podCIDR})
while [[ $POD_CIDR == "" ]]; do
	echo "Trying again in 2 sec"
	sleep 2
	POD_CIDR=$(kubectl get node $AGENT_HOSTNAME -o=jsonpath={.spec.podCIDR})
done
echo " -> $POD_CIDR"

echo "Writing CNI config..."
ssh $AGENT_HOSTNAME "sed 's!__POD_CIDR__!$POD_CIDR!g' 10-cni.conflist.template > /tmp/cni.conflist"
ssh $AGENT_HOSTNAME 'sudo mv /tmp/cni.conflist /etc/cni/net.d/10-cni.conflist'

echo "Configuring frr..."
ssh $AGENT_HOSTNAME "sed 's!__POD_CIDR__!$POD_CIDR!g' frr.conf.template > /tmp/frr.conf"
ssh $AGENT_HOSTNAME 'sudo mv /tmp/frr.conf /etc/frr/frr.conf'

ssh $AGENT_HOSTNAME 'sudo sed "s/ripd=no/ripd=yes/g" /etc/frr/daemons > /tmp/daemons'
ssh $AGENT_HOSTNAME 'sudo mv /tmp/daemons /etc/frr/daemons'

ssh $AGENT_HOSTNAME 'sudo service frr restart'

kubectl describe no $AGENT_HOSTNAME