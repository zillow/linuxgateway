#!/bin/bash

TYPE=$1
NAME=$2
STATE=$3

case $STATE in
        "MASTER")
		if [ "$TYPE" == "INSTANCE" ]
                  then
		    logger "Keepalived - toby - notify: applying tweaks to $NAME to be master"
		    #below is only needed if vmac is used
		    sysctl net.ipv4.conf.$NAME.arp_filter=0 | logger
		    sysctl net.ipv4.conf.$NAME.accept_local=1 | logger
		    sysctl net.ipv4.conf.$NAME.rp_filter=0 | logger
		  else
		    logger "Keepalived - toby - notify: notify script NEEDs correct VRRP interface name -> run it from instance - $TYPE $NAME $STATE"
		fi

                  exit 0
                  ;;
        "BACKUP")
	   	  logger "Keepalived - toby - notify: $NAME to backup"
		  sysctl net.ipv6.conf.$NAME.disable_ipv6=1 | logger
                  exit 0
                  ;;
        "FAULT")
	          logger "Keepalived - toby - notify: FAULT STATE! doing nothing but logging - $TYPE $NAME $STATE"
                  exit 0
                  ;;
        *)
	          logger "Keepalived - toby - notify: UNKNOWN STATE. doing nothing but logging - $TYPE $NAME $STATE"
                  exit 1
                  ;;
esac
