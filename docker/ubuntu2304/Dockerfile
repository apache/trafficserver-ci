FROM ubuntu:23.04

ENV DEBIAN_FRONTEND=noninteractive

RUN <<EOF
    set -e

    apt-get update

    apt-get -y install build-essential llvm lld ccache \
    make pkgconf bison flex g++ clang gettext libc++-dev autoconf automake \
    libtool autotools-dev git distcc file wget openssl hwloc intltool-debian \
    clang-tools-14 clang-14 cmake ninja-build

    apt-get -y install libssl-dev libexpat1-dev \
    libpcre3-dev libcap-dev libhwloc-dev libunwind8 libunwind-dev zlib1g-dev \
    libjemalloc-dev libluajit-5.1-dev liblzma-dev \
    libhiredis-dev libbrotli-dev libncurses-dev libgeoip-dev libmagick++-dev \
    libmaxminddb-dev libcjose-dev libcjose0 libjansson-dev

    apt-get -y autoremove; apt-get -y clean
EOF
