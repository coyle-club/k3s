#!/bin/bash

if [[ -f /usr/local/bin/k3s-uninstall.sh ]]; then
	k3s-uninstall.sh
fi

if [[ ! -d /opt/cni/bin ]]; then
	sudo mkdir -p /opt/cni/bin
	sudo curl "https://github.com/containernetworking/plugins/releases/download/v1.1.0/cni-plugins-linux-arm-v1.1.0.tgz" | tar xvzf -C /opt/cni/bin
fi

curl -sfL https://get.k3s.io | INSTALL_K3S_SKIP_START=true sh - $@

sudo mkdir -p /etc/rancher/k3s

sudo cp config.yaml /etc/rancher/k3s/
sudo cp 10-coylenet.conflist /etc/cni/net.d/

sudo service k3s start

kubectl apply -f subnets.yaml


#kubectl apply -f dns.yaml
#kubectl apply -f expose.yaml

#kubectl create namespace cert-manager

#kubectl apply -f cert-manager.yaml

#if [[ -f /etc/cloudflare/cloudflare-api-token ]]; then
#	kubectl create secret generic cloudflare --from-file=cloudflare-api-token=/etc/cloudflare/cloudflare-api-token
#fi
#kubectl apply -f letsencrypt.yaml