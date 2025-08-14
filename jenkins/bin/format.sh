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

set +x
cd "${WORKSPACE}/src"

# First, make sure there are no trailing WS!!!
git grep -IE ' +$' | \
    fgrep -v 'lib/yamlcpp' | \
    fgrep -v 'lib/Catch2' | \
    fgrep -v 'lib/systemtap' | \
    fgrep -v '.gold:' | \
    fgrep -v '.test_input'
if [ "1" != "$?" ]; then
    echo "Error: Trailing whitespaces are not allowed!"
    echo "Error: Please run: git grep -IE ' +$'"
    exit 1
fi

echo "Success! No trailing whitespace"
# Unix format please!
git grep -IE $'\r$' | \
    fgrep -v 'lib/yamlcpp' | \
    fgrep -v 'lib/Catch2' | \
    fgrep -v 'lib/systemtap' | \
    fgrep -v '.test_input'
if [ "1" != "$?" ]; then
    echo "Error: Please make sure to run dos2unix on the above file(s)"
    exit 1
fi
echo "Success! No DOS carriage return"

set -x

NPROC=${NPROC:-$(getconf _NPROCESSORS_ONLN)}

if [ -d cmake ]
then
  echo "Building with CMake"

  presetpath="${WORKSPACE}/ci/jenkins/branch/CMakePresets.json"
  [ -f "${presetpath}" ] && /bin/cp -f "${presetpath}" .

  cmake -B build --preset=branch
  cmake --build build --target format -j${NPROC} -v || exit 1

else
  echo "Building with autotools"

  autoreconf -if
  ./configure

  ${ATS_MAKE} clang-format || exit 1

  # Only enforce autopep8 on branches where the pre-commit
	# hook was updated to check it. Otherwise, none of the 
	# PRs for older branches will pass this check.
  if grep -q autopep8 tools/git/pre-commit; then
    ${ATS_MAKE} autopep8 || exit 1
  fi
fi

git diff --exit-code

# Normal exit
exit 0
