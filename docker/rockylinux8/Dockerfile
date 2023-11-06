FROM rockylinux:8

#-------------------------------------------------------------------------------
# Install the various system packages we use.
#-------------------------------------------------------------------------------
RUN <<EOF
  set -e

  yum -y install epel-release dnf-plugins-core
  yum config-manager --set-enabled powertools
  yum repolist
  yum -y update

  # Build tools.
  yum -y install \
    ccache make pkgconfig bison flex gcc-c++ clang cmake ninja-build \
    autoconf automake libtool \
    gcc-toolset-11 gcc-toolset-11-libasan-devel

  # Various other tools
  yum -y install \
    sudo git rpm-build distcc-server file wget openssl hwloc \
    nghttp2 libnghttp2-devel fmt fmt-devel

  # Devel packages that ATS needs
  yum -y install \
    openssl-devel expat-devel pcre-devel libcap-devel hwloc-devel libunwind-devel \
    xz-devel libcurl-devel ncurses-devel jemalloc-devel GeoIP-devel luajit-devel brotli-devel \
    ImageMagick-devel ImageMagick-c++-devel hiredis-devel zlib-devel libmaxminddb-devel \
    perl-ExtUtils-MakeMaker perl-Digest-SHA perl-URI perl-IPC-Cmd perl-Pod-Html \
    curl tcl-devel java

  # autest stuff
  yum -y install \
    python3 httpd-tools procps-ng nmap-ncat python3-pip \
    python3-gunicorn python3-requests python3-devel python3-psutil telnet
EOF

#-------------------------------------------------------------------------------
# Install some custom build tools.
#-------------------------------------------------------------------------------

WORKDIR /root

# We put our custom packages in /opt.
RUN <<EOF
  set -e
  mkdir -p /opt/bin
  chmod 755 /opt/bin
  echo 'PATH=/opt/bin:$PATH' | tee -a /etc/profile.d/opt_bin.sh
EOF
ARG PATH=/opt/bin:$PATH

# Install the latest ninja, which has some performance improvements over the
# older system version.
RUN <<EOF
  set -e
  wget https://github.com/ninja-build/ninja/releases/download/v1.11.1/ninja-linux.zip
  unzip ninja-linux.zip
  cp ninja /opt/bin
  chmod 755 /opt/bin/
  rm -f ninja ninja-linux.zip
EOF

RUN pip3 install --upgrade pip
RUN pip3 install pipenv httpbin

#-------------------------------------------------------------------------------
# Install the HTTP/3 build tools, including openssl-quic.
#-------------------------------------------------------------------------------
RUN <<EOF
  set -e
  yum install -y python38-devel cargo
  alternatives --set python /usr/bin/python3.8
  yum -y install \
    libev-devel jemalloc-devel libxml2-devel \
    c-ares-devel libevent-devel jansson-devel cjose-devel \
    zlib-devel systemd-devel
EOF

# go and rust will be installed by build_h3_tools.
RUN yum remove -y golang rust
ARG h3_tools_dir=/root/build_h3_tools
RUN mkdir -p ${h3_tools_dir}
COPY /build_h3_tools.sh ${h3_tools_dir}/build_h3_tools.sh
# This will install OpenSSL QUIC and related tools in /opt.
RUN <<EOF
  set -e
  cd ${h3_tools_dir}
  bash ${h3_tools_dir}/build_h3_tools.sh

  # Removing the build dir is crucial to keeping the Docker image size
  # reasonable.
  rm -rf ${h3_tools_dir} /root/.rustup
EOF

#-------------------------------------------------------------------------------
# Various CI Job and Test Requirements.
#-------------------------------------------------------------------------------

# Autests require some go applications.
RUN <<EOF
  set -e
  echo 'export PATH=$PATH:/opt/go/bin' | tee -a /etc/profile.d/go.sh
  echo 'export GOBIN=/opt/go/bin' | tee -a /etc/profile.d/go.sh

  /opt/go/bin/go install github.com/summerwind/h2spec/cmd/h2spec@latest
  cp /root/go/bin/h2spec /opt/go/bin/

  /opt/go/bin/go install github.com/mccutchen/go-httpbin/v2/cmd/go-httpbin@v2.6.0
  cp /root/go/bin/go-httpbin /opt/go/bin/
EOF

RUN update-crypto-policies --set LEGACY

# Add the CI's jenkins user.
# N.B: 1200 is the uid that our jenkins user is configured with, so that has to
# be used. Otherwise there will be permissions issues.
ARG username=jenkins
ARG uid=1200
RUN <<EOF
  set -e
  useradd \
    --home-dir /home/${username} \
    --groups users,wheel \
    --uid ${uid} \
    --shell /bin/bash \
    --create-home \
    ${username}
  echo "${username} ALL=(ALL:ALL) NOPASSWD:ALL" >> /etc/sudoers
  chown -R ${username} /home/${username}
EOF

# Install lcov.
RUN yum install -y perl-IO-Compress
ARG lcov_build_dir=/var/tmp/lcov_build_dir
RUN mkdir -p ${lcov_build_dir}
RUN <<EOF
  set -e
  cd ${lcov_build_dir}
  git clone https://github.com/linux-test-project/lcov.git
  cd lcov
  # v1.15 is required for g++ version 9 compiled files.
  git checkout v1.15
  make install
  cd /root
  rm -rf ${lcov_build_dir}
EOF

# Install ABI checking tools.
RUN yum install -y ctags elfutils-libelf-devel wdiff
COPY /install_abi_tools.sh /root/install_abi_tools.sh
RUN bash /root/install_abi_tools.sh

# Keep this at the end to clean up the yum cache.
RUN yum clean all
