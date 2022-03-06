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

sudo service k3s start

NODE_NAME=$(hostname)
echo "Attempting to get podCIDR for node $NODE_NAME..."
while ! POD_CIDR=$(kubectl get node $NODE_NAME -o=jsonpath={.spec.podCIDR}); do
	echo "Trying again in 2 sec..."
	sleep 2
done

sudo cat << EOF > /etc/cni/net.d/10-coylenet.conflist
{
  "name": "k8s-pod-network",
  "cniVersion": "0.3.1",
  "plugins": [
    {
      "type": "bridge",
      "bridge": "docker0",
      "isDefaultGateway": true,
      "forceAddress": false,
      "ipMasq": true,
      "hairpinMode": true,
      "ipam": {
        "type": "host-local",
        "subnet": "$POD_CIDR"
      }
    }
  ]
}
EOF
echo "cni config:"
sudo cat /etc/cni/net.d/10-coylenet.conflist


#kubectl apply -f dns.yaml
#kubectl apply -f expose.yaml

#kubectl create namespace cert-manager

#kubectl apply -f cert-manager.yaml

#if [[ -f /etc/cloudflare/cloudflare-api-token ]]; then
#	kubectl create secret generic cloudflare --from-file=cloudflare-api-token=/etc/cloudflare/cloudflare-api-token
#fi
#kubectl apply -f letsencrypt.yaml