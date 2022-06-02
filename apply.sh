#!/bin/bash

args="$@"

if [[ $args == "" ]]; then
	$args=manifests/*.yaml
fi

for filename in $args; do
	echo "-> Applying $filename"
	cat $filename | ssh arepo "kubectl apply -f -"
done