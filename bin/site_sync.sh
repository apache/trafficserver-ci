#!/bin/sh

cd /opt
rsync -av openssl qa1-int:/opt
rsync -av openssl qa2-int:/opt
