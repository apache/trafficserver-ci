FROM centos:7

# Since CentOS is no longer officially supported, update the mirror lists to
# vault.centos.org.
RUN \
    sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-Linux-*; \
    sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-Linux-*

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
    python3-gunicorn python3-requests python3-devel python3-psutil telnet golang;

# Setup openssl11
RUN mkdir /opt/openssl11 \
    && ln -s /usr/lib64/openssl11 /opt/openssl11/lib \
    && ln -s /usr/include/openssl11 /opt/openssl11/include

RUN pip3 install --upgrade pip
RUN pip3 install pipenv httpbin
RUN if [ ! -z "$(grep -i centos /etc/redhat-release)" ]; then \
    yum install -y centos-release-scl; \
    yum -y install devtoolset-9 devtoolset-9-libasan-devel; \
    fi

# Install openssl-quic
RUN yum -y install libev-devel jemalloc-devel libxml2-devel \
    c-ares-devel libevent-devel jansson-devel zlib-devel systemd-devel
# Installing the quic libraries requires Python 3.8.
RUN wget https://www.python.org/ftp/python/3.8.11/Python-3.8.11.tgz; \
    tar xzf Python-3.8.11.tgz; \
    cd Python-3.8.11; \
    ./configure --enable-optimizations; \
    make altinstall
ARG h3_tools_dir=/root/build_h3_tools
RUN mkdir -p ${h3_tools_dir}
WORKDIR ${h3_tools_dir}
COPY /build_h3_tools.sh ${h3_tools_dir}/build_h3_tools.sh
# This will install OpenSSL QUIC and related tools in /opt.
RUN bash ${h3_tools_dir}/build_h3_tools.sh
WORKDIR /root

# Make sure we pick up this built version of curl, which is in /opt/bin.
RUN echo 'PATH=/opt/bin:$PATH' | tee -a /etc/profile.d/curl_http3.sh

RUN echo 'export GOROOT=/usr/local/go' | tee -a /etc/profile
RUN echo 'export PATH=$PATH:/usr/local/go/bin' | tee -a /etc/profile
RUN source /etc/profile
RUN go get github.com/summerwind/h2spec/cmd/h2spec
RUN cp /root/go/bin/h2spec /usr/local/bin
RUN yum clean all

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
