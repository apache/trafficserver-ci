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

set -x
set -e

grep -q 80010 configure.ac && echo "8.1.x branch detected, stop here!" && exit 0

NPROC=$(nproc)

WORKSPACE="${WORKSPACE:-..}"
GITHUB_BRANCH="${GITHUB_BRANCH:-master}"

SCAN_BUILD=$(ls /usr/bin/scan-build* | grep -v py | tail -n 1)
ANAL_BUILD=$(ls /usr/bin/analyze-build* | grep -v py | tail -n 1)
RPTDIR="${WORKSPACE}/output/${GITHUB_BRANCH}"

mkdir -p ${RPTDIR}

if [ -d cmake ]
then
  echo "Building with CMake"

  # copy in CMakePresets.json
  presetpath="${WORKSPACE}/ci/jenkins/branch/CMakePresets.json"
  [ -f "${presetpath}" ] && /bin/cp -f "${presetpath}" .

	cmake -B builddir --preset branch-clang-analyzer
	cmake --build builddir -v -j${NPROC}

	${ANAL_BUILD} \
		--cdb builddir/compile_commands.json \
		-v \
		--status-bugs \
    --keep-empty \
    -enable-checker alpha.unix.cstring.BufferOverlap \
    -enable-checker alpha.core.BoolAssignment \
    -enable-checker alpha.core.CastSize \
    -enable-checker alpha.core.SizeofPtr \
    -o "${RPTDIR}" \
    --html-title="clang-analyzer: ${GITHUB_BRANCH}"

else
  echo "Building with autotools"

  autoreconf -fiv
  ${SCAN_BUILD} --keep-cc \
    ./configure --enable-experimental-plugins --with-luajit

  # build things like yamlcpp without the analyzer 
  make -j${NPROC} -C lib all-local V=1 Q=

  ${SCAN_BUILD} --keep-cc \
    -enable-checker alpha.unix.cstring.BufferOverlap \
    -enable-checker alpha.core.BoolAssignment \
    -enable-checker alpha.core.CastSize \
    -enable-checker alpha.core.SizeofPtr \
    --status-bugs --keep-empty \
    -o ${RPTDIR} \
    --html-title="clang-analyzer: ${GITHUB_BRANCH}" \
    make -j${NPROC} V=1 Q=

   make -j${NPROC}
fi

shopt -s nullglob
rptlist=(${RPTDIR}/**/index.html)

# no index.html means no report
if [ ${#rptlist[@]} -eq 0 ]; then
  touch "${RPTDIR}/No Errors Reported"
   status=0
else
   status=1
fi

exit $status
