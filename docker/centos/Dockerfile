FROM centos:8

RUN yum -y install epel-release dnf-plugins-core; yum config-manager --set-enabled powertools; yum repolist

RUN yum -y update; \
    # Compilers
    yum -y install ccache make pkgconfig bison flex gcc-c++ clang \
    # Autoconf
    autoconf automake libtool \
    # Various other tools
    git rpm-build distcc-server file wget openssl hwloc; \
    # Devel packages that ATS needs
    yum -y install openssl-devel expat-devel pcre-devel libcap-devel hwloc-devel libunwind-devel \
    xz-devel libcurl-devel ncurses-devel jemalloc-devel GeoIP-devel luajit-devel brotli-devel \
    ImageMagick-devel ImageMagick-c++-devel hiredis-devel zlib-devel libmaxminddb-devel \
    perl-ExtUtils-MakeMaker perl-Digest-SHA perl-URI;

RUN if [ ! -z "$(grep -i centos /etc/redhat-release)" ]; then \
    yum -y install centos-release-scl; \
    yum -y install gcc-toolset-9 gcc-toolset-9-libasan-devel; \
    fi

RUN yum clean all
