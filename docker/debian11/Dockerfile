# syntax=docker/dockerfile:1

FROM debian:11

RUN <<EOF /bin/bash
  set -ex
  export DEBIAN_FRONTEND=noninteractive
  apt-get -y update
  apt-get -y install build-essential llvm ccache \
    make pkgconf bison flex g++ clang gettext libc++-dev autoconf automake \
    libtool autotools-dev git distcc file wget openssl hwloc intltool-debian \
    ninja-build

  apt-get -y install libssl-dev libexpat1-dev \
    libpcre3-dev libcap-dev libhwloc-dev libunwind8 libunwind-dev zlib1g-dev \
    libmaxminddb-dev libjemalloc-dev libluajit-5.1-dev liblzma-dev \
    libhiredis-dev libncurses-dev libgeoip-dev libmagick++-dev

  apt-get -y autoremove
  apt-get -y clean
EOF

RUN <<EOF
    set -e
    cd /root
    wget https://github.com/Kitware/CMake/releases/download/v3.27.7/cmake-3.27.7-linux-x86_64.sh
    chmod +x cmake-3.27.7-linux-x86_64.sh
    bash ./cmake-3.27.7-linux-x86_64.sh --skip-license --prefix=/opt
    rm cmake-3.27.7-linux-x86_64.sh
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

# We put our custom packages in /opt and we want to use the llvm clang-12.
RUN <<EOF
  set -e
  mkdir -p /opt/bin
  chmod 755 /opt/bin
  echo 'PATH=/opt/bin:$PATH' | tee -a /etc/bash.bashrc
EOF
ARG PATH=/opt/bin:$PATH
