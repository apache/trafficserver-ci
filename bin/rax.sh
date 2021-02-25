#!/bin/sh

# Packages
yum -y install emacs-nox fail2ban nfs-utils java bzip2 btrfs-progs deltarpm yum-cron yum-plugin-fastestmirror ccache make pkgconfig gcc-c++ openssl-devel tcl-devel expat-devel pcre-devel perl-ExtUtils-MakeMaker libcap libcap-devel hwloc hwloc-devel autoconf automake libtool bison flex git ntp clang rsyslog

groupadd  -g 665 jenkins
useradd -g jenkins -u 989 -s /bin/bash -M -d /home/jenkins -c "Jenkins Continuous Build server" jenkins
mkdir /var/jenkins
chown jenkins.jenkins /var/jenkins

echo "ZONE=public" >> /etc/sysconfig/network-scripts/ifcfg-eth0
echo "ZONE=public" >> /etc/sysconfig/network-scripts/ifcfg-eth1
echo "ZONE=internal" >> /etc/sysconfig/network-scripts/ifcfg-eth2

firewall-cmd --permanent --zone=internal --add-service=rpc-bind
firewall-cmd --permanent --zone=internal --add-service=nfs
firewall-cmd --permanent --zone=internal --remove-service=samba-client
firewall-cmd --complete-reload

echo "[sshd]" > /etc/fail2ban/jail.local
echo "enabled = true" >> /etc/fail2ban/jail.local

mount | grep /home > /dev/null  || echo "192.168.3.1:/home /home nfs  rw,noatime,intr   0 0" >> /etc/fstab
mount /home

# ccache
mkdir -p /var/tmp/ccache && chown jenkins.jenkins /var/tmp/ccache
sudo -u jenkins ccache -M 8G -F 0


# For systemctl
#systemctl enable ntpd
#systemctl restart ntpd

systemctl enable fail2ban
systemctl restart fail2ban
