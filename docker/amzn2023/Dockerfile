FROM amazonlinux:2023

RUN <<EOF
  set -e
  # SPAL (Supplementary Packages for Amazon Linux) is AWS's rebuild of EPEL9 for
  # AL2023. It is load-bearing here: ccache, GeoIP-devel and libgsasl-devel
  # below are not in the AL2023 core repository and resolve only from SPAL.
  #
  # N.B: SPAL packages are not covered by AWS Support Plans and get no AWS CVE
  # tracking; they inherit fixes from upstream EPEL9 only.
  #
  # SPAL needs system-release >= 2023.9.20251117, so update before installing
  # spal-release rather than after.
  dnf -y update
  dnf -y install spal-release dnf-plugins-core
  dnf repolist

  # Compilers
  dnf -y install \
    ccache make pkgconfig bison flex gcc-c++ clang cmake ninja-build \
    autoconf automake libtool \
    sudo git rpm-build file wget openssl hwloc nghttp2 libnghttp2-devel \
    cargo llvm

  # Devel packages that ATS needs.
  #
  # --alowerasing for cur. See:
  # https://bugs.launchpad.net/tripleo/+bug/1953156
  dnf -y install --allowerasing \
    openssl-devel expat-devel pcre-devel pcre2-devel libcap-devel \
    hwloc-devel libunwind-devel xz-devel libcurl-devel ncurses-devel \
    jemalloc-devel GeoIP-devel luajit-devel brotli-devel \
    ImageMagick-devel ImageMagick-c++-devel hiredis-devel zlib-devel \
    libmaxminddb-devel perl-ExtUtils-MakeMaker perl-Digest-SHA \
    perl-URI perl-IPC-Cmd perl-Pod-Html perl-FindBin \
    curl tcl-devel java libzstd-devel lz4-devel

  # autest stuff.
  #
  # N.B: No python3-gunicorn, which AL2023 does not package. That is fine: the
  # autests pull gunicorn in through pipenv from tests/pyproject.toml, where the
  # distro packages are only ever a convenience.
  dnf -y install \
    python3 httpd-tools procps-ng nmap-ncat python3-pip \
    python3-requests python3-devel python3-psutil telnet golang
EOF

RUN <<EOF
  set -e
  # AL2023 marks the system Python environment as externally managed (PEP 668),
  # so a bare `pip install` is refused. Passing --prefix opts out of that check
  # and puts the console scripts in /usr/local/bin and the modules in
  # /usr/local/lib/python3.9/site-packages, both of which are already on the
  # default PATH and sys.path. That is the same place a plain `pip3 install`
  # lands on the Fedora and Rocky images.
  #
  # Do not switch this to --user or --target. Both need PATH and PYTHONPATH
  # fixups that the Jenkins pipelines do not perform, and a global PYTHONPATH
  # would additionally leak these packages into the virtualenvs pipenv creates.
  pip install --prefix=/usr/local pipenv httpbin
  export XDG_BIN_HOME=/opt/bin
  curl -LsSf https://astral.sh/uv/install.sh | sh
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
RUN <<EOF
  set -e
  dnf -y install libev-devel jemalloc-devel libxml2-devel \
    c-ares-devel libevent-devel jansson-devel zlib-devel systemd-devel \
    libpsl-devel libgsasl-devel libidn-devel openldap-devel
EOF

#-------------------------------------------------------------------------------
# Various CI Job and Test Requirements.
#-------------------------------------------------------------------------------

# Autests require some go applications.
#
# N.B: On the other images /opt/go is the Go toolchain that build_h3_tools.sh
# unpacks there. This image does not run that script, so /opt/go/bin holds just
# the built binaries and the toolchain is the distro's golang in /usr/bin.
# Exporting GOBIN puts `go install` output straight into /opt/go/bin, which is
# the directory the pipelines put on PATH.
RUN <<EOF
  set -e
  mkdir -p /opt/go/bin
  chmod -R 755 /opt/go
  echo 'export PATH=$PATH:/opt/go/bin' | tee -a /etc/profile.d/go.sh
  echo 'export GOBIN=/opt/go/bin' | tee -a /etc/profile.d/go.sh

  export GOBIN=/opt/go/bin
  go install github.com/summerwind/h2spec/cmd/h2spec@latest
  go install github.com/mccutchen/go-httpbin/v2/cmd/go-httpbin@v2.6.0
EOF

RUN update-crypto-policies --set LEGACY

# Install nuraft for the stek_share plugin. Distros, unfortunately, do not
# package these, so this has to be built by hand.
#
# NuRaft requests static OpenSSL, but openssl-devel provides shared libraries.
# Select those explicitly so NuRaft can find the system OpenSSL.
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
RUN dnf install -y perl-IO-Compress
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

# N.B: No ABI checking tools on this image, unlike the Fedora and Rocky ones.
# ABI is tracked there, which is reasonable coverage for Amazon Linux too. If an
# ABI job is ever pointed here, note that ABI Tracker needs wdiff by way of
# PkgDiff, and wdiff is in neither AL2023 core nor SPAL, so it would have to be
# built from source.

# Install some tools to test out of source builds.
RUN <<EOF
  set -e
  set -x

  # Retrieve the libswoc version we use in ATS.
  cd /root/
  mkdir libswoc
  cd libswoc
  swoc_version=1.5.13

  # Now, checkout that version and install libswoc in /opt/libswoc
  git clone https://github.com/apache/trafficserver-libswoc.git
  cd trafficserver-libswoc
  git checkout ${swoc_version}
  pipenv install
  pipenv run scons -j`nproc` all
  arch=$(uname -m)
  old_path=/root/libswoc/trafficserver-libswoc/_install/debug_posix-${arch}_default
  cp -rf ${old_path} /opt/libswoc
  chmod 755 /opt/libswoc
  sed -i "s:${old_path}:/opt/libswoc:g" /opt/libswoc/lib/pkgconfig/*.pc
  cd /root/
  rm -rf /root/libswoc

  # Retrieve the yaml-cpp version we use in ATS.
  cd /root/
  mkdir yaml-cpp
  cd yaml-cpp
  wget -O CMakeLists.txt https://raw.githubusercontent.com/apache/trafficserver/master/lib/yamlcpp/CMakeLists.txt
  yaml_version=$(awk '/project/ {print $3}' CMakeLists.txt)

  cd /root/yaml-cpp
  git clone https://github.com/jbeder/yaml-cpp.git
  cd yaml-cpp
  git checkout ${yaml_version}
  cmake -B build -G Ninja -DCMAKE_INSTALL_PREFIX=/opt/yaml-cpp
  cmake --build build
  cmake --install build
  cd /root
  rm -rf yaml-cpp
EOF

RUN <<EOF
  set -e
  # Keep this at the end to clean up the yum cache to reduce the image file size.
  dnf clean all
EOF

