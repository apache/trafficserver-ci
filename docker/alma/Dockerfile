FROM almalinux/almalinux:8

RUN yum -y install epel-release dnf-plugins-core; yum config-manager --set-enabled powertools; yum repolist; \

    yum -y update; \
    # Compilers
    yum -y install ccache make pkgconfig bison flex gcc-c++ clang \
    # Autoconf
    autoconf automake libtool \
    # Various other tools
    git rpm-build distcc-server file wget openssl hwloc nghttp2 libnghttp2-devel; \
    # Devel packages that ATS needs
    yum -y install openssl-devel expat-devel pcre-devel libcap-devel hwloc-devel libunwind-devel \
    xz-devel libcurl-devel ncurses-devel jemalloc-devel GeoIP-devel luajit-devel brotli-devel \
    ImageMagick-devel ImageMagick-c++-devel hiredis-devel zlib-devel libmaxminddb-devel \
    perl-ExtUtils-MakeMaker perl-Digest-SHA perl-URI curl; \
    # autest stuff
    yum -y install python3 httpd-tools procps-ng nmap-ncat python3-pip \
    python3-gunicorn python3-requests python3-devel python3-psutil telnet golang;

RUN pip3 install pipenv httpbin
RUN yum -y install gcc-toolset-9 gcc-toolset-9-libasan-devel

# Install openssl-quic
RUN yum install -y python38-devel
RUN alternatives --set python /usr/bin/python3.8
RUN yum -y install libev-devel jemalloc-devel libxml2-devel \
    c-ares-devel libevent-devel jansson-devel zlib-devel systemd-devel
COPY /build_h3_tools.sh /var/tmp/build_h3_tools.sh
RUN bash /var/tmp/build_h3_tools.sh
# Make sure we pick up this built version of curl, which is in /opt/bin.
RUN echo 'PATH=/opt/bin:$PATH' | tee -a /etc/profile.d/curl_http3.sh

RUN update-crypto-policies --set LEGACY
RUN go get github.com/summerwind/h2spec/cmd/h2spec
RUN cp /root/go/bin/h2spec /usr/local/bin
RUN yum clean all
