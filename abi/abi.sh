#!/bin/sh

abi-monitor -get -build trafficserver.json
abi-tracker -build trafficserver.json

# Deploy to webserver directory
#abi-tracker -deploy /usr/share/nginx/html/abi-trafficserver/
#cp -pr images /usr/share/nginx/html/abi-trafficserver/

# Untar reports and remove tar.gz reports
#cd /usr/share/nginx/html/abi-trafficserver/
#for i in $(find . -name '*tar.gz'); do tar -C $(dirname $i) -xf $i; done
#find . -name '*tar.gz' -exec rm {} \;
