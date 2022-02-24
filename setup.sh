#!/bin/bash

k3s-uninstall.sh

curl -sfL https://get.k3s.io | INSTALL_K3S_SKIP_START=true sh -

sudo mkdir /etc/rancher/k3s

sudo cp config.yaml /etc/rancher/k3s/
sudo cp 10-coylenet.conflist /etc/cni/net.d/

sudo service k3s start

kubectl apply -f dns.yaml

kubectl apply -f nginx.yaml

kubectl apply -f expose.yaml

kubectl create namespace cert-manager
kubectl apply -f cert-manager-arm.yaml
