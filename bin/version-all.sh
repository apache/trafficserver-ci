#!/bin/sh

# Fedora
for x in 31 32; do
    echo -n "Fedora${x}: "
    docker run -v /home:/home -v /CA:/CA -v /var/tmp:/var/tmp -i -t ci.trafficserver.apache.org/ats/fedora:${x}  cat /etc/redhat-release
done

# CentOs
for x in 6 7 8; do
    echo -n "CentOS${x}: "
    docker run -v /home:/home -v /CA:/CA -v /var/tmp:/var/tmp -i -t ci.trafficserver.apache.org/ats/centos:${x}  cat /etc/redhat-release
done

# Debian
for x in 8 9; do
    echo -n "Debian${x}: "
    docker run -v /home:/home -v /CA:/CA -v /var/tmp:/var/tmp -i -t ci.trafficserver.apache.org/ats/debian:${x}  cat /etc/debian_version
done

# Ubuntu
for x in 14.04 16.04 18.04 19.04 20.04 20.10; do
    echo -n "Ubuntu${x}: "
    docker run -v /home:/home -v /CA:/CA -v /var/tmp:/var/tmp -i -t ci.trafficserver.apache.org/ats/ubuntu:${x}  grep DISTRIB_RELEASE /etc/lsb-release
done
