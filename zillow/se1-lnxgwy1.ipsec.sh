#!/bin/bash

# Tunnel SE1
ip tunnel add vti2.1 mode vti local 192.168.43.8 remote 1.2.3.4 okey 21 ikey 21
ip link set vti2.1 up
ip addr add 169.254.5.14/30 remote 169.254.5.13/30 dev vti2.1
sysctl -w 'net.ipv4.conf.vti2/1.disable_policy=1'


# Tunnel SE1
ip tunnel add vti2.2 mode vti local 192.168.43.8 remote 2.3.4.5 okey 22 ikey 22
ip link set vti2.2 up
ip addr add 169.254.5.18/30 remote 169.254.5.17/30 dev vti2.2
sysctl -w 'net.ipv4.conf.vti2/2.disable_policy=1'


### VPN access Policies (to access FROM the VPN resources IN sv2)
 ## Zillow SE1
iptables -N se1
iptables -A FORWARD        -i vti2.+      -j se1
iptables -A se1            -i vti2.+      -j ACCEPT


### special rules for znet
iptables -A INPUT          -i vti2.+      -s 172.16.0.0/16   -p tcp --dport 22       -j ACCEPT
