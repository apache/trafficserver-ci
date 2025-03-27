FROM rockylinux:8

#-------------------------------------------------------------------------------
# Install the various system packages we use.
#-------------------------------------------------------------------------------
RUN <<EOF
  set -e

  dnf -y install epel-release dnf-plugins-core
  dnf config-manager --set-enabled powertools
  dnf repolist
  dnf -y update

  # Build tools.
  dnf -y install \
    ccache make pkgconfig bison flex gcc-c++ clang cmake ninja-build \
    autoconf automake libtool \
    gcc-toolset-11 gcc-toolset-11-libasan-devel \
    gcc-toolset-14 gcc-toolset-14-libasan-devel

  # build_h3_tools.sh dependencies.
  dnf -y install \
    python3.12-devel \
    libev-devel jemalloc-devel libxml2-devel \
    c-ares-devel libevent-devel jansson-devel cjose-devel \
    zlib-devel systemd-devel

  # Various other tools
  dnf -y install \
    sudo git rpm-build distcc-server file wget openssl hwloc \
    nghttp2 libnghttp2-devel fmt fmt-devel jq

  # Devel packages that ATS needs
  dnf -y install \
    openssl-devel expat-devel pcre-devel pcre2-devel libcap-devel \
    hwloc-devel libunwind-devel xz-devel libcurl-devel ncurses-devel \
    jemalloc-devel GeoIP-devel luajit-devel brotli-devel \
    ImageMagick-devel ImageMagick-c++-devel hiredis-devel zlib-devel \
    libmaxminddb-devel perl-ExtUtils-MakeMaker perl-Digest-SHA \
    perl-URI perl-IPC-Cmd perl-Pod-Html \
    curl tcl-devel java cjose-devel jansson-devel \
    python3.12 python3.12-pip

  # autest stuff
  dnf -y install \
    python3 httpd-tools procps-ng nmap-ncat python3-pip \
    python3-gunicorn python3-requests python3-devel python3-psutil telnet

  # This keeps our Docker layers smaller.
  dnf clean all
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

RUN <<EOF
  set -e
  pip3 install --upgrade pip
  pip3 install pipenv httpbin

  python3.12 -m pip install --upgrade pip
  python3.12 -m pip install pipenv httpbin
EOF

#-------------------------------------------------------------------------------
# Install the HTTP/3 build tools, including openssl-quic.
#-------------------------------------------------------------------------------

ARG h3_tools_dir=/root/build_h3_tools
RUN mkdir -p ${h3_tools_dir}
COPY build_boringssl_h3_tools.sh ${h3_tools_dir}
# boringssl
RUN <<EOF
  set -e
  # go will be installed by build_boringssl_h3_tools.sh
  dnf remove -y golang rust
  dnf install -y cargo
  # This keeps our Docker layers smaller.
  dnf clean all
EOF

RUN <<EOF
  set -e
  cd ${h3_tools_dir}
  source /opt/rh/gcc-toolset-14/enable
  export BASE=/opt/h3-tools-boringssl
  bash ${h3_tools_dir}/build_boringssl_h3_tools.sh
  cd /root
  rm -rf ${h3_tools_dir} /root/.rustup
EOF
# openssl: These are stored in /opt so that CI can easily access the curl,
# h2load, etc., from there.
RUN mkdir -p ${h3_tools_dir}
COPY build_openssl_h3_tools.sh ${h3_tools_dir}
RUN <<EOF
  set -e
  cd ${h3_tools_dir}
  source /opt/rh/gcc-toolset-14/enable
  export BASE=/opt
  bash ${h3_tools_dir}/build_openssl_h3_tools.sh
  cd /root
  rm -rf ${h3_tools_dir} /root/.rustup
EOF

#-------------------------------------------------------------------------------
# Various CI Job and Test Requirements.
#-------------------------------------------------------------------------------

# Autests require some go applications.
RUN <<EOF
  set -e
  ln -s /opt/h3-tools-boringssl/go /opt/go
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
  set -x

  git clone https://github.com/eBay/NuRaft.git
  cd NuRaft
  source /opt/rh/gcc-toolset-14/enable
  ./prepare.sh

  # openssl-quic nuraft
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
    -B build_openssl \
    -G Ninja \
    -DCMAKE_INSTALL_PREFIX=/opt/ \
    -DCMAKE_CXX_STANDARD=17 \
    -DCMAKE_CXX_FLAGS="-Wno-sign-compare" \
    -DOPENSSL_LIBRARY_PATH=${OPENSSL_LIB} \
    -DOPENSSL_INCLUDE_PATH=${OPENSSL_PREFIX}/include
  cmake --build build_openssl
  cmake --install build_openssl

  # boringssl nuraft
  BORINGSSL_PREFIX=/opt/h3-tools-boringssl/boringssl
  BORINGSSL_LIB="${BORINGSSL_PREFIX}/lib"
  if [ -e /etc/redhat-release ]; then
    BORINGSSL_LIB="${BORINGSSL_PREFIX}/lib64"
  fi
  cmake \
    -B build_boringssl \
    -G Ninja \
    -DCMAKE_INSTALL_PREFIX=/opt/nuraft-boringssl \
    -DCMAKE_CXX_STANDARD=17 \
    -DCMAKE_CXX_FLAGS="-Wno-sign-compare" \
    -DOPENSSL_LIBRARY_PATH=${BORINGSSL_LIB} \
    -DOPENSSL_INCLUDE_PATH=${BORINGSSL_PREFIX}/include
  cmake --build build_boringssl
  cmake --install build_boringssl

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
  source /opt/rh/gcc-toolset-14/enable
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

RUN <<EOF
  set -e
  alternatives --set python3 /usr/bin/python3.12
  python3 -m ensurepip --upgrade
  python3 -m pip install --upgrade pip
  python3 -m pip install virtualenv
EOF

# Install some tools to test out of source builds.
RUN <<EOF
  set -e
  set -x

  source /opt/rh/gcc-toolset-14/enable

  # Retrieve the libswoc version we use in ATS.
  cd /root/
  mkdir libswoc
  cd libswoc
  swoc_version=1.5.13

  # Now, checkout that version and install libswoc in /opt/libswoc
  git clone https://github.com/apache/trafficserver-libswoc.git
  cd trafficserver-libswoc
  git checkout ${swoc_version}
  python3.12 -m pipenv install --python python3.12
  python3.12 -m pipenv run scons -j`nproc` all
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

# Keep this at the end to clean up the dnf cache.
RUN dnf clean all
