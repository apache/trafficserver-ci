#!/bin/sh

HOSTS=$(/usr/bin/mktemp --suffix .on-gd)
PSSH="/usr/bin/pssh -i -h $HOSTS"
trap "rm -f $HOSTS" 0 1 2 5 15

/usr/sbin/fping -q -a -f /admin/etc/gd-hosts.txt 2>&1 | cut -d:  -f 1 > $HOSTS
$PSSH  "rpm -qa | sort > /tmp/yum.txt"

for h in $(cat $HOSTS); do
    scp $h:/tmp/yum.txt /tmp/yum-${h}.txt
done

for h in $(cat $HOSTS); do
    echo "Diffing $h"
    for h2 in $(cat $HOSTS); do
	diff /tmp/yum-${h}.txt /tmp/yum-${h2}.txt | grep -v gpg
    done
    echo "Done"; echo; echo
done
    
