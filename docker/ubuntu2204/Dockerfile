FROM ubuntu:22.04

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

    apt-get -y autoremove
    apt-get -y clean
EOF

# We put our custom packages in /opt and we want to use the llvm clang-12.
RUN <<EOF
  set -e
  mkdir -p /opt/bin
  chmod 755 /opt/bin
  echo 'PATH=/opt/bin:/usr/lib/llvm-12/bin:$PATH' | tee -a /etc/bash.bashrc
EOF

ARG PATH=/opt/bin:/usr/lib/llvm-12/bin:$PATH

# Install nuraft for the stek_share plugin. Distros, unfortunately, do not
# package these, so this has to be built by hand.
RUN <<EOF
  set -e

  git clone https://github.com/eBay/NuRaft.git
  cd NuRaft
  ./prepare.sh

  cmake \
    -B build \
    -G Ninja \
    -DCMAKE_INSTALL_PREFIX=/opt/
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
