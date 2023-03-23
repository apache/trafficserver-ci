FROM rockylinux:8

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
    perl-ExtUtils-MakeMaker perl-Digest-SHA perl-URI curl tcl-devel java; \
    # autest stuff
    yum -y install python3 httpd-tools procps-ng nmap-ncat python3-pip \
    python3-gunicorn python3-requests python3-devel python3-psutil telnet golang;

RUN pip3 install --upgrade pip
RUN pip3 install pipenv httpbin
RUN yum -y install gcc-toolset-11 gcc-toolset-11-libasan-devel

# Install openssl-quic
RUN yum install -y python38-devel
RUN alternatives --set python /usr/bin/python3.8
RUN yum -y install libev-devel jemalloc-devel libxml2-devel \
    c-ares-devel libevent-devel jansson-devel zlib-devel systemd-devel

ARG h3_tools_dir=/root/build_h3_tools
RUN mkdir -p ${h3_tools_dir}
WORKDIR ${h3_tools_dir}
COPY /build_h3_tools.sh ${h3_tools_dir}/build_h3_tools.sh
# This will install OpenSSL QUIC and related tools in /opt.
RUN bash ${h3_tools_dir}/build_h3_tools.sh
WORKDIR /root

# Make sure we pick up this built version of curl, which is in /opt/bin.
RUN echo 'PATH=/opt/bin:$PATH' | tee -a /etc/profile.d/curl_http3.sh

RUN update-crypto-policies --set LEGACY

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
RUN git clone https://github.com/linux-test-project/lcov.git; \
    cd lcov; \
    # v1.15 is required for g++ version 9 compiled files.
    git checkout v1.15; \
    make install
WORKDIR /root
RUN rm -rf ${lcov_build_dir}
RUN yum clean all

# Install ABI checking tools.
RUN yum install -y ctags elfutils-libelf-devel wdiff
COPY /install_abi_tools.sh /root/install_abi_tools.sh
RUN bash /root/install_abi_tools.sh

#-----------------------------
# Install quiche dependencies.
#-----------------------------

RUN yum install -y cmake

# Retrieve quiche
RUN \
  mkdir -p src && \
  cd src && \
  git clone --recursive https://github.com/cloudflare/quiche

# Install rust/cargo.
RUN \
  mkdir -p src && \
  wget https://sh.rustup.rs -O src/rustup.sh && \
  bash src/rustup.sh -y

# Build quiche.
RUN \
  source "/root/.cargo/env" && \
  cd src/quiche && \
  cargo build -j4 --package quiche --release --features ffi,pkg-config-meta,qlog

# Manually install quiche because, unfortunately, the cargo install command
# doesn't work for quiche.
RUN \
  mkdir -p /opt/quiche/lib/pkgconfig && \
  mkdir -p /opt/quiche/include && \
  cp src/quiche/target/release/libquiche.a /opt/quiche/lib && \
  cp src/quiche/target/release/libquiche.so /opt/quiche/lib && \
  cp src/quiche/quiche/include/quiche.h /opt/quiche/include && \
  cp src/quiche/target/release/quiche.pc /opt/quiche/lib/pkgconfig

# Install go and some of our needed go applications.
WORKDIR /root
RUN yum remove -y golang
RUN echo 'export PATH=$PATH:/usr/local/go/bin' | tee -a /etc/profile.d/go.sh
RUN echo 'export GOBIN=/usr/local/go/bin' | tee -a /etc/profile.d/go.sh
RUN wget https://go.dev/dl/go1.20.1.linux-amd64.tar.gz
RUN rm -rf /usr/local/go && sudo tar -C /usr/local -xf go1.20.1.linux-amd64.tar.gz

RUN \
  /usr/local/go/bin/go install github.com/summerwind/h2spec/cmd/h2spec@latest; \
  cp /root/go/bin/h2spec /usr/local/go/bin/

RUN \
  /usr/local/go/bin/go install github.com/mccutchen/go-httpbin/v2/cmd/go-httpbin@v2.5.6; \
  cp /root/go/bin/go-httpbin /usr/local/go/bin/

# BoringSSL has no releases or tags. For Docker image reproducibilty, we pin to
# a particular commit. This should be updated regularly.
RUN \
  cd /root/src; \
  git clone https://github.com/google/boringssl.git; \
  cd boringssl/; \
  git checkout b6a50fd62d1ae44ad211ebe26f803c66db444302; \
  mkdir build; \
  cd build; \
  source /opt/rh/gcc-toolset-11/enable; \
  cmake -DGO_EXECUTABLE=/usr/local/go/bin/go -DCMAKE_INSTALL_PREFIX=/opt/boringssl -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=1 ../; \
  make -j4; \
  make install
