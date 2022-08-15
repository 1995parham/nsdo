#!/bin/bash

namespace="elie"
internet="wlan0"
subnet="192.168.78"

# global variable that points to nsdo/scripts directory
current_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR/lib
source "$current_dir/lib/message.sh"

function main() {
	# delete iptables rule and network namespace
	sudo iptables -D FORWARD -i "$internet" -o "${namespace}o" -j ACCEPT
	sudo iptables -D FORWARD -o "$internet" -i "${namespace}o" -j ACCEPT
	sudo iptables -t nat -D POSTROUTING -s "${subnet}.0/24" -o "$internet" -j MASQUERADE

	sudo ip route del "${subnet}.0/24"
	sudo ip link del "${namespace}o"

	# delete resolv.conf setup
	[ ! -d "/etc/netns/$namespace" ] || sudo rm -rf "/etc/netns/$namespace"

	# disable IPV4 forward
	echo "0" | sudo tee /proc/sys/net/ipv4/ip_forward

	sudo ip netns del "$namespace"
}

main "$@"
