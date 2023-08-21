FROM fedora:39

#-------------------------------------------------------------------------------
# Install the various system packages we use.
#-------------------------------------------------------------------------------
RUN <<EOF
  set -e

  # TODO: Add these back in when fedora:39 hacks aren't needed anymore.
  #dnf -y install dnf-plugins-core
  #dnf repolist
  #dnf -y update

  # Build tools.
  dnf -y install \
    ccache make pkgconfig bison flex gcc-c++ clang \
    autoconf automake libtool \
    cmake ninja-build

  # Various other tools
  dnf -y install \
    sudo git rpm-build distcc-server file wget openssl hwloc \
    nghttp2 libnghttp2-devel fmt fmt-devel

  # Devel packages that ATS needs
  dnf -y install \
    openssl-devel expat-devel pcre-devel libcap-devel hwloc-devel libunwind-devel \
    xz-devel libcurl-devel ncurses-devel jemalloc-devel GeoIP-devel luajit-devel brotli-devel \
    ImageMagick-devel ImageMagick-c++-devel hiredis-devel zlib-devel libmaxminddb-devel \
    perl-ExtUtils-MakeMaker perl-Digest-SHA perl-URI perl-IPC-Cmd perl-Pod-Html \
    curl tcl-devel java

  # autest stuff
  dnf -y install \
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

#-------------------------------------------------------------------------------
# Install the HTTP/3 build tools, including openssl-quic.
#-------------------------------------------------------------------------------
RUN dnf -y install libev-devel jemalloc-devel libxml2-devel \
    c-ares-devel libevent-devel jansson-devel zlib-devel systemd-devel \
    perl-FindBin cargo

# go will be installed by build_h3_tools.
RUN dnf remove -y golang
ARG h3_tools_dir=/root/build_h3_tools
RUN mkdir -p ${h3_tools_dir}
COPY /build_h3_tools.sh ${h3_tools_dir}/build_h3_tools.sh
# This will install OpenSSL QUIC and related tools in /opt.
RUN <<EOF
  set -e
  cd ${h3_tools_dir}
  bash ${h3_tools_dir}/build_h3_tools.sh; \
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

# Add the CI's test user. N.B: 1200 is the uid that our jenkins user is
# configured with, so that has to be used. Otherwise there will be permissions
# issues.
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

# Install lcov
RUN dnf install -y lcov

# Keep this at the end to clean up the dnf cache.
RUN dnf clean all
