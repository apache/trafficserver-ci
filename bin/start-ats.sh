#!/bin/sh

: ${DIALOG=dialog}
DIAGFILE=/tmp/transient-ats.txt

# Don't use this, it gets removed in the pass "exec" from ATS startup
#trap "rm -f $DIAGFILE" 0 1 2 5 15

# Make sure it's empty
rm -f $DIAGFILE
cp /dev/null $DIAGFILE
chmod og= $DIAGFILE
chown nobody.nobody $DIAGFILE

$DIALOG --title "Apache Traffic Server" --clear --passwordbox "Enter password (transient)" 10 50  2> $DIAGFILE

/usr/local/bin/trafficserver stop
/usr/local/bin/trafficserver start
