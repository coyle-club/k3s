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
while ! POD_CIDR=$(kubectl get node $NODE_NAME -o=jsonpath={.spec.podCIDR}); do
	echo "Trying again in 2 sec"
	sleep 2
done
echo " -> $POD_CIDR"

echo "Writing CNI config..."
sed "s/__POD_CIDR__/$POD_CIDR/g" 10-coyletnet.conflist
sudo cp 10-coyletnet.conflist /etc/cni/net.d/

kubectl apply -f dns.yaml
kubectl apply -f expose.yaml

echo "Setting up cert-manager..."
kubectl create namespace cert-manager

kubectl apply -f cert-manager.yaml

if [[ -f /etc/cloudflare/cloudflare-api-token ]]; then
	kubectl create secret generic cloudflare --from-file=cloudflare-api-token=/etc/cloudflare/cloudflare-api-token
fi
kubectl apply -f letsencrypt.yaml