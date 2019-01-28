#!/bin/sh
/bin/cat /etc/haproxy/haproxy.cfg | /bin/grep "frontend\|bind\s\|listen\s" | /bin/grep -v "^\s*#" | /bin/sed 's/frontend //' | /bin/sed 's/listen\s*//' | /bin/sed 's/\s*bind\s*//' | 
/bin/sed 's/\s*name.*//' | /bin/sed ':a;N;$!ba;s/\n\([0-9]\)/ \1/g' | /bin/sed 's/\s\s*/ /' | /usr/bin/awk '{ print "<a href=\"http://"$2"/haproxy-stats\">"$1"</a>" }' | /bin/sed ':a;N;$!ba;s/\n/,/g'
