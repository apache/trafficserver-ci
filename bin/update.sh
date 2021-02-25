#!/bin/sh

# 192.168.3.12freebsd10-int

YUM="fedora22-int fedora-latest-int centos5-int centos6-int devel-int znc qa1 qa2"
APT="debian7-int debian8-int ubuntu1204-int ubuntu1404-int ubuntu1505-int ubuntu-latest-int"

for h in $YUM; do
    echo "Doing $h..."
    ssh $h "yum update -y; yum clean all"
done

for h in $APT; do
    echo "Doing $h..."
    ssh $h "apt-get update; apt-get -y dist-upgrade; apt-get -y autoremove"
done
