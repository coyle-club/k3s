#!/bin/bash

if [[ -f /usr/local/bin/k3s-uninstall.sh ]]; then
	echo "Uninstalling k3s..."
	k3s-uninstall.sh
fi

if [[ ! -d /opt/cni/bin ]]; then
	echo "Installing CNI plugins..."
	sudo mkdir -p /opt/cni/bin
	sudo curl "https://github.com/containernetworking/plugins/releases/download/v1.1.0/cni-plugins-linux-arm-v1.1.0.tgz" | tar xvzf -C /opt/cni/bin
fi

echo "Installing k3s..."
curl -sfL https://get.k3s.io | INSTALL_K3S_SKIP_START=true sh - $@

echo "Writing k3s config..."
sudo mkdir -p /etc/rancher/k3s
sudo cp config.yaml /etc/rancher/k3s/

echo "Starting k3s..."
sudo service k3s start


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
sudo cp /tmp/cni.conflist /etc/cni/net.d/10-cni.conflist
rm /tmp/cni.conflist

echo "Setting up cert-manager..."
kubectl create namespace cert-manager

kubectl apply -f cert-manager.yaml

echo "Waiting for cert-manager pod to be Ready..."
kubectl wait pod --for=condition=Ready -l app=cert-manager -n cert-manager

if [[ -f /etc/cloudflare/cloudflare-api-token ]]; then
	kubectl create secret generic cloudflare -n cert-manager --from-file=cloudflare-api-token=/etc/cloudflare/cloudflare-api-token
fi
kubectl apply -f letsencrypt.yaml
kubectl apply -f cert.yaml

echo "Waiting for coyle.club cert..."
kubectl wait certificate coyle-wildcard --for=condition=Ready

kubectl apply -f expose.yaml