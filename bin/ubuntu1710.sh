#!/bin/sh

docker run -v /home:/home -v /CA:/CA -v /var/tmp:/var/tmp -i -t ci.trafficserver.apache.org/ats/ubuntu:17.10  /bin/bash
