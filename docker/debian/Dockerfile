# syntax=docker/dockerfile:1

FROM debian:12

RUN <<EOT /bin/bash
  set -ex
  export DEBIAN_FRONTEND=noninteractive
  apt-get -y update
  apt-get -y install build-essential llvm ccache \
    make pkgconf bison flex g++ clang gettext libc++-dev autoconf automake \
    libtool autotools-dev git distcc file wget openssl hwloc intltool-debian \
    cmake ninja-build

  apt-get -y install libssl-dev libexpat1-dev \
    libpcre3-dev libcap-dev libhwloc-dev libunwind8 libunwind-dev zlib1g-dev \
    libjemalloc-dev libluajit-5.1-dev liblzma-dev \
    libhiredis-dev libncurses-dev libgeoip-dev libmagick++-dev

  apt-get -y autoremove
  apt-get -y clean
EOT
