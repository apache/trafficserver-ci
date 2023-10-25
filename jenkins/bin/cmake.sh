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

# This does intentionally not run the regressions, it's primarily a "build" test

set -x

# join function
join() {
  local separator="$1"
  shift
  local first="$1"
  shift
  printf "%s" "$first" "${@/#/$separator}"
}

NPROC=$(nproc)

if [ ! -d cmake ]
then
  echo "CMake builds are not supported for the pre 10.x branches."
  exit 0
fi

# copy in CMakePresets.json
presetpath="../ci/jenkins/branch/CMakePresets.json"
[ -f "${presetpath}" ] && /usr/bin/cp -f "${presetpath}" .

# debug/release become a feature
btype="release"
if [ "${TYPE#*debug}" != "${TYPE}" ]
then
  btype="debug"
fi

FEATURES="${FEATURES:=""}"
[ -n "${FEATURES}" ] && FEATURES="${FEATURES} ${btype}"
[ -z "${FEATURES}" ] && FEATURES="${btype}"

# build CMakeUserPresets.json

# split
IFS=' ' read -ra farray <<< "$FEATURES"

# join
inherits=\"$(join '", "' "${farray[@]}")\"

read -d '' contents << EOF
{
  "version": 2,
  "configurePresets": [
    { 
      "name": "ci-preset", 
      "inherits": [${inherits}]
    } 
  ] 
}
EOF

echo "${contents}" > CMakeUserPresets.json

#cmake -B cmake-build-release\
#  -GNinja \
#  -DCMAKE_COMPILE_WARNING_AS_ERROR=ON \
#  -DCMAKE_BUILD_TYPE=Release \
#  -DBUILD_EXPERIMENTAL_PLUGINS=ON \
#  -DCMAKE_INSTALL_PREFIX=/tmp/ats
#  -DOPENSSL_ROOT_DIR=/opt/openssl-quic

cmake -B builddir --preset ci-preset
cmake --build builddir -j${NPROC} -v

pushd builddir
ctest -B builddir -j${NPROC} --output-on-failure --no-compress-output -T Test
popd

cmake --install builddir
chmod -R go+w installdir
installdir/bin/traffic_server -K -k -R 1
