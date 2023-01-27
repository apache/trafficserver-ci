FROM fedora:30
RUN  \
    # Compilers
    yum -y install ccache make pkgconfig bison flex gcc-c++ clang git sudo; \
    # Various other tools
    git rpm-build distcc-server file wget openssl hwloc; \
    # Devel packages that ATS needs
    yum -y install openssl-devel expat-devel pcre-devel libcap-devel hwloc-devel libunwind-devel \
    xz-devel libcurl-devel ncurses-devel jemalloc-devel GeoIP-devel luajit-devel brotli-devel \
    ImageMagick-devel ImageMagick-c++-devel hiredis-devel zlib-devel \
    perl-ExtUtils-MakeMaker perl-Digest-SHA perl-URI automake autoconf libtool; \
    # This is for autest stuff
    yum -y install python3 httpd-tools procps-ng nmap-ncat pipenv; \
    # This is stuff for docs building
    yum -y install java lbzip2 rsync;
RUN pip3 install --upgrade pip
RUN pip3 install sphinx
RUN pip3 install sphinxcontrib.plantuml
RUN pip3 install sphinx-rtd-theme

# Check if devtoolset-7 is required
RUN  if [ ! -z "$(grep -i centos /etc/redhat-release)" ]; then \
    yum -y install centos-release-scl; \
    yum -y install devtoolset-7; \
    fi

#RUN mkdir /home/mirror
#RUN mkdir /home/mirror/trafficserver
#RUN mkdir /home/docs
##CMD cd /home/mirror && rm -rf trafficserver && \
##    source ./gh-mirror.sh && cd /home/mirror/trafficserver.git && \
##    git fetch && cd /home/mirror && git clone trafficserver.git && \
##    cd /home/mirror/trafficserver && source /home/mirror/trafficserver/ci/jenkins/bin/environment.sh && \
##    source /home/mirror/trafficserver/ci/jenkins/bin/docs.sh

##CMD  cd src && source ci/jenkins/bin/environment.sh && source ci/jenkins/bin/docs.sh

#CMD  cd /home/mirror/trafficserver && ls -alh && git status && source /home/mirror/trafficserver/ci/jenkins/bin/environment.sh && \
#     source /home/mirror/trafficserver/ci/jenkins/bin/docs.sh
