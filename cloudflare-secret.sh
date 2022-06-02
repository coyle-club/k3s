#!/bin/bash

ssh arepo "sudo -S kubectl create secret generic cloudflared -n cloudflare \
  --from-file=/etc/cloudflare/cloudflared-relay-token \
  --from-file=/etc/cloudflare/cloudflared-tunnel-token"
