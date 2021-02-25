#!/bin/sh

#!/bin/bash

HOSTS=$(/usr/bin/mktemp --suffix .on-gd)
PSSH="/usr/bin/pssh -i -h $HOSTS"
trap "rm -f $HOSTS" 0 1 2 5 15

/usr/sbin/fping -q -a -f /admin/etc/gd-hosts.txt 2>&1 | cut -d:  -f 1 > $HOSTS

NUM_ARGS=$(($#-1))

case "$1" in
    #
    # DNF (yum) commands
    #
    install)
    ;&
    debuginfo-install)
    ;&
    remove)
    ;&
    update)
    ;&
    clean)
    ;&
    upgrade)
    $PSSH "yum -y $*"
    ;;
    #
    # systemd (systemctl) comamands
    #
    enable)
    ;&
    disable)
    ;&
    status)
    ;&
    stop)
    ;&
    start)
    ;&
    restart)
    $PSSH "systemctl $*"
    ;;
    #
    # scp
    #
    scp)
    dest=${@: -1}
    files=${@:2:$NUM_ARGS-1}
    pscp.pssh -h ${HOSTS} "$files" "${dest}"
    ;;
    #
    # Everything else
    #
    *)
    $PSSH -X "-x" "$*"
    ;;
esac
