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

if [ "${ATS_BRANCH}" == "9.0.x" -o \
     "${ATS_BRANCH}" == "9.1.x" -o \
     "${ATS_BRANCH}" == "9.2.x" -o ]
then
  echo "CMake builds are not supported for the 9.x branch."
  echo "No need to test it to show that it fails."
  exit 0
fi

cd "${WORKSPACE}/src"

cmake -B cmake-build-release\
  -GNinja \
  -DCMAKE_COMPILE_WARNING_AS_ERROR=ON \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_EXPERIMENTAL_PLUGINS=ON \
  -DOPENSSL_ROOT_DIR=/opt/openssl-quic \
  -DCMAKE_INSTALL_PREFIX=/tmp/ats
cmake --build cmake-build-release -j4 -v
cmake --install cmake-build-release

pushd cmake-build-release
ctest -j4 --output-on-failure --no-compress-output -T Test
/tmp/ats/bin/traffic_server -K -k -R 1
popd

# quiche build
cmake -B cmake-build-quiche \
  -GNinja \
  -DCMAKE_COMPILE_WARNING_AS_ERROR=ON \
  -DENABLE_QUICHE=ON \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_EXPERIMENTAL_PLUGINS=ON \
  -Dquiche_ROOT=/opt/quiche \
  -DOPENSSL_ROOT_DIR=/opt/boringssl \
  -DCMAKE_INSTALL_PREFIX=/tmp/ats_quiche
cmake --build cmake-build-quiche -j4 -v
cmake --install cmake-build-quiche

pushd cmake-build-quiche
ctest -j4 --output-on-failure --no-compress-output -T Test
/tmp/ats_quiche/bin/traffic_server -K -k -R 1
popd
