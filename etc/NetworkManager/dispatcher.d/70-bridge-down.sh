#!/bin/bash

interface=$1
action=$2

[[ $interface == "enp0s20f0u1" && $action == "down" ]] && { nmcli connection down bridge-br0; exit 0; }
[[ $interface == "enp0s20f0u6u3" && $action == "down" ]] && { nmcli connection down bridge-br0; exit 0; }

