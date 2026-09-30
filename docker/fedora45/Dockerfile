FROM fedora:45 AS build

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
    sudo git rpm-build distcc-server file wget which openssl hwloc \
    nghttp2 libnghttp2-devel fmt fmt-devel pcre2-devel

  # Devel packages that ATS needs
  dnf -y install \
    openssl-devel expat-devel libcap-devel hwloc-devel libunwind-devel \
    xz-devel libcurl-devel ncurses-devel jemalloc-devel GeoIP-devel luajit-devel brotli-devel \
    ImageMagick-devel ImageMagick-c++-devel hiredis-devel zlib-devel libmaxminddb-devel \
    perl-ExtUtils-MakeMaker perl-Digest-SHA perl-URI perl-IPC-Cmd perl-Pod-Html perl-Time-Piece \
    curl tcl-devel java cjose-devel protobuf-devel libzstd-devel lz4-devel

  # Needed to build the BoringSSL HTTP/3 clients.
  dnf -y install libev-devel jemalloc-devel libxml2-devel \
    c-ares-devel libevent-devel cjose-devel jansson-devel zlib-devel \
    systemd-devel perl-FindBin cargo

  # build_h3_tools will install its own version of golang.
  dnf remove -y golang

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

#-------------------------------------------------------------------------------
# Install the BoringSSL HTTP/3 build tools.
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

  # NuRaft bundles Asio 1.24, which is incompatible with OpenSSL 4.
  # Fedora's zlib CMake config also imports the separately packaged archive.
  dnf -y install asio-devel zlib-static
  dnf clean all

  git clone https://github.com/eBay/NuRaft.git
  cd NuRaft

  cmake \
    -B build \
    -G Ninja \
    -DCMAKE_INSTALL_PREFIX=/opt/ \
    -DASIO_INCLUDE_DIR=/usr/include \
    -DOPENSSL_SSL_LIBRARY=/usr/lib64/libssl.so \
    -DOPENSSL_CRYPTO_LIBRARY=/usr/lib64/libcrypto.so \
    -DOPENSSL_INCLUDE_DIR=/usr/include \
    -DBUILD_TESTING=OFF \
    -DBUILD_EXAMPLES=OFF
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
  wget https://github.com/open-telemetry/opentelemetry-cpp/archive/refs/tags/v1.19.0.tar.gz
  tar zxf v1.19.0.tar.gz
  cd opentelemetry-cpp-1.19.0
  cmake -B build -G Ninja -DBUILD_TESTING=OFF -DWITH_EXAMPLES=OFF -DBUILD_SHARED_LIBS=OFF -DWITH_OTLP_GRPC=OFF -DWITH_OTLP_HTTP=ON -DCMAKE_POSITION_INDEPENDENT_CODE=ON -DCMAKE_CXX_STANDARD=17 -DCMAKE_CXX_STANDARD_REQUIRED=ON -DWITH_ABSEIL=OFF
  cmake --build build --config Release --verbose
  cmake --install build --prefix /opt

  OTEL_LIBDIR=$(find /opt/lib /opt/lib64 -type f -name libopentelemetry_exporter_otlp_http_log.a -printf '%h\n' -quit)
  test -n "${OTEL_LIBDIR}"
  for library in \
    opentelemetry_exporter_ostream_span \
    opentelemetry_exporter_otlp_http \
    opentelemetry_exporter_otlp_http_client \
    opentelemetry_exporter_otlp_http_log \
    opentelemetry_exporter_otlp_http_metric \
    opentelemetry_http_client_curl \
    opentelemetry_metrics \
    opentelemetry_otlp_recordable \
    opentelemetry_proto \
    opentelemetry_resources \
    opentelemetry_trace \
    opentelemetry_version \
    opentelemetry_common \
    opentelemetry_logs
  do
    test -f "${OTEL_LIBDIR}/lib${library}.a"
  done
  test -f /opt/include/opentelemetry/version.h

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
  wget https://github.com/bytecodealliance/wasm-micro-runtime/archive/refs/tags/WAMR-2.1.1.tar.gz
  tar zxvf WAMR-2.1.1.tar.gz

  # Build WAMR.
  cd wasm-micro-runtime-WAMR-2.1.1
  cp core/iwasm/include/* ${BASE}/include/
  cd product-mini/platforms/linux
  cmake -B build -G Ninja -DCMAKE_INSTALL_PREFIX=${BASE} -DWAMR_BUILD_INTERP=1 -DWAMR_BUILD_FAST_INTERP=1 -DWAMR_BUILD_JIT=0 -DWAMR_BUILD_AOT=0 -DWAMR_BUILD_SIMD=0 -DWAMR_BUILD_MULTI_MODULE=1 -DWAMR_BUILD_LIBC_WASI=0 -DWAMR_BUILD_TAIL_CALL=1 -DWAMR_DISABLE_HW_BOUND_CHECK=1 -DWAMR_BUILD_BULK_MEMORY=1 -DWAMR_BUILD_WASM_CACHE=0
  cmake --build build
  sudo cmake --install build
  test -f ${BASE}/include/wasm_c_api.h
  test -f ${BASE}/lib/libiwasm.so
  grep -q WASM_EXTERNREF ${BASE}/include/wasm_export.h

  # WAMR Cleanup.
  cd /var/tmp
  rm -rf ${build_dir}
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

FROM fedora:45

RUN <<EOF
  set -e

  dnf repolist
  dnf -y update

  # Build tools.
  dnf -y install \
    ccache make pkgconfig bison flex gcc-c++ clang \
    autoconf automake libtool \
    cmake ninja-build

  # Various other tools
  dnf -y install \
    sudo git rpm-build distcc-server file wget which openssl hwloc \
    fmt fmt-devel pcre2-devel

  # Devel packages that ATS needs
  dnf -y install \
    openssl-devel expat-devel libcap-devel hwloc-devel libunwind-devel \
    xz-devel libcurl-devel ncurses-devel jemalloc-devel GeoIP-devel luajit-devel brotli-devel \
    ImageMagick-devel ImageMagick-c++-devel hiredis-devel zlib-devel libmaxminddb-devel \
    perl-ExtUtils-MakeMaker perl-Digest-SHA perl-URI perl-IPC-Cmd perl-Pod-Html \
    curl tcl-devel java cjose-devel protobuf-devel antlr4-cpp-runtime-devel antlr4 libzstd-devel lz4-devel

  # lcov is used for code coverage.
  dnf install -y lcov

  # autest stuff
  dnf -y install \
    bpftrace python3 httpd-tools procps-ng nghttp2 nmap-ncat python3-pip \
    python3-gunicorn python3-requests python3-devel python3-psutil telnet jq

  dnf clean all
EOF

# The protobuf CMake config loads zlib targets, including its static archive.
RUN dnf -y install zlib-static && dnf clean all

RUN pip3 install pipenv httpbin
RUN export XDG_BIN_HOME=/opt/bin && curl -LsSf https://astral.sh/uv/install.sh | sh

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

COPY --from=build /opt /opt

RUN <<EOF
  set -e
  for tool in /opt/h3-tools-boringssl/bin/*
  do
    case "$(basename "${tool}")" in
      curl|curl-config)
        continue
        ;;
    esac
    if [ -x "${tool}" ]; then
      ln -sf "${tool}" /opt/bin/
    fi
  done
EOF

# Older ATS branches require PCRE1, which Fedora 45 no longer packages.
RUN <<EOF
  set -eux

  cd /tmp
  wget -O pcre-8.45.tar.gz https://downloads.sourceforge.net/project/pcre/pcre/8.45/pcre-8.45.tar.gz
  echo "4e6ce03e0336e8b4a3d6c2b70b1c5e18590a5673a98186da90d4f33c23defc09  pcre-8.45.tar.gz" | sha256sum -c -
  tar -xzf pcre-8.45.tar.gz
  cd pcre-8.45
  ./configure --prefix=/usr/local --enable-jit --enable-utf --enable-unicode-properties
  make -j$(nproc)
  make check
  make install
  echo /usr/local/lib > /etc/ld.so.conf.d/pcre.conf
  ldconfig
  cd /tmp
  rm -rf pcre-8.45 pcre-8.45.tar.gz
EOF

ENV PKG_CONFIG_PATH="/usr/local/lib/pkgconfig"
ENV PATH="$PATH:/opt/bin"
