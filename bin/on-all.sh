#!/bin/sh

for host in $(awk '/\-int/ {print $2}' /etc/hosts); do
    echo "${host}:"
    ssh $host "$*"
    echo
done
