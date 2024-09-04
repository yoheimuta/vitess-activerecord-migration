#!/bin/sh

kubectl port-forward --address 0.0.0.0 "$(kubectl get service --selector="planetscale.com/component=vtgate,!planetscale.com/cell" -o name | head -n1)" 3306 15000 &
process_id1=$!
sleep 2
wait $process_id1
