FROM rockylinux:9

RUN dnf -y install epel-release dnf-plugins-core ; \
    dnf config-manager --set-enabled crb ;  \
    dnf install -y https://rpms.remirepo.net/enterprise/remi-release-9.rpm ; \
    dnf repolist ; \
    dnf -y update ; \
    # Compilers
    dnf -y install ccache make pkgconfig bison flex gcc-c++ clang \
    # Autoconf
    autoconf automake libtool \
    # Various other tools
    sudo git rpm-build file wget openssl hwloc nghttp2 libnghttp2-devel ; \
    # Devel packages that ATS needs
    dnf -y install openssl-devel expat-devel pcre-devel libcap-devel \
        hwloc-devel libunwind-devel xz-devel libcurl-devel ncurses-devel \
        jemalloc-devel GeoIP-devel luajit-devel brotli-devel \
        ImageMagick-devel ImageMagick-c++-devel hiredis-devel \
        zlib-devel libmaxminddb-devel perl-ExtUtils-MakeMaker \
        perl-Digest-SHA perl-URI perl-FindBin curl tcl-devel java; \
    # autest stuff
    dnf -y install python3 httpd-tools procps-ng nmap-ncat python3-pip \
        python3-gunicorn python3-requests python3-devel python3-psutil \
        telnet golang;

RUN pip3 install --upgrade pip
RUN pip3 install pipenv httpbin
#RUN dnf -y install gcc-toolset-11 gcc-toolset-11-libasan-devel
RUN dnf -y install go-toolset llvm-toolset

# Install openssl-quic
#RUN dnf install -y python38-devel
#RUN alternatives --set python /usr/bin/python3.8
RUN dnf -y install libev-devel jemalloc-devel libxml2-devel \
    c-ares-devel libevent-devel jansson-devel zlib-devel systemd-devel \
    libpsl-devel libgsasl-devel libidn-devel openldap-devel

#ARG h3_tools_dir=/root/build_h3_tools
#RUN mkdir -p ${h3_tools_dir}
#WORKDIR ${h3_tools_dir}
#COPY /build_h3_tools.sh ${h3_tools_dir}/build_h3_tools.sh
# This will install OpenSSL QUIC and related tools in /opt.
#RUN bash ${h3_tools_dir}/build_h3_tools.sh; rm -rf ${h3_tools_dir} /root/.rustup
WORKDIR /root

# Make sure we pick up this built version of curl, which is in /opt/bin.
#RUN echo 'PATH=/opt/bin:$PATH' | tee -a /etc/profile.d/curl_http3.sh

RUN update-crypto-policies --set LEGACY
RUN echo 'export GOROOT=/usr/local/go' | tee -a /etc/profile
RUN echo 'export PATH=$PATH:/usr/local/go/bin' | tee -a /etc/profile
RUN source /etc/profile
RUN wget https://github.com/summerwind/h2spec/releases/download/v2.6.0/h2spec_linux_amd64.tar.gz
RUN tar xf h2spec_linux_amd64.tar.gz
RUN cp --force h2spec /usr/local/bin/h2spec
RUN dnf clean all

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
RUN dnf install -y perl-IO-Compress
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
RUN dnf clean all

# Install ABI checking tools.
RUN dnf install -y ctags elfutils-libelf-devel wdiff
COPY /install_abi_tools.sh /root/install_abi_tools.sh
RUN bash /root/install_abi_tools.sh
