#!/bin/sh

SRC=$1
DEST=$2

for host in $(awk '/\-int/ {print $2}' /etc/hosts); do
    echo "${host}:"
    scp $SRC ${host}:$DEST
done
