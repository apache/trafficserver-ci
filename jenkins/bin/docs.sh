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

# These shenanigans are here to allow it to run both manually, and via Jenkins
test -z "${ATS_MAKE}" && ATS_MAKE="make"

# Skip if nothing in doc has changed
#if [ -z "${GITHUB_BRANCH}" ]; then
#	INCLUDE_FILES=$(for i in $(git grep literalinclude doc/ | awk '{print $3}'); do basename $i; done | sort -u | paste -sd\|)
#	echo $INCLUDE_FILES
#	if [ ! -z "$ghprbActualCommit" ]; then
#		git diff ${ghprbActualCommit}^...${ghprbActualCommit} --name-only | egrep -E "(^doc/|$INCLUDE_FILES)" > /dev/null
#		if [ $? = 1 ]; then
#			echo "No relevant files changed, skipping run"
#			exit 0
#		fi
#	fi
#fi

vername=${GITHUB_PR_NUMBER}
test -z "${GITHUB_PR_NUMBER}" && vername=${GITHUB_BRANCH}

outputdir="${PWD}/output"
enoutdir="${outputdir}/en/${vername}"
jaoutdir="${outputdir}/ja/${vername}"

sudo chmod -R 777 . || exit 1

cd doc
pipenv install || exit 1

tmpfile=/tmp/build_the_docs.$$

cat << _END_OF_DOC_ > ${tmpfile}
#!/bin/bash
set -e
set -x
cd ..
autoreconf -fi && ./configure --enable-docs
cd doc
echo "Building EN Docs"
rm -rf docbuild/html
make -j4 -e SPHINXOPTS="-D language='en'" html

mkdir -p "${enoutdir}"
cp -rf docbuild/html/* "${enoutdir}"

echo "Building JA Docs"
rm -rf docbuild/html
make -j4 -e SPHINXOPTS="-D language='ja'" html

mkdir -p "${jaoutdir}"
cp -rf docbuild/html/* "${jaoutdir}"
_END_OF_DOC_

chmod 755 ${tmpfile}
echo "Running:"
cat ${tmpfile}
pipenv run ${tmpfile} || exit 1
rm ${tmpfile}

# If we made it here, the doc build ran and succeeded. Let's copy out the
# docbuild contents so it can be published.
ls "${outputdir}"
cd "${outputdir}"

sudo chmod -R u=rwX,g=rX,o=rX . || exit 1

#if [ "${PUBLISH_DOCS}" == "true" ]; then
#	sudo cp -avx ja /home/docs
#	sudo cp -avx en /home/docs
#	/home/docs/docs_purge.sh ${vername}
#fi

exit 0
