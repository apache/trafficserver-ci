#!/bin/sh

cd /CA/clang-analyzer || exit

# Cleanup some empty dirs
rmdir github/*/* 2> /dev/null

for dir in *; do
    if [ -d $dir ]; then
	cd ${dir} || exit # Shouldn't exit here, but safe ...
	for old in $(/usr/bin/ls -1t | egrep '^[0-9\-]+$' | tail -n +21); do
	    rm -rf $old
	done

	# Setup the symlink to the latest report
	latest=$(/usr/bin/ls -1t | egrep '^[0-9\-]+$' | head -1)
	if [ "$latest" != "" -a ! "$(readlink latest)" -ef "$latest" ]; then
	    rm -f latest
	    ln -s $latest latest
	    [ ! -f latest/index.html ] && touch latest/No\ Errors\ Reported

	    # Purge the cached URL
	    curl -o /dev/null -s -X PURGE https://ci.trafficserver.apache.org/files/clang-analyzer/${dir}/latest/
	fi
    cd ..
    fi
done
