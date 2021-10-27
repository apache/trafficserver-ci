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

test -z "${WORKSPACE}" && WORKSPACE=".."
mkdir -p ${WORKSPACE}/output/${GITHUB_BRANCH}
head -1 README

grep -q 80010 configure.ac && echo "8.1.x branch detected, stop here!" && exit 0

autoreconf -fiv
scan-build-10 --keep-cc \
  ./configure --enable-experimental-plugins --with-luajit

# build things like yamlcpp without the analyzer 
make -j4 -C lib all-local V=1 Q=
rptdir="${WORKSPACE}/output/${GITHUB_BRANCH}"

scan-build-10 --keep-cc \
  -enable-checker alpha.unix.cstring.BufferOverlap \
  -enable-checker alpha.core.BoolAssignment \
  -enable-checker alpha.core.CastSize \
  -enable-checker alpha.core.SizeofPtr \
  --status-bugs --keep-empty \
  -o ${rptdir} \
  --html-title="clang-analyzer: ${GITHUB_BRANCH}" \
  make -j4 V=1 Q=

make -j4

shopt -s nullglob
rptlist=(${rptdir}/**/index.html)

# no index.html means no report
if [ ${#rptlist[@]} -eq 0 ]; then
  touch "${rptdir}/No Errors Reported"
   status=0
else
   status=1
fi

exit $status
