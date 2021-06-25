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

test -z "${WORKSPACE}" && WORKSPACE=".."

mkdir -p ${WORKSPACE}/output/
head -1 README
autoreconf -fiv

scan-build-10 --keep-cc \
	./configure --enable-experimental-plugins --with-luajit

make -j4 -C lib all-local V=1 Q=

scan-build-10 --keep-cc \
	-enable-checker alpha.unix.cstring.BufferOverlap \
	-enable-checker alpha.core.BoolAssignment \
	-enable-checker alpha.core.CastSize \
	-enable-checker alpha.core.SizeofPtr \
	--status-bugs --keep-empty \
	-o ${WORKSPACE}/output/ \
	--html-title="clang-analyzer: ${GITHUB_BRANCH}" \
make -j4 V=1 Q=

make -j4
[ ! -f ${WORKSPACE}/output/index.html ] && touch "${WORKSPACE}/output/No Errors Reported"; exit 0 || exit 1

# Where are our LLVM tools?
NPROCS=${NPROCS:-$(getconf _NPROCESSORS_ONLN)}

# Options
options="--status-bugs --keep-cc"
configure="--enable-experimental-plugins --with-luajit"

# Additional checkers
# Phil says these are all FP's: -enable-checker alpha.security.ArrayBoundV2
#           -enable-checker alpha.unix.PthreadLock\
checkers="-enable-checker alpha.unix.cstring.BufferOverlap \
          -enable-checker alpha.core.BoolAssignment \
          -enable-checker alpha.core.CastSize \
          -enable-checker alpha.core.SizeofPtr"

# These shenanigans are here to allow it to run both manually, and via Jenkins
test -z "${ATS_MAKE}" && ATS_MAKE="make"
test ! -z "${WORKSPACE}" && cd "${WORKSPACE}/src"

# Where to store the results, special case for the CI
output="/tmp"
test ! -z "${WORKSPACE}" && output="${WORKSPACE}/output"

# Find a Jenkins output tree if possible
#if [ "${JOB_NAME#*-github}" != "${JOB_NAME}" ]; then
    # This is a Github PR build, override the branch name accordingly
#    ATS_BRANCH="github"
#    if [ -w "${OUTPUT_BASE}/${ATS_BRANCH}" ]; then
#        output="${OUTPUT_BASE}/${ATS_BRANCH}/${ghprbPullId}"
#        [ ! -d "${output}" ] && mkdir "${output}"
#    fi
#    github_pr=" PR #${ghprbPullId}"
#    results_url="https://ci.trafficserver.apache.org/clang-analyzer/${ATS_BRANCH}/${ghprbPullId}/"
#else
#    test -w "${OUTPUT_BASE}/${ATS_BRANCH}" && output="${OUTPUT_BASE}/${ATS_BRANCH}"
#    github_pr=""
#    results_url="https://ci.trafficserver.apache.org/clang-analyzer/${ATS_BRANCH}/"
#fi

export LLVM_BASE=/usr

# Tell scan-build to use clang as the underlying compiler to actually build
# source. If you don't do this, it will default to GCC.
export CCC_CC=${LLVM_BASE}/bin/clang
export CCC_CXX=${LLVM_BASE}/bin/clang++

# This can be used to override any of those settings above
[ -f ./.clang-analyzer ] && source ./.clang-analyzer

# Don't do clang-analyzer runs on 7.1.x branch, for e.g. Github PRs
grep -q 70010 configure.ac && echo "7.1.x branch detected, stop here!" && exit 0
grep -q 80000 configure.ac && echo "8.0.x branch detected, stop here!" && exit 0
grep -q 80010 configure.ac && echo "8.1.x branch detected, stop here!" && exit 0

# Start the build / scan
[ "$output" != "/tmp" ] && echo "Results (if any) can be found at ${results_url}"
autoreconf -fi
${LLVM_BASE}/bin/scan-build-10 --keep-cc ./configure ${configure} \
	|| exit 1

# Since we don't want the analyzer to look at yamlcpp, build it first
# without scan-build. The subsequent make will then skip it.
# the all-local can be taken out and lib changed to lib/yamlcpp
# by making yaml cpp a SUBDIRS in lib/Makefile.am.
${ATS_MAKE} -j ${NPROCS} -C lib all-local V=1 Q= || exit 1

${LLVM_BASE}/bin/scan-build-10 --keep-cc ${checkers} ${options} -o ${output} \
    --html-title="clang-analyzer: ${ATS_BRANCH}${github_pr}" \
    ${ATS_MAKE} -j ${NPROCS} V=1 Q=
status=$?

# Clean the work area unless NOCLEAN is set. This is just for debugging when you
# need to see what the generated build did.
#if [ -z "$NOCLEAN" ]; then
#    ${ATS_MAKE} distclean
#fi
[ "$output" != "/tmp" ] && echo "Results (if any) can be found at ${results_url}"

# Cleanup old reports, for main clang and github as well (if the local helper script is available)
#if [ -x "/admin/bin/clean-clang.sh" ]; then
#    /admin/bin/clean-clang.sh
#fi

exit $status
