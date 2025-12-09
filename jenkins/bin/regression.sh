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

NPROC=${NPROC:-$(getconf _NPROCESSORS_ONLN)}

#cd "${ATS_BUILD_BASEDIR}/build"
#cd "${ATS_BUILD_BASEDIR}"
#[ -d BUILDS ] && cd BUILDS

#chmod -R go+w /tmp/ats
#/tmp/ats/bin/traffic_server -K -k -R 3

echo
echo -n "Unit tests started at " && date

if [ -d cmake ]
then
	pushd build
	ctest -j${NPROC} --output-on-failure --no-compress-output -T Test || exit 1
	popd
else
  ${ATS_MAKE} -j${NPROC} check VERBOSE=Y V=1 || exit 1
fi

echo -n "Unit tests finished at " && date

echo
echo -n "Regression tests started at " && date
/tmp/ats/bin/traffic_server -K -R 3
rval=$?
echo -n "Regression tests finished at " && date
exit $rval
