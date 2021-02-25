#!/bin/sh

pkg update
pkg upgrade -y
pkg install -y emacs-nox11 py27-fail2ban gcc gcc49 openjdk bzip2 gmake ccache openssl tcl86 expat pcre p5-ExtUtils-MakeMaker hwloc autoconf automake libtool bison flex git bash

ln -s /usr/local/bin/git /usr/bin
ln -s /usr/local/bin/bash /bin

echo "mount -t fdescfs fdesc /dev/fd" >> /etc/fstab
echo "mount -t procfs proc /proc" >> /etc/fstab


pw groupadd jenkins -g 665
pw useradd jenkins -g jenkins -u 665,665

mkdir /var/jenkins && chown jenkins /var/jenkins && chgrp jenkins /var/jenkins
mkdir -p /home/jenkins/.ssh
chmod -R 700 /home/jenkins

echo 'from="23.253.81.82,192.168.3.*",no-X11-forwarding ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCnOsr+q3xlFQZ3Z2cH8fpZynAWCmOZkbjBXH19c6C3KzA9cUPe8v7YnBq3tmfKtnMJYv42ZYz4n0ddHfbU91qqEwr6It7xN0kQeqtW0oGzLPWHun90YabKGeLVONFzlWzQG9Wv2R2se3W1qX8PKpAEyaocyujP94dc2tFQUkQ9tIj3fjVBj8SzrggnkC76MXojMHcPSZEYB4jZWxVlgWkX2vN2Te4qVJy6MlCEDOkYQW62TkfowZclNOu+OJvD7/kxOPLggWM9id9SWYvyMfJF8qd+xY1o9XY/kcnuGCCxnkGrNaOVeHsdKq87rhe2nGltZOnfucYN+S3pThYVUAJsB7bmmCwY/h4N2OXjUv/Rhg+NUERvU2Lc3I0z99aMvbBCK9EgKKIWxUAlQZyIYglEKjbf0oQM3YzviU8p+IvO1Yi5qa4523vHYSBkD2hASzRjgdp2dScYolHfzZTuywX7GBfuzL64oUgQWRQ+UtVxHB/XINNKbUdsiiL05Io8VbQfPgpL8ILLA8lCVpMzxnQPz4YAVpMWkBKG/4PoF9riWoMneBdQgwwlZCASMPWSzPxZmHeQdv9Hdiwo85XmtE6Q+nHvNw/vYGHnO1uySoM1obzCfPUR2tBupNQSigbdoOa7HNVEWg1lXhNXqV/ZF/fv3JoBDUJXWYXyh3HQtzbtXQ== root@jenkins-master.rax.boot.org' > /home/jenkins/.ssh/authorized_keys

chmod 600 /home/jenkins/.ssh/authorized_keys
chown -R jenkins /home/jenkins
chgrp -R jenkins /home/jenkins

sudo -u jenkins ccache -M 10G -F 0

echo 'ntpd_enable="YES"' >> /etc/rc.conf
echo 'firewall_enable="YES"' >> /etc/rc.conf
echo 'firewall_type="client"'>> /etc/rc.conf
echo 'fail2ban_enable="YES"' >> /etc/rc.conf
