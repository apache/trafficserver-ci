FROM fedora:40

#-------------------------------------------------------------------------------
# Install the various system packages we use.
#
# Try to keep all or at least most dnf commands at the beginning and clean
# afterwards to keep the Docker images smaller.
#-------------------------------------------------------------------------------
RUN <<EOF
  set -e

  dnf -y install dnf-plugins-core
  dnf repolist
  dnf -y update

  # Build tools.
  dnf -y install \
    ccache make pkgconfig bison flex gcc-c++ clang \
    autoconf automake libtool \
    cmake ninja-build

  # Various other tools
  dnf -y install \
    sudo git rpm-build distcc-server file wget openssl hwloc \
    nghttp2 libnghttp2-devel fmt fmt-devel pcre2-devel

  # Devel packages that ATS needs
  dnf -y install \
    openssl-devel expat-devel pcre-devel libcap-devel hwloc-devel libunwind-devel \
    xz-devel libcurl-devel ncurses-devel jemalloc-devel GeoIP-devel luajit-devel brotli-devel \
    ImageMagick-devel ImageMagick-c++-devel hiredis-devel zlib-devel libmaxminddb-devel \
    perl-ExtUtils-MakeMaker perl-Digest-SHA perl-URI perl-IPC-Cmd perl-Pod-Html \
    curl tcl-devel java cjose-devel protobuf-devel

  # autest stuff
  dnf -y install \
    python3 httpd-tools procps-ng nmap-ncat python3-pip \
    python3-gunicorn python3-requests python3-devel python3-psutil telnet

  # Needed to install openssl-quic
  dnf -y install libev-devel jemalloc-devel libxml2-devel \
    c-ares-devel libevent-devel cjose-devel jansson-devel zlib-devel \
    systemd-devel perl-FindBin cargo

  # build_h3_tools will install its own version of golang.
  dnf remove -y golang

  # lcov is used for code coverage.
  dnf install -y lcov

  # abi tool dependencies.
  dnf install -y ctags elfutils-libelf-devel wdiff rfcdiff

  # Cleaning before this RUN command finishes keeps the image size smaller.
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

RUN pip3 install pipenv httpbin

#-------------------------------------------------------------------------------
# Install the HTTP/3 build tools, including openssl-quic.
#-------------------------------------------------------------------------------

# go will be installed by build_h3_tools.
ARG h3_tools_dir=/root/build_h3_tools
RUN mkdir -p ${h3_tools_dir}
COPY build_boringssl_h3_tools.sh ${h3_tools_dir}
# boringssl
RUN <<EOF
  set -e
  cd ${h3_tools_dir}
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

# For Open Telemetry Tracer plugin.
RUN <<EOF
  set -e

  cd /root
  mkdir nlohmann-json
  cd nlohmann-json
  wget https://github.com/nlohmann/json/archive/refs/tags/v3.11.3.tar.gz
  tar zxf v3.11.3.tar.gz
  cd json-3.11.3
  cmake -B build -G Ninja -DCMAKE_CXX_STANDARD=17 -DCMAKE_CXX_STANDARD_REQUIRED=ON -DCMAKE_INSTALL_PREFIX=/opt -DJSON_BuildTests=OFF
  cmake --build build
  cmake --install build
  cd /root
  rm -rf nlohmann-json

  mkdir opentelemetry-cpp
  cd opentelemetry-cpp
  wget https://github.com/open-telemetry/opentelemetry-cpp/archive/refs/tags/v1.3.0.tar.gz
  tar zxf v1.3.0.tar.gz
  cd opentelemetry-cpp-1.3.0
  cmake -B build -G Ninja -DBUILD_TESTING=OFF -DWITH_EXAMPLES=OFF -DWITH_JAEGER=OFF -DWITH_OTLP=ON -DWITH_OTLP_GRPC=OFF -DWITH_OTLP_HTTP=ON -DCMAKE_POSITION_INDEPENDENT_CODE=ON -DCMAKE_CXX_STANDARD=17 -DCMAKE_CXX_STANDARD_REQUIRED=ON -Dnlohmann_json_ROOT=/opt/ -DCMAKE_INSTALL_PREFIX=/opt
  cmake --build build --target all
  cmake --install build --config Debug
  cd /root
  rm -rf opentelemetry-cpp
EOF

# For the proxy wasm plugin.
RUN <<EOF
  set -e

  # WAMR
  BASE=/opt
  build_dir=/var/tmp/wamr_build

  # Get the WAMR source.
  mkdir ${build_dir}
  cd ${build_dir}
  wget https://github.com/bytecodealliance/wasm-micro-runtime/archive/refs/tags/WAMR-1.2.1.tar.gz
  tar zxvf WAMR-1.2.1.tar.gz

  # Build WAMR.
  cd wasm-micro-runtime-WAMR-1.2.1
  cp core/iwasm/include/* ${BASE}/include/
  cd product-mini/platforms/linux
  cmake -B build -G Ninja -DCMAKE_INSTALL_PREFIX=${BASE} -DWAMR_BUILD_INTERP=1 -DWAMR_BUILD_FAST_INTERP=1 -DWAMR_BUILD_JIT=0 -DWAMR_BUILD_AOT=0 -DWAMR_BUILD_SIMD=0 -DWAMR_BUILD_MULTI_MODULE=1 -DWAMR_BUILD_LIBC_WASI=0 -DWAMR_BUILD_TAIL_CALL=1 -DWAMR_DISABLE_HW_BOUND_CHECK=1 -DWAMR_BUILD_BULK_MEMORY=1 -DWAMR_BUILD_WASM_CACHE=0
  cmake --build build
  sudo cmake --install build

  # WAMR Cleanup.
  cd /var/tmp
  rm -rf ${build_dir}
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

# Install abi checking tools.
RUN <<EOF
  set -e
  mkdir -p /root/src/abi
  cd /root/src/abi
  git clone https://github.com/lvc/installer.git
  cd installer
  for i in abi-dumper abi-tracker abi-compliance-checker vtable-dumper abi-monitor
  do
    make install prefix=/opt target=${i}
  done
  cd /root
  rm -rf src/abi
EOF

# Keep this at the end to ensure the dnf cache is cleared out.
RUN dnf clean all
