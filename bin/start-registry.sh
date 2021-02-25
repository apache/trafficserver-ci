#!/bin/bash

fail()
{
    echo $1
    exit 1
}
[ "$EUID" -eq 0 ] || fail "This must be run as root."
docker-compose -f /admin/etc/docker-compose.yml up -d
