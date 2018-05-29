#!/usr/bin/env bash

if [[ "$1" != "eth1" ]]; then exit 0; fi

function mask2cdr {
  # Assumes there's no "255." after a non-255 byte in the mask
  local x=${1##*255.}
  set -- 0^^^128^192^224^240^248^252^254^ $(( (${#1} - ${#x})*2 )) ${x%%.*}
  x=${1%%$3*}
  echo $(( $2 + (${#x}/4) ))
}

function main {
  SUBNET_CIDR="$(netstat -rn | awk '$NF == "eth0" && $4 == "U" { print $1 }')/$(mask2cdr "$(netstat -rn | awk '$NF == "eth0" && $4 == "U" { print $1 }')")"
  IP_GATEWAY="$(bash -c 'echo $1 $2 $3 $(( $4 + 1 ))' '' $(netstat -rn | awk '$NF == "eth0" && $4 == "U" { print $1 }' | sed 's#\.# #g') | sed 's# #.#g')"
  IP_ADDRESS="$(ifconfig eth0 | awk 'NR == 2 {print $2}' | cut -d: -f2)"
  echo 1 rt2 >>  /etc/iproute2/rt_tables

  ip route add ${SUBNET_CIDR} dev eth0 src ${IP_ADDRESS} table rt2
  ip route add default via ${IP_GATEWAY} dev eth0 table rt2

  ip rule add from ${IP_ADDRESS}/32 table rt2
  ip rule add to ${IP_ADDRESS}/32 table rt2

  sysctl -q -w net.ipv4.ip_forward=1 net.ipv4.conf.eth1.send_redirects=0 net.ipv4.conf.eth0.send_redirects=1

  iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
  iptables -t nat -C POSTROUTING -o eth1 -j MASQUERADE || iptables -t nat -A POSTROUTING -o eth1 -j MASQUERADE

  ip route del default via ${IP_GATEWAY}
}

main "$@"
