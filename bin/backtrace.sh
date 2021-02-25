#!/bin/sh

DM=/var/backtrace/ats
CF=/usr/local/etc/coroner.cf
PATH=/opt/backtrace/bin:/usr/bin:/bin:$PATH

TAG=$(/opt/ats/bin/traffic_ctl metric get proxy.node.version.manager.short|cut -d ' ' -f 2)

mkdir -p ${DM}/
ptrace --kv="tag:${TAG}" $1 -O ${DM}/ats
if test "$?" == "0"; then
    coroner -c $CF put -u ats ats ${DM}/*.btt
fi
