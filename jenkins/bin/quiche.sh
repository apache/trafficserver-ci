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

# Config installation preserves source modes. Ensure a restrictive checkout
# umask cannot make installed defaults unreadable.
sudo chmod -R o+r .

# copy in CMakePresets.json
presetpath="../ci/jenkins/branch/CMakePresets.json"
[ -f "${presetpath}" ] && /bin/cp -f "${presetpath}" .

cmake_args=()
if [ -x tests/urtest.sh ]; then
  autest_files=$(find tests -type f -name '*.test.py' -print)
  if [ -n "${autest_files}" ]; then
    echo "ERROR: Found unconverted AuTest files that will not run because this branch uses pytest." >&2
    echo "Convert these *.test.py files to Uranium tests:" >&2
    printf '%s\n' "${autest_files}" >&2
    exit 1
  fi
  cmake_args+=("-DURTEST_SANDBOX=/tmp/sandbox")
fi
cmake -B build --preset branch-quiche-on-${SSL_FLAVOR} "${cmake_args[@]}"
cmake --build build -j${NPROC} -v
cmake --install build

#pushd cmake-build-quiche
#ctest -j${NPROC} --output-on-failure --no-compress-output -T Test
#/tmp/ats_quiche/bin/traffic_server -K -R 3
#popd
