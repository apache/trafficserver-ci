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
OPENSSL_BRANCH=${OPENSSL_BRANCH:-"OpenSSL_1_1_1t+quic"}

# Set these, if desired, to change these to your preferred installation
# directory
BASE=${BASE:-"/opt"}
OPENSSL_BASE=${OPENSSL_BASE:-"${BASE}/openssl-quic"}
OPENSSL_PREFIX=${OPENSSL_PREFIX:-"${OPENSSL_BASE}-${OPENSSL_BRANCH}"}
MAKE="make"

# These are for Linux like systems, specially the LDFLAGS, also depends on dirs above
CFLAGS=${CFLAGS:-"-O3 -g"}
CXXFLAGS=${CXXFLAGS:-"-O3 -g"}
LDFLAGS=${LDFLAGS:-"-Wl,-rpath,${OPENSSL_PREFIX}/lib"}

if [ -e /etc/redhat-release ]; then
    MAKE="gmake"
    TMP_QUICHE_BSSL_PATH="${BASE}/boringssl/lib64"
    echo "+-------------------------------------------------------------------------+"
    echo "| You probably need to run this, or something like this, for your system: |"
    echo "|                                                                         |"
    echo "|   sudo yum -y install libev-devel jemalloc-devel python2-devel          |"
    echo "|   sudo yum -y install libxml2-devel c-ares-devel libevent-devel         |"
    echo "|   sudo yum -y install jansson-devel zlib-devel systemd-devel cargo      |"
    echo "|                                                                         |"
    echo "| Rust may be needed too, see https://rustup.rs for the details           |"
    echo "+-------------------------------------------------------------------------+"
    echo
    echo
elif [ -e /etc/debian_version ]; then
    TMP_QUICHE_BSSL_PATH="${BASE}/boringssl/lib"
    echo "+-------------------------------------------------------------------------+"
    echo "| You probably need to run this, or something like this, for your system: |"
    echo "|                                                                         |"
    echo "|   sudo apt -y install libev-dev libjemalloc-dev python2-dev libxml2-dev |"
    echo "|   sudo apt -y install libpython2-dev libc-ares-dev libsystemd-dev       |"
    echo "|   sudo apt -y install libevent-dev libjansson-dev zlib1g-dev cargo      |"
    echo "|                                                                         |"
    echo "| Rust may be needed too, see https://rustup.rs for the details           |"
    echo "+-------------------------------------------------------------------------+"
    echo
    echo
fi

if [ -z ${QUICHE_BSSL_PATH+x} ]; then
   QUICHE_BSSL_PATH=${TMP_QUICHE_BSSL_PATH:-"${BASE}/boringssl/lib"}
fi

set -x
if [ `uname -s` = "Linux" ]
then
  num_threads=$(nproc)
else
  # MacOS.
  num_threads=$(sysctl -n hw.logicalcpu)
fi

# boringssl
echo "Building boringssl..."

# We need this go version.
mkdir -p ${BASE}/go

if [ `uname -m` = "arm64" -o `uname -m` = "aarch64" ]; then
    ARCH="arm64"
else
    ARCH="amd64"
fi

if [ `uname -s` = "Darwin" ]; then
    OS="darwin"
else
    OS="linux"
fi

wget https://go.dev/dl/go1.20.1.${OS}-${ARCH}.tar.gz
rm -rf ${BASE}/go && tar -C ${BASE} -xf go1.20.1.${OS}-${ARCH}.tar.gz
rm go1.20.1.${OS}-${ARCH}.tar.gz

GO_BINARY_PATH=${BASE}/go/bin/go
if [ ! -d boringssl ]; then
  git clone https://boringssl.googlesource.com/boringssl
  cd boringssl
  git checkout 31bad2514d21f6207f3925ba56754611c462a873
  cd ..
fi
cd boringssl
mkdir -p build
cd build
cmake \
  -DGO_EXECUTABLE=${GO_BINARY_PATH} \
  -DCMAKE_INSTALL_PREFIX=${BASE}/boringssl \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=1 ../

${MAKE} -j ${num_threads}
${MAKE} install
cd ..

# Build quiche
# Steps borrowed from: https://github.com/apache/trafficserver-ci/blob/main/docker/rockylinux8/Dockerfile
echo "Building quiche"
# Install the latest rust.
mkdir -p src
wget https://sh.rustup.rs -O src/rustup.sh
bash src/rustup.sh -y
source /root/.cargo/env
QUICHE_BASE="${BASE:-/opt}/quiche"
[ ! -d quiche ] && git clone --recursive https://github.com/cloudflare/quiche.git
cd quiche
git checkout 0b37da1cc564e40749ba650febd40586a4355be4
QUICHE_BSSL_PATH=${QUICHE_BSSL_PATH} QUICHE_BSSL_LINK_KIND=dylib cargo build -j4 --package quiche --release --features ffi,pkg-config-meta,qlog
mkdir -p ${QUICHE_BASE}/lib/pkgconfig
mkdir -p ${QUICHE_BASE}/include
cp target/release/libquiche.a ${QUICHE_BASE}/lib/
[ -f target/release/libquiche.so ] && cp target/release/libquiche.so ${QUICHE_BASE}/lib/
cp quiche/include/quiche.h ${QUICHE_BASE}/include/
cp target/release/quiche.pc ${QUICHE_BASE}/lib/pkgconfig
cd ..

# OpenSSL needs special hackery ... Only grabbing the branch we need here... Bryan has shit for network.
echo "Building OpenSSL with QUIC support"
[ ! -d openssl-quic ] && git clone -b ${OPENSSL_BRANCH} --depth 1 https://github.com/quictls/openssl.git openssl-quic
cd openssl-quic
git checkout c3f5f36f5dadfa334119e940b7576a4abfa428c8
./config enable-tls1_3 --prefix=${OPENSSL_PREFIX}
${MAKE} -j ${num_threads}
${MAKE} -j install

# The symlink target provides a more convenient path for the user while also
# providing, in the symlink source, the precise branch of the OpenSSL build.
ln -sf ${OPENSSL_PREFIX} ${OPENSSL_BASE}
cd ..

# Then nghttp3
echo "Building nghttp3..."
if [ ! -d nghttp3 ]; then
  git clone https://github.com/ngtcp2/nghttp3.git
  cd nghttp3
  git checkout -b v0.9.0 v0.9.0
  cd ..
fi
cd nghttp3
autoreconf -if
./configure \
  --prefix=${BASE} \
  PKG_CONFIG_PATH=${BASE}/lib/pkgconfig:${OPENSSL_PREFIX}/lib/pkgconfig \
  CFLAGS="${CFLAGS}" \
  CXXFLAGS="${CXXFLAGS}" \
  LDFLAGS="${LDFLAGS}" \
  --enable-lib-only
${MAKE} -j ${num_threads}
${MAKE} install
cd ..

# Now ngtcp2
echo "Building ngtcp2..."
if [ ! -d ngtcp2 ]; then
  git clone https://github.com/ngtcp2/ngtcp2.git
  cd ngtcp2
  git checkout -b v0.13.1 v0.13.1
  cd ..
fi
cd ngtcp2
autoreconf -if
./configure \
  --prefix=${BASE} \
  PKG_CONFIG_PATH=${BASE}/lib/pkgconfig:${OPENSSL_PREFIX}/lib/pkgconfig \
  CFLAGS="${CFLAGS}" \
  CXXFLAGS="${CXXFLAGS}" \
  LDFLAGS="${LDFLAGS}" \
  --enable-lib-only
${MAKE} -j ${num_threads}
${MAKE} install
cd ..

# Then nghttp2, with support for H3
echo "Building nghttp2 ..."
if [ ! -d nghttp2 ]; then
  git clone https://github.com/tatsuhiro-t/nghttp2.git
  cd nghttp2
  git checkout -b v1.52.0 v1.52.0
  cd ..
fi
cd nghttp2
autoreconf -if
if [ `uname -s` = "Darwin" ]
then
  # --enable-app requires systemd which is not available on Mac.
  ENABLE_APP=""
else
  ENABLE_APP="--enable-app"
fi
./configure \
  --prefix=${BASE} \
  PKG_CONFIG_PATH=${BASE}/lib/pkgconfig:${OPENSSL_PREFIX}/lib/pkgconfig \
  CFLAGS="${CFLAGS}" \
  CXXFLAGS="${CXXFLAGS}" \
  LDFLAGS="${LDFLAGS}" \
  --enable-http3 \
  ${ENABLE_APP}
${MAKE} -j ${num_threads}
${MAKE} install
cd ..

# Then curl
echo "Building curl ..."
[ ! -d curl ] && git clone --branch curl-7_88_1 https://github.com/curl/curl.git
cd curl
# On mac autoreconf fails on the first attempt with an issue finding ltmain.sh.
# The second runs fine.
autoreconf -fi || autoreconf -fi
./configure \
  --prefix=${BASE} \
  --with-ssl=${OPENSSL_PREFIX} \
  --with-nghttp2=${BASE} \
  --with-nghttp3=${BASE} \
  --with-ngtcp2=${BASE} \
  CFLAGS="${CFLAGS}" \
  CXXFLAGS="${CXXFLAGS}" \
  LDFLAGS="${LDFLAGS}"
${MAKE} -j ${num_threads}
${MAKE} install
cd ..
