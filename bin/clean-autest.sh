#!/bin/sh

cd /tmp
cd /CA/autest || exit

# Nuke all core files
find . -name core.\* -exec rm {} \;

touch .
find . -maxdepth 1 -mtime +14 -exec rm -rf {} \;
for autest in autest-github autest-master autest-9.0.x; do
    cd /tmp
    if [ -d /var/jenkins/workspace/$autest ]; then 
	cd /var/jenkins/workspace/$autest || exit
	find . -maxdepth 1 -mtime +16 -exec rm -rf {} \;
    fi
done
