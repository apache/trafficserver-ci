#!/bin/bash

GD_HOSTS="gd-1 gd-2 gd-3 gd-4 gd-5 gd-6 gd-7 gd-8 gd-9"
HOME_DIRS="/home/jenkins /home/trafficserver /home/admin"
CA_DIRS="/CA/autest /CA/clang-analyzer /CA/RAT"

if [ "fetch" == "$1" ]; then
    parallel  'rsync --exclude="core.*" -av {2}:{1} /CA' ::: $CA_DIRS ::: $GD_HOSTS
else
    parallel  'rsync --exclude=.ccache --delete -av {1} {2}:/home' ::: $HOME_DIRS ::: $GD_HOSTS
fi
