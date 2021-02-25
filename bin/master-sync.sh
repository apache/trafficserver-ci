#!/bin/sh

rsync --delete -av /var/jenkins/jobs jenkins:/var/jenkins
rsync --delete --exclude '.snapshot' -av /var/lib/jenkins jenkins:/var/lib
rsync --delete --exclude '.snapshot' -av /home jenkins:/
rsync --delete -av /admin jenkins:/

echo "Only run this once"
echo "rsync -av /etc/httpd jenkins:/etc"
