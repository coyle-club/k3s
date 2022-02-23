#!/bin/bash

k3s-uninstall.sh

curl -sfL https://get.k3s.io | INSTALL_K3S_SKIP_START=true sh -

sudo mkdir /etc/rancher/k3s

sudo cp config.yaml /etc/rancher/k3s/

sudo service k3s start

kubectl apply -f dns.yaml
