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

# This does intentionally not run the regressions, it's primarily a "build" test

set -x

NPROC=`nproc`

if [ ! -d cmake ]
then
  echo "CMake builds are not supported for the pre 10.x branches."
  exit 0
fi

cd "${WORKSPACE}/src"

cmake -B cmake-build-release\
  -GNinja \
  -DCMAKE_COMPILE_WARNING_AS_ERROR=ON \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_EXPERIMENTAL_PLUGINS=ON \
  -DCMAKE_INSTALL_PREFIX=/tmp/ats
#  -DOPENSSL_ROOT_DIR=/opt/openssl-quic
cmake --build cmake-build-release -j${NPROC} -v
cmake --install cmake-build-release

pushd cmake-build-release
ctest -j${NPROC} --output-on-failure --no-compress-output -T Test
/tmp/ats/bin/traffic_server -K -k -R 1
popd
