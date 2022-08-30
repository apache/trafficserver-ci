#!/usr/bin/env bash
#
#  Simple script to build OpenSSL and various tools with H3 and QUIC support.
#  This probably needs to be modified based on platform.
#
#  Licensed to the Apache Software Foundation (ASF) under one
#  or more contributor license agreements.  See the NOTICE file
#  distributed with this work for additional information
#  regarding copyright ownership.  The ASF licenses this file
#  to you under the Apache License, Version 2.0 (the
#  "License"); you may not use this file except in compliance
#  with the License.  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.



# This is a slightly modified version of:
# https://github.com/apache/trafficserver/blob/19dfdd4753232d0b77ca555f7ef5f5ba3d2ccae1/tools/build_h3_tools.sh
#
# This present script been modified from the latter in the following ways:
#
# * This version checks out specific commits of the repos so that people
#   creating images from the corresponding Dockerfile do not get different
#   versions of these over time.
#
# * It also doesn't run sudo since the Dockerfile will run this as root.


set -e

# Update this as the draft we support updates.
OPENSSL_BRANCH=${OPENSSL_BRANCH:-"OpenSSL_1_1_1q+quic"}

# Set these, if desired, to change these to your preferred installation
# directory
BASE=${BASE:-"/opt"}
OPENSSL_BASE=${OPENSSL_BASE:-"${BASE}/openssl-quic"}
OPENSSL_PREFIX=${OPENSSL_PREFIX:-"${OPENSSL_BASE}-${OPENSSL_BRANCH}"}
MAKE="make"

# These are for Linux like systems, specially the LDFLAGS, also depends on dirs above
CFLAGS=${CFLAGS:-"-O3 -g"}
CXXFLAGS=${CXXFLAGS:-"-O3 -g"}
LDFLAGS=${LDFLAGS:-"-Wl,-rpath=${OPENSSL_PREFIX}/lib"}

if [ -e /etc/redhat-release ]; then
    MAKE="gmake"
    echo "+-------------------------------------------------------------------------+"
    echo "| You probably need to run this, or something like this, for your system: |"
    echo "|                                                                         |"
    echo "|   sudo yum -y install libev-devel jemalloc-devel python2-devel          |"
    echo "|   sudo yum -y install libxml2-devel c-ares-devel libevent-devel         |"
    echo "|   sudo yum -y install jansson-devel zlib-devel systemd-devel            |"
    echo "+-------------------------------------------------------------------------+"
    echo
    echo
elif [ -e /etc/debian_version ]; then
    echo "+-------------------------------------------------------------------------+"
    echo "| You probably need to run this, or something like this, for your system: |"
    echo "|                                                                         |"
    echo "|   sudo apt -y install libev-dev libjemalloc-dev python2-dev libxml2-dev |"
    echo "|   sudo apt -y install libpython2-dev libc-ares-dev libsystemd-dev       |"
    echo "|   sudo apt -y install libevent-dev libjansson-dev zlib1g-dev            |"
    echo "+-------------------------------------------------------------------------+"
    echo
    echo
fi

set -x

# OpenSSL needs special hackery ... Only grabbing the branch we need here... Bryan has shit for network.
echo "Building OpenSSL with QUIC support"
[ ! -d openssl-quic ] && git clone -b ${OPENSSL_BRANCH} https://github.com/quictls/openssl.git openssl-quic
cd openssl-quic
git checkout f105ac0bfdae1ce009b8fd86bc6d9f65e5576352
./config enable-tls1_3 --prefix=${OPENSSL_PREFIX}
${MAKE} -j $(nproc)
${MAKE} install_sw

# The symlink target provides a more convenient path for the user while also
# providing, in the symlink source, the precise branch of the OpenSSL build.
ln -sf ${OPENSSL_PREFIX} ${OPENSSL_BASE}
cd ..

# Then nghttp3
echo "Building nghttp3..."
[ ! -d nghttp3 ] && git clone https://github.com/ngtcp2/nghttp3.git
cd nghttp3
git checkout 635a532c8ff98cdbd6c141f85583632919102912
autoreconf -if
./configure \
  --prefix=${BASE} \
  PKG_CONFIG_PATH=${BASE}/lib/pkgconfig:${OPENSSL_PREFIX}/lib/pkgconfig \
  CFLAGS="${CFLAGS}" \
  CXXFLAGS="${CXXFLAGS}" \
  LDFLAGS="${LDFLAGS}" \
  --enable-lib-only
${MAKE} -j $(nproc)
${MAKE} install
cd ..

# Now ngtcp2
echo "Building ngtcp2..."
[ ! -d ngtcp2 ] && git clone https://github.com/ngtcp2/ngtcp2.git
cd ngtcp2
git checkout ee8efbe9aa7f209f483e2fe1e78183e62cd166cb
autoreconf -if
./configure \
  --prefix=${BASE} \
  PKG_CONFIG_PATH=${BASE}/lib/pkgconfig:${OPENSSL_PREFIX}/lib/pkgconfig \
  CFLAGS="${CFLAGS}" \
  CXXFLAGS="${CXXFLAGS}" \
  LDFLAGS="${LDFLAGS}" \
  --enable-lib-only
${MAKE} -j $(nproc)
${MAKE} install
cd ..

# Then nghttp2, with support for H3
echo "Building nghttp2 ..."
[ ! -d nghttp2 ] && git clone https://github.com/tatsuhiro-t/nghttp2.git
cd nghttp2

# This commit will be removed whenever the nghttp2 author rebases origin/quic.
# For reference, this commit is currently described as:
#
# commit 1340b296dde152fb0771f1eb4e4c221047d37ab7 (HEAD -> master, origin/master, origin/HEAD)
# Merge: f919cf1a fc5a020b
# Author: Tatsuhiro Tsujikawa <404610+tatsuhiro-t@users.noreply.github.com>
# Date:   Mon Aug 29 21:22:56 2022 +0900
#
#     Merge pull request #1787 from heitbaum/patch-1
#
#     Fix typographic error
git checkout 1340b296dde152fb0771f1eb4e4c221047d37ab7

autoreconf -if
./configure \
  --prefix=${BASE} \
  PKG_CONFIG_PATH=${BASE}/lib/pkgconfig:${OPENSSL_PREFIX}/lib/pkgconfig \
  CFLAGS="${CFLAGS}" \
  CXXFLAGS="${CXXFLAGS}" \
  LDFLAGS="${LDFLAGS}" \
  --enable-lib-only
${MAKE} -j $(nproc)
${MAKE} install
cd ..

# And finally curl
echo "Building curl ..."
[ ! -d curl ] && git clone https://github.com/curl/curl.git
cd curl
git checkout 2fc031d834d488854ffc58bf7dbcef7fa7c1fc28
autoreconf -i
./configure \
  --prefix=${BASE} \
  --with-ssl=${OPENSSL_PREFIX} \
  --with-nghttp2=${BASE} \
  --with-nghttp3=${BASE} \
  --with-ngtcp2=${BASE} \
  CFLAGS="${CFLAGS}" \
  CXXFLAGS="${CXXFLAGS}" \
  LDFLAGS="${LDFLAGS}"
${MAKE} -j $(nproc)
${MAKE} install
