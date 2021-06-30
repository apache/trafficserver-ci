FROM centos:8

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
    perl-ExtUtils-MakeMaker perl-Digest-SHA perl-URI curl tcl-devel; \
    # autest stuff
    yum -y install python3 httpd-tools procps-ng nmap-ncat python3-pip \
    python3-gunicorn python3-requests python3-devel python3-psutil telnet golang;

RUN pip3 install pipenv httpbin
RUN if [ ! -z "$(grep -i centos /etc/redhat-release)" ]; then \
    yum -y install gcc-toolset-9 gcc-toolset-9-libasan-devel; \
    fi

# Install openssl-quic
RUN yum install -y python38-devel
RUN alternatives --set python /usr/bin/python3.8
RUN yum -y install libev-devel jemalloc-devel libxml2-devel \
    c-ares-devel libevent-devel jansson-devel zlib-devel systemd-devel

ARG h3_tools_dir=/var/tmp/h3_tools_tmp
RUN mkdir -p ${h3_tools_dir}
WORKDIR ${h3_tools_dir}
COPY /build_h3_tools.sh ${h3_tools_dir}/build_h3_tools.sh
# This will install OpenSSL QUIC and related tools in /opt.
RUN bash ${h3_tools_dir}/build_h3_tools.sh
WORKDIR /root
RUN rm -rf ${h3_tools_dir}

# Make sure we pick up this built version of curl, which is in /opt/bin.
RUN echo 'PATH=/opt/bin:$PATH' | tee -a /etc/profile.d/curl_http3.sh

RUN update-crypto-policies --set LEGACY
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
