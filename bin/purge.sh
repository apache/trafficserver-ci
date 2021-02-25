#!/bin/bash

for u in $*; do
    echo "Purging $u..."
    curl --resolve ci.trafficserver.apache.org:443:192.168.3.14 -X PURGE "$u"
done
