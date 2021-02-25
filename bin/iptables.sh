#!/bin/sh

# Allow Apple buildbot
iptables -I INPUT -i eth0 -s 17.244.0.0/14 -p tcp -m tcp --dport 40649 -j ACCEPT

# Restrict SSH
iptables -I INPUT -p tcp -m tcp -s 24.9.49.85/32 --dport 22 -j ACCEPT
iptables -I INPUT -p tcp -m tcp -s 24.56.188.103/32 --dport 22 -j ACCEPT
iptables -I INPUT -p tcp -m tcp --dport 22 -m state --state new -m limit --limit 20/hour --limit-burst 6 -j ACCEPT
iptables -I INPUT -m tcp -p tcp --dport 22 -j LOG --log-prefix "IPTABLES SSH-LIMIT: "
iptables -I INPUT -m tcp -p tcp --dport 22 -j DROP
