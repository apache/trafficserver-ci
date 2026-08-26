FROM ubuntu:26.04

ENV DEBIAN_FRONTEND=noninteractive

RUN <<EOF
    set -eux

    apt-get update

    apt-get install -y --no-install-recommends \
        build-essential \
        cmake \
        ninja-build \
        ccache \
        pkgconf \
        bison \
        flex \
        gettext \
        autoconf \
        automake \
        autotools-dev \
        libtool \
        clang \
        clang-tools \
        clang-tidy \
        llvm \
        lld \
        libc++-dev \
        libclang-rt-dev \
        cppcheck \
        abigail-tools \
        git \
        distcc \
        file \
        wget \
        ca-certificates \
        openssl \
        hwloc \
        intltool-debian \
        sudo \
        libssl-dev \
        libjitterentropy3-dev \
        libexpat1-dev \
        libpcre2-dev \
        libcap-dev \
        libhwloc-dev \
        libunwind-dev \
        zlib1g-dev \
        libzstd-dev \
        libjemalloc-dev \
        libluajit-5.1-dev \
        liblzma-dev \
        libhiredis-dev \
        libbrotli-dev \
        libncurses-dev \
        libgeoip-dev \
        libmagick++-dev \
        libmaxminddb-dev \
        libcjose-dev \
        libjansson-dev

    apt-get clean
    rm -rf /var/lib/apt/lists/*
EOF

# We put our custom packages in /opt.
RUN install -d -m 0755 /opt/bin

ENV PATH="/opt/bin:${PATH}"

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
