#!/bin/sh

#
# NOTE NOTE: Do not commit this script into any source repository!!!
#

curl --form project=Apache+Traffic+Server \
  --form token=rXAv468n \
  --form email=zwoop@apache.org \
  --form file=@${1} \
  --form version=${2} \
  --form description="ATS master branch" \
  https://scan.coverity.com/builds?project=Apache+Traffic+Server
