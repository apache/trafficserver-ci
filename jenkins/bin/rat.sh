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

set -x
set -e

WORKSPACE="${WORKSPACE:-..}"

cd "${WORKSPACE}/src"
export PATH=/opt/bin:$PATH

check_rat_output() {
  local rat_output=$1

  if [ -f ci/apache-rat-0.17.jar ]; then
    grep -Eq '^INFO:[[:space:]]+Unapproved:[[:space:]]+0$' "${rat_output}" || return 1
    grep -Eq '^INFO:[[:space:]]+Unknown:[[:space:]]+0$' "${rat_output}" || return 1
  else
    grep '^0 Unknown Licenses' "${rat_output}" >/dev/null || return 1
  fi
}

if [ -d cmake ]
then

  cmake -B builder
  cmake --build builder --target rat | tee RAT.txt

else

  autoreconf -if
  ./configure

  # WTF
  rm -f lib/ts/stamp-h1

  ${ATS_MAKE} rat | tee RAT.txt
fi

check_rat_output RAT.txt || exit 1
#mv RAT.txt /CA/RAT/rat-${ATS_BRANCH}.txt.new
#mv /CA/RAT/rat-${ATS_BRANCH}.txt.new /CA/RAT/rat-${ATS_BRANCH}.txt

# Purgatory
#curl -o /dev/null -k -s -X PURGE https://ci.trafficserver.apache.org/RAT/rat-${ATS_BRANCH}.txt

# Mark as failed if there are any unknown licesnes
#grep '0 Unknown Licenses' /CA/RAT/rat-${ATS_BRANCH}.txt >/dev/null || exit 1

# Normal exit
exit 0
