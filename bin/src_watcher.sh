#!/bin/bash

while [ 1 ]; do
    inotifywait /CA/src > /dev/null 2>&1
    sleep 1
    rsync -av --delete /CA/src docker-gd-1:/CA > /dev/null 2>&1
done
