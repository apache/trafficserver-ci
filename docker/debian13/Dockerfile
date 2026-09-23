# syntax=docker/dockerfile:1

FROM debian:13

RUN <<EOF /bin/bash
  set -ex
  export DEBIAN_FRONTEND=noninteractive
  apt-get -y update
  apt-get -y install build-essential llvm ccache \
    make pkgconf bison flex g++ clang gettext libc++-dev autoconf automake \
    libtool autotools-dev git distcc file wget openssl hwloc intltool-debian \
    cmake ninja-build

  apt-get -y install libssl-dev libexpat1-dev \
    libpcre2-dev libcap-dev libhwloc-dev libunwind8 libunwind-dev zlib1g-dev \
    libmaxminddb-dev libjemalloc-dev libluajit-5.1-dev liblzma-dev \
    libhiredis-dev libncurses-dev libgeoip-dev libmagick++-dev \
    libcjose-dev libcjose0 libjansson-dev libzstd-dev liblz4-dev

  apt-get -y autoremove
  apt-get -y clean
EOF

# Older ATS branches require PCRE1, which Debian 13 no longer packages.
RUN <<EOF
  set -eux

  cd /tmp
  wget -O pcre-8.45.tar.gz https://downloads.sourceforge.net/project/pcre/pcre/8.45/pcre-8.45.tar.gz
  echo "4e6ce03e0336e8b4a3d6c2b70b1c5e18590a5673a98186da90d4f33c23defc09  pcre-8.45.tar.gz" | sha256sum -c -
  tar -xzf pcre-8.45.tar.gz
  cd pcre-8.45
  ./configure --prefix=/usr/local --enable-jit --enable-utf --enable-unicode-properties
  make -j$(nproc)
  make check
  make install
  ldconfig
  cd /tmp
  rm -rf pcre-8.45 pcre-8.45.tar.gz
EOF

# Install nuraft for the stek_share plugin. Distros, unfortunately, do not
# package these, so this has to be built by hand.
# NuRaft requests static OpenSSL, whose dependencies on Debian 13 include
# non-PIC libz.a. Use shared OpenSSL to allow linking libnuraft.so on amd64.
RUN <<EOF
  set -e

  OPENSSL_LIBDIR=$(pkg-config --variable=libdir openssl)

  git clone https://github.com/eBay/NuRaft.git
  cd NuRaft
  ./prepare.sh

  cmake \
    -B build \
    -G Ninja \
    -DCMAKE_INSTALL_PREFIX=/opt/ \
    -DOPENSSL_SSL_LIBRARY=${OPENSSL_LIBDIR}/libssl.so \
    -DOPENSSL_CRYPTO_LIBRARY=${OPENSSL_LIBDIR}/libcrypto.so \
    -DOPENSSL_INCLUDE_DIR=/usr/include
  cmake --build build
  cmake --install build
  cd ../
  rm -rf NuRaft
EOF

# Add the CI's test user. N.B: 1200 is the uid that our jenkins user is
# configured with, so that has to be used. Otherwise there will be permissions
# issues.
ARG username=jenkins
ARG uid=1200
RUN <<EOF
  set -e
  useradd \
    --home-dir /home/${username} \
    --groups users,sudo \
    --uid ${uid} \
    --shell /bin/bash \
    --create-home \
    ${username}
  echo "${username} ALL=(ALL:ALL) NOPASSWD:ALL" >> /etc/sudoers
  chown -R ${username} /home/${username}
EOF

# We put our custom packages in /opt.
RUN <<EOF
  set -e
  mkdir -p /opt/bin
  chmod 755 /opt/bin
  echo 'PATH=/opt/bin:$PATH' | tee -a /etc/bash.bashrc
EOF
