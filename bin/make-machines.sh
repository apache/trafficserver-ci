#!/bin/sh

cd /home/jenkins/BuildMachines

# FreeBSD
for h in FreeBSD11; do 
    curl -s -X PURGE https://ci.trafficserver.apache.org/files/BuildMachines/${h}
    ssh ${h}-int freebsd-version > ${h}
    echo >> ${h}
    ssh ${h}-int pkg info | sort >> ${h}
done
exit

# CentOS / Fedora based systems
for h in CentOS6 CentOS7 Fedora24 Fedora25 Fedora26 Fedora27; do
    curl -s -X PURGE https://ci.trafficserver.apache.org/files/BuildMachines/${h}
    ssh ${h}-int cat /etc/redhat-release > ${h}
    echo >> ${h}
    ssh ${h}-int rpm -qa | sort >> ${h}
done

# Debian/Ubuntu systems
for h in Ubuntu1204 Ubuntu1404 Ubuntu1604 Ubuntu1704 Debian7 Debian8; do
    curl -s -X PURGE https://ci.trafficserver.apache.org/files/BuildMachines/${h}
    ssh ${h}-int cat /etc/debian_version > ${h}
    echo >> ${h}
    ssh ${h}-int dpkg -l  >> ${h}
done
