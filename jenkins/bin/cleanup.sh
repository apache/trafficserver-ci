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

# Do a distclean, to verify that we can actually satisfy this (common) build target
cd "${ATS_BUILD_BASEDIR}/build"
[ -d BUILDS ] && cd BUILDS

${ATS_MAKE} distclean

# Final cleanup, this removes the build and install areas, not really needed nor right for docker builds
cd "${WORKSPACE}" && rm -rf ${BUILD_NUMBER}
