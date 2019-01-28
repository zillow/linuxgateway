#!/bin/bash
FILE=$1
CHAIN=$2
SUBNET=$3

if [ -z $SUBNET ]; then
   echo "I need options to work with"
   exit 1
fi

exec 1> >(tee /tmp/$(basename $FILE).log | logger -s -t $(basename $0)) 2>&1

if [ ! -f $FILE ]; then
   echo "ERROR: $FILE file not found"
   exit 2
fi
if [[ ! $SUBNET =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
   echo "ERROR: $SUBNET is not a valid subnet"
   exit 2
fi

if diff -U0 ${FILE}.last ${FILE}; then
  #echo "no changes detected, not doing anything, remove or change ${FILE}.last to force a change"
  exit 0
fi

cp ${FILE} ${FILE}.last

COUNT=1
for LINE in $(cat $FILE); do
   LINE=$(sed -E 's/#.*|[[:space:]]*//g' <<<$LINE)
   if [ -z $LINE ]; then
     continue
   fi

   IFS=',' read -r -a line <<<$LINE
   HOST="${line[0]}"
   PORT="${line[1]}"
   PROT="${line[2]}"
   DESC="${line[3]}"

   if [ -z "${HOST}" ] || [ -z "${PORT}" ] || [ -z "${PROT}" ]; then
      echo "WARN: missing variable in $FILE: expecting csv containing: HOST,PORT,PROTOCOL,DESCRIPTION - DESCRIPTION is optional and HOST can be IP or FQDN, got: ${HOST},${PORT},${PROT},${DESC}"
      continue
   fi
   if [[ $HOST =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
      IP=$HOST
    else
      for i in {1..10}; do                                                                     ### try to resolve the IP up to 10 times
         IP=$(/usr/bin/host $HOST | grep "has address" | awk '{ print $4 }')
         if [[ $IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then break; fi      ### if successfully reolved an IP no need to try to resolve again
      done
      if [[ ! $IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
         echo "WARN: unable to determine the IP address for '$IP' / '$HOST' in $FILE"
         continue
      fi
   fi
   
   iptables -I $CHAIN $COUNT  -s $SUBNET -d $IP -p $PROT --dport $PORT -j ACCEPT -m comment --comment "desc: $DESC"
   COUNT=$((COUNT+1))

done

while true; do 
   iptables -D $CHAIN $COUNT 2>/dev/null || break
done

cat /tmp/$(basename $FILE).log | mail -Es "Firewall-exec: $FILE" root
