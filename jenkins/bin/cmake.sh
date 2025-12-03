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
set -e

NPROC=${NPROC:-$(getconf _NPROCESSORS_ONLN)}

if [ ! -d cmake ]
then
  echo "CMake builds are not supported for the pre 10.x branches."
  exit 0
fi

# copy in CMakePresets.json
presetpath="../ci/jenkins/branch/CMakePresets.json"
[ -f "${presetpath}" ] && /bin/cp -f "${presetpath}" .

# debug/release become a feature
btype="release"
if [ "${TYPE#*debug}" != "${TYPE}" ]
then
  btype="debug"
fi

FEATURES="${FEATURES:=""}"
[ -n "${FEATURES}" ] && FEATURES="${btype} ${FEATURES}"
[ -z "${FEATURES}" ] && FEATURES="${btype}"

# build CMakeUserPresets.json

# split, handles extra spaces
IFS=' ' read -ra farray <<< "${FEATURES}"

# prepend with 'branch-' and quote
for ((ind=0 ; ind < ${#farray[@]} ; ++ind)); do
  farray[$ind]=\"branch-${farray[$ind]}\"
done

# comma separate
inherits=$(sed 's/ /, /g' <<< "${farray[@]}")

contents="
{
  \"version\": 2,
  \"configurePresets\": [
    { 
      \"name\": \"branch-user-preset\", 
      \"inherits\": [${inherits}]
    } 
  ] 
}
"

echo "${contents}" > CMakeUserPresets.json

cmake -B build --preset branch-user-preset
cmake --build build -j${NPROC} -v
cmake --install build

#pushd build
#ctest -B build -j${NPROC} --output-on-failure --no-compress-output -T Test
#popd

#chmod -R go+w /tmp/ats
#/tmp/ats/bin/traffic_server -K - R 3
