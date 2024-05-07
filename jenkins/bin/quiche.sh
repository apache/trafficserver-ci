#!/usr/bin/env bash
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

NPROC=${NPROC:-$(getconf _NPROCESSORS_ONLN)}

if [ ! -d cmake ]
then
  echo "CMake builds are not supported on pre 10.x branch."
  exit 0
fi

SSL_FLAVOR="boringssl"
if [ $# -ge 1 ]
then
  SSL_FLAVOR=$1
fi

cd "${WORKSPACE}/src"

# copy in CMakePresets.json
presetpath="../ci/jenkins/branch/CMakePresets.json"
[ -f "${presetpath}" ] && /bin/cp -f "${presetpath}" .

cmake -B build --preset branch-quiche-on-${SSL_FLAVOR}
cmake --build build -j${NPROC} -v
cmake --install build

#pushd cmake-build-quiche
#ctest -j${NPROC} --output-on-failure --no-compress-output -T Test
#/tmp/ats_quiche/bin/traffic_server -K -k -R 1
#popd
