IFVRRP=$1
IFREAL=$2

echo "
net.ipv4.conf.all.arp_ignore = 1
net.ipv4.conf.all.arp_announce = 1
net.ipv4.conf.all.arp_filter = 0
net.ipv4.conf.all.accept_local = 1
net.ipv4.conf.all.rp_filter = 0


net.ipv4.conf.default.arp_ignore = 1
net.ipv4.conf.default.arp_announce = 1
net.ipv4.conf.default.arp_filter = 0
net.ipv4.conf.default.accept_local = 1
net.ipv4.conf.default.rp_filter = 0


net.ipv4.conf.$IFREAL.arp_filter = 1

net.ipv4.conf.$IFVRRP.arp_filter = 0
net.ipv4.conf.$IFVRRP.accept_local = 1
net.ipv4.conf.$IFVRRP.rp_filter = 0
" | sysctl -p -
