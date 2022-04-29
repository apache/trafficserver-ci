#!/bin/sh
#
#  Licensed to the Apache Software Foundation (ASF) under one
#  or more contributor license agreements.  See the NOTICE file
#  distributed with this work for additional information
#  regarding copyright ownership.  The ASF licenses this file
#  to you under the Apache License, Version 2.0 (the
#  "License"); you may not use this file except in compliance
#  with the License.  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

# Show which platform we're actually building on
set +x

# Deduct if this build is on a docker instance
IS_DOCKER="no"
df / | fgrep -q overlay && IS_DOCKER="yes"
export IS_DOCKER

echo -n "Build platform: "
[ -f /etc/lsb-release ] && grep DISTRIB_RELEASE /etc/lsb-release
[ -f /etc/debian_version ] && cat /etc/debian_version
[ -f /etc/redhat-release ] && cat /etc/redhat-release
echo "Build on Docker: " $IS_DOCKER

# Jenkins workspace
export WORKSPACE="${WORKSPACE:=${PWD}}"
echo "Workspace is: " ${WORKSPACE}

# ccache dir as mounted in container
CCACHE_DIR="${CCACHE_DIR:=/tmp/ccache}"

# Shouldn't have to tweak this
#export ATS_SRC_HOME="/home/jenkins/src"

# Check if we're doing Debian style hardening
[ "hardening" == "${TYPE}" ] && export DEB_BUILD_HARDENING=1
test "${JOB_NAME#*type=hardening}" != "${JOB_NAME}" && export DEB_BUILD_HARDENING=1

# Check if we need to use a different "make"
ATS_MAKE=make
PLATFORM=${PLATFORM:=linux}
[ "freebsd" == "${PLATFORM}" ] && ATS_MAKE="gmake"
export ATS_MAKE

# Useful for timestamps etc. for daily runs
export TODAY=$(/bin/date +'%m%d%Y')

# Extract the current branch (default to master). ToDo: Can we do this better ?
#ATS_BRANCH=master
ATS_BRANCH=${GITHUB_BRANCH:=master}

# Make sure to leave these, for the HTTP cache tests
#test "${JOB_NAME#*-5.3.x}" != "${JOB_NAME}" && ATS_BRANCH=5.3.x
#test "${JOB_NAME#*-6.2.x}" != "${JOB_NAME}" && ATS_BRANCH=6.2.x

# These should be maintained and cleaned up as needed.
test "${JOB_NAME#*-8.0.x}" != "${JOB_NAME}" && ATS_BRANCH=8.0.x
test "${JOB_NAME#*-8.1.x}" != "${JOB_NAME}" && ATS_BRANCH=8.1.x
test "${JOB_NAME#*-9.0.x}" != "${JOB_NAME}" && ATS_BRANCH=9.0.x
test "${JOB_NAME#*-9.1.x}" != "${JOB_NAME}" && ATS_BRANCH=9.1.x
test "${JOB_NAME#*-9.2.x}" != "${JOB_NAME}" && ATS_BRANCH=9.2.x
test "${JOB_NAME#*-9.3.x}" != "${JOB_NAME}" && ATS_BRANCH=9.3.x
test "${JOB_NAME#*-10.0.x}" != "${JOB_NAME}" && ATS_BRANCH=10.0.x
test "${JOB_NAME#*-10.1.x}" != "${JOB_NAME}" && ATS_BRANCH=10.1.x
test "${JOB_NAME#*-10.2.x}" != "${JOB_NAME}" && ATS_BRANCH=10.2.x
test "${JOB_NAME#*-10.3.x}" != "${JOB_NAME}" && ATS_BRANCH=10.3.x

# Special case for the full build of clang analyzer
#test "${JOB_NAME}" == "clang-analyzer-full" && ATS_BRANCH=FULL

export ATS_BRANCH
echo "Branch is $ATS_BRANCH"

# If the job name includes the string "clang", force clang. This can also be set
# explicitly for specific jobs.
test "${JOB_NAME#*compiler=clang}" != "${JOB_NAME}" && enable_clang=1

COMPILER=${COMPILER:=gcc}
[ "${COMPILER}" == "clang" ] && enable_clang=1
[ "${COMPILER}" == "icc" ] && enable_icc=1
[ "${COMPILER}" == "gcc" ] && enable_gcc=1

if [ "1" == "$enable_clang" ]; then
    export CC="clang"
    export CXX="clang++"
    export CXXFLAGS="-Qunused-arguments"
    export WITH_LIBCPLUSPLUS="yes"
elif [ "1" == "$enable_icc" ]; then
    source /opt/rh/devtoolset-9/enable
    source /opt/intel/bin/iccvars.sh intel64
    export CC=icc
    export CXX=icpc
else
    # Default is gcc / g++
    export CC=gcc
    export CXX=g++
    if test -f "/opt/rh/devtoolset-9/enable"; then
        # This changes the path such that gcc / g++ is the right version. This is for CentOS 6 / 7.
        source /opt/rh/devtoolset-9/enable
        echo "Enabling devtoolset-9"
    elif test -f "/opt/rh/gcc-toolset-11/enable"; then
        # This changes the path such that gcc / g++ is the right version. This is for Rockylinux 8
        source /opt/rh/gcc-toolset-11/enable
        echo "Enabling gcc-toolset-11"
    elif test -x "/usr/bin/g++-9"; then
        # This is for Debian platforms
        export CC=/usr/bin/gcc-9
        export CXX=/usr/bin/g++-9
    fi
fi

# Echo out compiler information
echo "Compiler information:"
echo "CC: ${CC}"
$CC -v
echo "CXX: $CXX"
$CXX -v

if [ -x "/bin/bash" ]; then
  export CONFIG_SHELL=/bin/bash
fi

if [ -x "/bin/m4" ]; then
  export M4=/bin/m4
fi

# Figure out parallelism for regular builds / bots
export ATS_MAKE_FLAGS="-j4"
if [ "yes" == "$IS_DOCKER" ]; then
  export ATS_BUILD_BASEDIR="${WORKSPACE}"
else
  export ATS_BUILD_BASEDIR="${WORKSPACE}/${BUILD_NUMBER}"
fi

# sanitizer environment
if [ "${FEATURES#*asan}" != "${FEATURES}" ]; then
  export ASAN_OPTIONS="detect_leaks=0:detect_odr_violation=1"
fi

# ccache settings
#export CCACHE_BASEDIR=${ATS_BUILD_BASEDIR}
#export CCACHE_COMPRESS=true

# Restore verbose shell output
set -x
