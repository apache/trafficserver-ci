#!/bin/sh

docker run -v /home:/home -v /CA:/CA -v /var/tmp/ccache:/var/tmp/ccache -i -t ci.trafficserver.apache.org/ats/centos:6  /bin/bash
