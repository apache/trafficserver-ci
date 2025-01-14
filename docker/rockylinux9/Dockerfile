FROM rockylinux:9

RUN <<EOF
  set -e
  dnf -y install epel-release dnf-plugins-core
  dnf config-manager --set-enabled crb
  dnf install -y https://rpms.remirepo.net/enterprise/remi-release-9.rpm
  dnf repolist
  dnf -y update

  # Compilers
  dnf -y install \
    ccache make pkgconfig bison flex gcc-c++ clang cmake ninja-build \
    autoconf automake libtool \
    sudo git rpm-build file wget openssl hwloc nghttp2 libnghttp2-devel \
    cargo go-toolset llvm-toolset

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
    curl tcl-devel java

  # autest stuff
  dnf -y install \
    python3 httpd-tools procps-ng nmap-ncat python3-pip \
    python3-gunicorn python3-requests python3-devel python3-psutil telnet golang
EOF

RUN <<EOF
  set -e
  pip3 install --upgrade pip
  pip3 install pipenv httpbin
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

# go and rust will be installed by build_h3_tools.
RUN dnf remove -y golang rust
RUN dnf install -y cargo
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

# Install nuraft for the stek_share plugin. Distros, unfortunately, do not
# package these, so this has to be built by hand.
RUN <<EOF
  set -e

  git clone https://github.com/eBay/NuRaft.git
  cd NuRaft
  ./prepare.sh

  OPENSSL_PREFIX=/opt/openssl-quic
  if [ -d "${OPENSSL_PREFIX}/lib" ]; then
    OPENSSL_LIB="${OPENSSL_PREFIX}/lib"
  elif [ -d "${OPENSSL_PREFIX}/lib64" ]; then
    OPENSSL_LIB="${OPENSSL_PREFIX}/lib64"
  else
    echo "Could not find the OpenSSL install library directory."
    exit 1
  fi
  cmake \
    -B build \
    -G Ninja \
    -DCMAKE_INSTALL_PREFIX=/opt/ \
    -DOPENSSL_LIBRARY_PATH=${OPENSSL_LIB} \
    -DOPENSSL_INCLUDE_PATH=${OPENSSL_PREFIX}/include
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

# Install ABI checking tools.
RUN dnf install -y ctags elfutils-libelf-devel wdiff
COPY /install_abi_tools.sh /root/install_abi_tools.sh
RUN bash /root/install_abi_tools.sh

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
  # reinstall openssl-devel
  dnf install -y openssl-devel
  # Keep this at the end to clean up the yum cache to reduce the image file size.
  dnf clean all
EOF

