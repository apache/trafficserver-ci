FROM ubuntu:20.04

RUN apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get -y install build-essential llvm ccache \
    make pkgconf bison flex g++ clang gettext libc++-dev autoconf automake \
    libtool autotools-dev git distcc file wget openssl hwloc intltool-debian clang-tools-10 clang-10; \

    DEBIAN_FRONTEND=noninteractive apt-get -y install libssl-dev libexpat1-dev \
    libpcre3-dev libcap-dev libhwloc-dev libunwind8 libunwind-dev zlib1g-dev \
    tcl-dev tcl8.6-dev libjemalloc-dev libluajit-5.1-dev liblzma-dev \
    libhiredis-dev libbrotli-dev libncurses-dev libgeoip-dev libmagick++-dev \
    libmaxminddb-dev libcjose-dev libcjose0 libjansson-dev; \
    
    DEBIAN_FRONTEND=noninteractive apt-get autoremove; apt-get clean;

