#!/bin/bash

set -e

patch_release()
{
  root_dir=$(pwd)
  ver=$1
  patch=$2
  echo version: $ver
  echo patch file: $patch
  rm -rf installed/trafficserver/$ver
  rm -rf src/trafficserver/$ver
  mkdir -p src/trafficserver/$ver
  cd src/trafficserver/$ver
  wget https://archive.apache.org/dist/trafficserver/trafficserver-${ver}.tar.bz2
  tar -xjf trafficserver-${ver}.tar.bz2
  cd trafficserver-${ver}
  patch -p0 < ../../../../patches/$patch
  cd ..
  rm trafficserver-${ver}.tar.bz2
  tar -cjf trafficserver-${ver}.tar.bz2 trafficserver-${ver}
  rm -rf trafficserver-${ver}
  cd $root_dir
}

for i in 8.1.0 8.1.1 8.1.2; do
  patch_release $i limits_8.x.patch
done

patch_release 9.0.0 limits_9.x.patch

