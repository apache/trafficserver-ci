#!/bin/bash

ulimit -c unlimited
cd /usr/local/src/trafficserver
git stash
git pull --rebase
git stash pop

gmake  -j4
[ $? -ne 0 ] && exit

/usr/local/bin/trafficserver stop && mv /var/log/trafficserver/traffic.out /var/log/trafficserver/traffic.out.$(date '+%s')
/usr/local/bin/trafficserver start
