#!/bin/sh

# Fedora
for x in 27 28 29 30; do
    echo -n "Fedora${x}: "
    docker run -v /home:/home -v /CA:/CA -v /var/tmp:/var/tmp -i -t ci.trafficserver.apache.org/ats/fedora:${x} "$@"
done

# CentOs
for x in 6 7; do
    echo -n "CentOS${x}: "
    docker run -v /home:/home -v /CA:/CA -v /var/tmp:/var/tmp -i -t ci.trafficserver.apache.org/ats/centos:${x} "$@"
done

# Debian
for x in 7 8 9; do
    echo -n "Debian${x}: "
    docker run -v /home:/home -v /CA:/CA -v /var/tmp:/var/tmp -i -t ci.trafficserver.apache.org/ats/debian:${x} "$@"
done

# Ubuntu
for x in 14.04 16.04 17.04 17.10 18.04 18.10 19.04; do
    echo -n "Ubuntu${x}: "
    docker run -v /home:/home -v /CA:/CA -v /var/tmp:/var/tmp -i -t ci.trafficserver.apache.org/ats/ubuntu:${x} "$@"
done
