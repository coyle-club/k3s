#!/bin/bash

ARCH=$(dpkg --print-architecture)
CNI_VERSION="1.1.1"

if [[ -f /usr/local/bin/k3s-uninstall.sh ]]; then
	echo "Uninstalling k3s..."
	k3s-uninstall.sh
fi

if [[ ! -x /opt/cni/bin/host-local ]] || [[ $(/opt/cni/bin/host-local -v) == "CNI host-local plugin v$CNI_VERSION" ]]; then
	echo "Installing CNI plugins..."
	mkdir -p /opt/cni/bin
	curl -sL "https://github.com/containernetworking/plugins/releases/download/v$CNI_VERSION/cni-plugins-linux-$ARCH-v$CNI_VERSION.tgz" | tar xvz -C /opt/cni/bin
fi

echo "Installing k3s..."
curl -sfL https://get.k3s.io | INSTALL_K3S_SKIP_START=true sh - $@

echo "Writing k3s config..."
mkdir -p /etc/rancher/k3s
cp config.yaml /etc/rancher/k3s/

echo "Starting k3s..."
service k3s start


NODE_NAME=$(hostname)
echo "Attempting to get podCIDR for node $NODE_NAME..."
POD_CIDR=$(kubectl get node $NODE_NAME -o=jsonpath={.spec.podCIDR})
while [[ $POD_CIDR == "" ]]; do
	echo "Trying again in 2 sec"
	sleep 2
	POD_CIDR=$(kubectl get node $NODE_NAME -o=jsonpath={.spec.podCIDR})
done
echo " -> $POD_CIDR"

echo "Writing CNI config..."
sed "s!__POD_CIDR__!$POD_CIDR!g" 10-cni.conflist.template > /tmp/cni.conflist
mv /tmp/cni.conflist /etc/cni/net.d/10-cni.conflist

echo "Configuring frr..."
sed "s!__POD_CIDR__!$POD_CIDR!g" frr.conf.template > /tmp/frr.conf
mv /tmp/frr.conf /etc/frr/frr.conf

sed "s/ripd=no/ripd=yes/g" /etc/frr/daemons > /tmp/daemons
mv /tmp/daemons /etc/frr/daemons

service frr restart

echo "Setting up cert-manager..."
kubectl create namespace cert-manager

kubectl apply -f cert-manager.yaml

echo "Waiting for cert-manager pod to be Ready..."
kubectl wait pod --for=condition=Ready -l app=cert-manager -n cert-manager --timeout=120s
kubectl wait pod --for=condition=Ready -l app=webhook -n cert-manager --timeout=120s

if [[ -f /etc/cloudflare/cloudflare-api-token ]]; then
	kubectl create secret generic cloudflare -n cert-manager --from-file=cloudflare-api-token=/etc/cloudflare/cloudflare-api-token
fi
kubectl apply -f letsencrypt.yaml
kubectl apply -f cert.yaml

echo "Waiting for coyle.club cert..."
kubectl wait certificate coyle-wildcard --for=condition=Ready --timeout=600s

kubectl apply -f nginx.yaml
kubectl wait pod --for=condition=Ready -l app=nginx --timeout=120s

kubectl apply -f expose.yaml
