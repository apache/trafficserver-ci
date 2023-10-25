#!/bin/bash
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

set +x

autoreconf -if

printenv

# Check if it's a debug or release build
DEBUG=""
test "${JOB_NAME#*type=debug}" != "${JOB_NAME}" && DEBUG="--enable-debug"
[ "${TYPE}" == "debug" ] && DEBUG="--enable-debug"
HARDENING=""
[ "${TYPE}" == "hardening" ] && HARDENING="--enable-hardening"

# When to turn on ccache, disabled for some builds
CCACHE="--enable-ccache"

# Check for /opt/openssl11
OPENSSL=""
test -d "/opt/openssl11" && OPENSSL="--with-openssl=/opt/openssl11"

# When to enable -Werror
#WERROR="--enable-werror"
WERROR=""

# Optional settings
SANIT=""
test "${FEATURES#*asan}" != "${FEATURES}" && SANIT="${SANIT} --enable-asan"
test "${FEATURES#*lsan}" != "${FEATURES}" && SANIT="${SANIT} --enable-lsan"
test "${FEATURES#*tsan}" != "${FEATURES}" && SANIT="${SANIT} --enable-tsan"

echo "DEBUG: $DEBUG"
echo "CCACHE: $CCACHE"
echo "WERROR: $WERROR"
echo "SANIT: $SANIT"

# Change to the build area (this is previously setup in extract.sh)
#cd "${ATS_BUILD_BASEDIR}/build"
mkdir -p install
#mkdir -p BUILDS && cd BUILDS

# Restore verbose shell output
set -x

#../configure \
./configure \
    --prefix="/tmp/ats" \
    --enable-experimental-plugins \
    --enable-example-plugins \
    --with-user=jenkins \
    ${OPENSSL} \
    ${CCACHE} \
    ${WERROR} \
    ${DEBUG} \
    ${HARDENING} \
    ${SANIT}

echo
echo -n "Main build and install started at " && date
${ATS_MAKE} ${ATS_MAKE_FLAGS} V=1 Q= || exit 1
${ATS_MAKE} ${ATS_MAKE_FLAGS} install
echo -n "Main build and install at " && date
