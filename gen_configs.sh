#!/bin/bash
URL=$1
CIDR=$2
TEAM=$3
WORKDIR="/vpns"
FILETMP="/tmp/vpn.cfg.tmp"
MYPUBIP=$(ip addr show dev ens7f0 | grep 'inet ' | awk '{ print $2 }' | sed 's/\/24//')


function die {
        echo "====================================================================================="
        echo "$1"
        echo "====================================================================================="
        exit 255
}



if [ ! $3 ]; then
   echo "usage: $0 config-URL/FILE VPC-cidr teamname"
   echo "==============================="
   echo "config-URL/FILE    =    Amazon provided Generic VPN config file (can be a http url)"
   echo "VPC-cidr           =    Subnet used in AWS' VPC -> 172.16.XX.0/24"
   echo "teamname           =    short name of Team requesting / owning VPC"
   exit 128
fi


if [[ $CIDR == 172.16.* ]]; then
   INDEX=${CIDR#*.*.*}
   INDEX=${INDEX%%.*}
   INDEX=$(printf "%02d" $INDEX)
elif [[ $CIDR == 10.130.* ]]; then
   INDEX1=${CIDR#*.*}
   INDEX1=${INDEX1%%.*}
   INDEX1=$(printf "%03d" $INDEX1)
   INDEX2=${CIDR#*.*.*}
   INDEX2=${INDEX2%%.*}
   INDEX2=$(printf "%03d" $INDEX2)
   INDEX="10${INDEX1}${INDEX2}"
else
   die "Subnet not supported"
fi


if [ ! -w "$WORKDIR/" ]; then
   die "$WORKDIR not writeable for me"
fi

if [ -e "$FILETMP" ]; then
   echo "WARNING: $FILETMP exist... overriding"
   rm "$FILETMP" || die "unable to delete tmp file $FILETMP"
fi


if [[ "$URL" == http://* ]] || [[ "$URL" == https://* ]]; then 
    wget -qO "$FILETMP" "$URL"
  elif [[ $URL != $FILETMP ]]; then
    cp "$URL" "$FILETMP"
fi

chmod 600 "$FILETMP" || die "unable to chmod"


if /usr/bin/file $FILETMP | grep XML
  then
    VPNID=$(/usr/bin/xmlstarlet sel -t -v "//vpn_connection/@id" $FILETMP)
    FILETYPE=xml
  else
    VPNID=$(cat $FILETMP | grep "Your VPN Connection ID" | awk -F ':' '{ print $2 }' | sed 's/\s*//g')
    FILETYPE=txt
fi


FILEPFX="$WORKDIR/aws-$INDEX-$TEAM-$VPNID"

if [ -e "$FILEPFX.$FILETYPE" ]; then 
   die "config file already exists locally"; 
fi




echo "======================"
echo "URL:     $URL"
echo "VPN:     $VPNID"
echo "FILE:    $FILEPFX"
echo "index:   $INDEX"
echo "type:    $FILETYPE"
echo "hit return to continue"
echo "======================"
read



if [ "$FILETYPE" == "txt" ]
   then
      echo "parsing as textfile"

      # gather various variables from AWS config file
      j=0
      for i in `cat $FILETMP | grep -- "- Virtual Private  Gateway ASN" | awk -F ':' '{ print $2 }' | sed 's/\s*//g'`; do
          awsasn[$j]=$i
          j=$(($j+1))
      done
      
      j=0
      for i in `cat $FILETMP | grep -- "- Customer Gateway ASN" | awk -F ':' '{ print $2 }' | sed 's/\s*//g'`; do
          myasn[$j]=$i
          j=$(($j+1))
      done
      
      j=0
      for i in `cat $FILETMP | grep -- "- Virtual Private Gateway" | grep -v "169.254" | awk -F ':' '{ print $2 }'i | sed 's/\s*//g'`; do
          awspubip[$j]=$i
          j=$(($j+1))
      done
      
      j=0
      for i in `cat $FILETMP | grep -- "- Customer Gateway" | grep -v "169.254" | awk -F ':' '{ print $2 }' | sed 's/\/30//' | sed 's/\s*//g'`; do
          mypubip[$j]=$i
          j=$(($j+1))
      done
      
      j=0
      for i in `cat $FILETMP | grep -- "- Virtual Private Gateway  " | grep "169.254" | awk -F ':' '{ print $2 }' | sed 's/\/30//' | sed 's/\s*//g'`; do
          awstunnelip[$j]=$i
          j=$(($j+1))
      done
      
      j=0
      for i in `cat $FILETMP | grep -- "- Customer Gateway" | grep "169.254" | awk -F ':' '{ print $2 }' | sed 's/\/30//' | sed 's/\s*//g'`; do
          mytunnelip[$j]=$i
          j=$(($j+1))
      done
      
      j=0
      for i in `cat $FILETMP | grep -- "- Pre-Shared Key" | awk -F ':' '{ print $2 }'`; do
          psk[$j]=$i
          j=$(($j+1))
      done
      

else
      echo "parsing as XML"
      
      
      ##############
      ## READ XML ##
      ##############
      ### read AWS ASN numbers to use for BGP
      j=0
      for i in $(xmlstarlet sel -T -t -v "//ipsec_tunnel/vpn_gateway/bgp/asn" $FILETMP || exit 255)
        do 
          awsasn[$j]=$i
          j=$(($j+1))
      done
      if [ $j -gt 2 ]; then 
        die "found more ASN numbers that I can handle"
      fi
      j=0
      for i in $(xmlstarlet sel -T -t -v "//ipsec_tunnel/customer_gateway/bgp/asn" $FILETMP || exit 255)
        do 
          myasn[$j]=$i
          j=$(($j+1))
      done
      if [ $j -gt 2 ]; then 
        die "found more ASN numbers that I can handle"
      fi
      
      
      ### read Public Tunnel IPs
      j=0
      for i in $(xmlstarlet sel -T -t -v "//ipsec_tunnel/vpn_gateway/tunnel_outside_address/ip_address" $FILETMP || exit 255)
        do 
          awspubip[$j]=$i
          j=$(($j+1))
      done
      if [ $j -gt 2 ]; then 
        die "found more IPs that I can handle"
      fi
      j=0
      for i in $(xmlstarlet sel -T -t -v "//ipsec_tunnel/customer_gateway/tunnel_outside_address/ip_address" $FILETMP || exit 255)
        do 
          mypubip[$j]=$i
          j=$(($j+1))
      done
      if [ $j -gt 2 ]; then 
        die "found more IPs that I can handle"
      fi
      
      
      ### read Private Tunnel IPs
      j=0
      for i in $(xmlstarlet sel -T -t -v "//ipsec_tunnel/vpn_gateway/tunnel_inside_address/ip_address" $FILETMP || exit 255)
        do 
          awstunnelip[$j]=$i
          j=$(($j+1))
      done
      if [ $j -gt 2 ]; then 
        die "found more IPs that I can handle"
      fi
      j=0
      for i in $(xmlstarlet sel -T -t -v "//ipsec_tunnel/customer_gateway/tunnel_inside_address/ip_address" $FILETMP || exit 255)
        do 
          mytunnelip[$j]=$i
          j=$(($j+1))
      done
      if [ $j -gt 2 ]; then 
        die "found more IPs that I can handle"
      fi
      
      
      ### read PSK
      j=0
      for i in $(xmlstarlet sel -T -t -v "//ipsec_tunnel/ike/pre_shared_key" $FILETMP || exit 255)
        do 
          psk[$j]=$i
          j=$(($j+1))
      done
      if [ $j -gt 2 ]; then 
        die "found more PSK that I can handle"
      fi

fi







## sanity checks
echo "## running some sanity checks beforehand"
if [ "${mypubip[0]}" != "$MYPUBIP" ]
  then
    die "this config does not look like it's meant for me, I'm not ${mypubip[0]}.... aborting"
fi
if [ "${mypubip[1]}" != "$MYPUBIP" ]
  then
    die "this config does not look like it's meant for me, I'm not ${mypubip[1]}.... aborting"
fi
if grep mark $WORKDIR/*.ipsec.conf | awk '{ print $2 }' | grep ${INDEX}1 >/dev/null 2>&1 || grep mark $WORKDIR/*.ipsec.conf | awk '{ print $2 }' | grep ${INDEX}2 >/dev/null 2>&1
  then
    die "something is already using that index: $INDEX .... aborting"
fi
if grep vti${INDEX}.1 $WORKDIR*.ipsec.sh >/dev/null 2>&1 || grep vti${INDEX}.2 $WORKDIR*.ipsec.sh >/dev/null 2>&1
  then
    die "vti interface already exists ... please check manually"
fi
if ip link show dev vti${INDEX}.1 >/dev/null 2>&1 || ip link show dev vti${INDEX}.2 >/dev/null 2>&1
  then
    die "vti interface already exists ... please check manually"
fi
if ip route get ${mytunnelip[0]} | grep "vti\|lo" >/dev/null 2>&1
  then
    die "tunnel subnet ${mytunnelip[0]} already exist in local routing table... aborting"
fi
if ip route get ${mytunnelip[1]} | grep "vti\|lo" >/dev/null 2>&1
  then
    die "tunnel subnet ${mytunnelip[1]} already exist in local routing table... aborting"
fi
echo "## sanity checks done ... looking good"



## blank line on top of first conn is needed for strongswan to start correctly do NOT ask me why
cat >${FILEPFX}.ipsec.conf <<EOF

conn aws_${INDEX}_${VPNID}_1
    right=${awspubip[0]}
    mark=${INDEX}1

conn aws_${INDEX}_${VPNID}_2
    right=${awspubip[1]}
    mark=${INDEX}2

EOF


cat >${FILEPFX}.ipsec.secrets <<EOF
%any ${awspubip[0]} : PSK "${psk[0]}"
%any ${awspubip[1]} : PSK "${psk[1]}"
EOF


cat >${FILEPFX}.bird.conf <<EOF
protocol bgp 'aws_${INDEX}_${VPNID}_1' from awspeer {
        local ${mytunnelip[0]} as ${myasn[0]};
        neighbor ${awstunnelip[0]} as ${awsasn[0]};
}

protocol bgp 'aws_${INDEX}_${VPNID}_2' from awspeer {
        local ${mytunnelip[1]} as ${myasn[1]};
        neighbor ${awstunnelip[1]} as ${awsasn[1]};
}
EOF



cat >${FILEPFX}.ipsec.sh <<EOF
#!/bin/bash

# Tunnel 1 aws_${VPNID}_1
ip tunnel add vti${INDEX}.1 mode vti local ${MYPUBIP} remote ${awspubip[0]} okey ${INDEX}1 ikey ${INDEX}1
ip link set vti${INDEX}.1 up
ip addr add ${mytunnelip[0]}/30 remote ${awstunnelip[0]}/30 dev vti${INDEX}.1
sysctl -w 'net.ipv4.conf.vti${INDEX}/1.disable_policy=1'

# Tunnel 2 aws_${VPNID}_2
ip tunnel add vti${INDEX}.2 mode vti local ${MYPUBIP} remote ${awspubip[1]} okey ${INDEX}2 ikey ${INDEX}2
ip link set vti${INDEX}.2 up
ip addr add ${mytunnelip[1]}/30 remote ${awstunnelip[1]}/30 dev vti${INDEX}.2
sysctl -w 'net.ipv4.conf.vti${INDEX}/2.disable_policy=1'

iptables -N aws-${INDEX}-${TEAM}
iptables -A FORWARD    -i vti${INDEX}.+   -s ${CIDR}    -j aws-${INDEX}-${TEAM}
EOF

chmod 755 ${FILEPFX}.ipsec.sh


cat >${FILEPFX}.remove.sh <<EOF
#!/bin/bash


iptables -D FORWARD    -i vti${INDEX}.+   -s ${CIDR}    -j aws-${INDEX}-${TEAM}
iptables -F aws-${INDEX}-${TEAM}
iptables -X aws-${INDEX}-${TEAM}


rm ${FILEPFX}.ipsec.conf
rm ${FILEPFX}.ipsec.secrets
rm ${FILEPFX}.ipsec.sh
rm ${FILEPFX}.bird.conf

ip tunnel delete vti${INDEX}.1
ip tunnel delete vti${INDEX}.2

ipsec rereadsecrets
ipsec update
echo configure soft | birdc

ipsec down aws_${INDEX}_${VPNID}_1
ipsec down aws_${INDEX}_${VPNID}_2

rm ${FILEPFX}.remove.sh

EOF

chmod 755 ${FILEPFX}.remove.sh

echo "moving config file to $FILEPFX.$FILETYPE"
mv "$FILETMP" "$FILEPFX.$FILETYPE"


echo "======================"
echo "activating new config"
echo "======================"

${FILEPFX}.ipsec.sh
ipsec rereadsecrets
ipsec update
echo configure soft | birdc
echo show protocols | birdc
