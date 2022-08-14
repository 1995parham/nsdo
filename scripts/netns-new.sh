#!/bin/bash

set -eu
set -o pipefail

namespace="elie"
internet="wlan0"
subnet="192.168.78"
use_resolve=true

# global variable that points to nsdo/scripts directory
current_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR/lib
source "$current_dir/lib/message.sh"

function main() {
	# output setup information
	cat <<EOF
Using following options:
- network namespace: $namespace
- network interface: $internet
- IPv4 address for ${namespace}d: ${subnet}.1/24
- resolv.conf: ${use_resolve}
EOF

	# check that internet network interface is exists
	ip link show "$internet" >/dev/null 2>&1 || (
		echo "interface $internet which is used for internte access does not exists"
		exit 1
	)

	# add network namespace and interfaces
	running ip "create ns ${namespace}"
	sudo ip netns add "$namespace"
	running ip "create ${namespace}r interface in ${namespace} namespace"
	sudo ip link add "${namespace}o" type veth peer name "${namespace}r"
	sudo ip link set "${namespace}r" netns "$namespace"
	action ip "network namespace created and interface ${namespace}r attaches to it"

	# set ip address and up interface in the default network namespace
	sudo ip addr add "${subnet}.1/24" dev "${namespace}o"
	sudo ip link set "${namespace}o" up
	action "ip" "interface ${namespace}o is up"

	# Setup interface in another network namespace
	sudo ip netns exec "$namespace" ip link set "${namespace}r" name eth0
	sudo ip netns exec "$namespace" ip addr add "${subnet}.2/24" dev eth0
	sudo ip netns exec "$namespace" ip link set eth0 up
	sudo ip netns exec "$namespace" ip route add default via "${subnet}.1"
	action "ip" "interface ${namespace}r in ${namespace} is up and ready"

	# Enable IPv4 forward
	echo "1" | sudo tee /proc/sys/net/ipv4/ip_forward
	action "sysfs" "ipv4 forwarding"

	# add NAT rule
	sudo iptables -t nat -A POSTROUTING -s "${subnet}.0/24" -o "$internet" -j MASQUERADE
	action "iptables" "NAT rule is ready"

	# setup resolv.conf for this network namespace
	if [ $use_resolve ]; then
		[ -d "/etc/netns/$namespace" ] || sudo mkdir -p "/etc/netns/$namespace"
		echo "nameserver 8.8.8.8" | sudo tee "/etc/netns/$namespace/resolve.conf"
	fi
	action "etc" "setup resolve.conf"

	sudo iptables -A FORWARD -i "$internet" -o "${namespace}o" -j ACCEPT
	sudo iptables -A FORWARD -o "$internet" -i "${namespace}o" -j ACCEPT
	action "iptables" "setup forwarding rules"
}

main "$@"
