FROM centos:7

RUN yum -y install epel-release dnf-plugins-core; yum config-manager --set-enabled powertools; yum repolist; \

    yum -y update; \
    # Compilers
    yum -y install ccache make pkgconfig bison flex gcc-c++ clang \
    # Autoconf
    autoconf automake libtool \
    # Various other tools
    sudo git rpm-build distcc-server file wget openssl hwloc nghttp2 libnghttp2-devel; \
    # Devel packages that ATS needs
    yum -y install openssl-devel expat-devel pcre-devel libcap-devel hwloc-devel libunwind-devel \
    xz-devel libcurl-devel ncurses-devel jemalloc-devel GeoIP-devel luajit-devel brotli-devel \
    ImageMagick-devel ImageMagick-c++-devel hiredis-devel zlib-devel libmaxminddb-devel \
    perl-ExtUtils-MakeMaker perl-Digest-SHA perl-URI curl tcl-devel java \
    openssl11-libs openssl11 openssl11-devel; \
    # autest stuff
    yum -y install python3 httpd-tools procps-ng nmap-ncat python3-pip \
    python3-gunicorn python3-requests python3-devel python3-psutil telnet;

# Setup openssl11
RUN mkdir /opt/openssl11 \
    && ln -s /usr/lib64/openssl11 /opt/openssl11/lib \
    && ln -s /usr/include/openssl11 /opt/openssl11/include

RUN pip3 install --upgrade pip
RUN pip3 install pipenv httpbin
RUN \
  yum install -y centos-release-scl; \
  yum -y install devtoolset-8 devtoolset-10 devtoolset-11 devtoolset-9-libasan-devel

# We put our custom packages in /opt.
RUN echo 'PATH=/opt/bin:$PATH' | tee -a /etc/profile.d/opt_bin.sh
ARG PATH=/opt/bin:$PATH

# Install a recent cmake.
RUN yum remove -y cmake
RUN \
  wget https://github.com/Kitware/CMake/releases/download/v3.26.3/cmake-3.26.3-linux-x86_64.sh; \
  chmod +x cmake-3.26.3-linux-x86_64.sh; \
  bash ./cmake-3.26.3-linux-x86_64.sh --skip-license --prefix=/opt

# Install openssl-quic
RUN yum install -y rh-python38 cargo
RUN yum -y install libev-devel jemalloc-devel libxml2-devel \
    c-ares-devel libevent-devel jansson-devel zlib-devel systemd-devel

# go and rust will be installed by build_h3_tools.
RUN yum remove -y golang rust
ARG h3_tools_dir=/root/build_h3_tools
RUN mkdir -p ${h3_tools_dir}
WORKDIR ${h3_tools_dir}
COPY /build_h3_tools.sh ${h3_tools_dir}/build_h3_tools.sh
# This will install OpenSSL QUIC and related tools in /opt.
RUN \
  source /opt/rh/devtoolset-11/enable; \
  source /opt/rh/rh-python38/enable; \
  export PATH=/opt/bin:${PATH}; \
  bash ${h3_tools_dir}/build_h3_tools.sh; \
  rm -rf ${h3_tools_dir} /root/.rustup

WORKDIR /root

# Install some of our needed go applications.
RUN echo 'export PATH=$PATH:/opt/go/bin' | tee -a /etc/profile.d/go.sh
RUN echo 'export GOBIN=/opt/go/bin' | tee -a /etc/profile.d/go.sh
RUN \
  /opt/go/bin/go install github.com/summerwind/h2spec/cmd/h2spec@latest; \
  cp /root/go/bin/h2spec /opt/go/bin/

RUN \
  /opt/go/bin/go install github.com/mccutchen/go-httpbin/v2/cmd/go-httpbin@v2.6.0; \
  cp /root/go/bin/go-httpbin /opt/go/bin/

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
    -DCMAKE_INSTALL_PREFIX=/opt/ \
    -DOPENSSL_LIBRARY_PATH=${OPENSSL_LIB} \
    -DOPENSSL_INCLUDE_PATH=${OPENSSL_PREFIX}/include
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
RUN useradd \
    --home-dir /home/${username} \
    --groups users,wheel \
    --uid ${uid} \
    --shell /bin/bash \
    --create-home \
    ${username}
RUN echo "${username} ALL=(ALL:ALL) NOPASSWD:ALL" >> /etc/sudoers
RUN chown -R ${username} /home/${username}

# Install lcov requirements.
RUN yum install -y perl-IO-Compress
ARG lcov_build_dir=/var/tmp/lcov_build_dir
RUN mkdir -p ${lcov_build_dir}
WORKDIR ${lcov_build_dir}
RUN \
    source /opt/rh/devtoolset-11/enable; \
    source /opt/rh/rh-python38/enable; \
    git clone https://github.com/linux-test-project/lcov.git; \
    cd lcov; \
    # v1.15 is required for g++ version 9 compiled files.
    git checkout v1.15; \
    make install
WORKDIR /root
RUN rm -rf ${lcov_build_dir}
RUN yum clean all
