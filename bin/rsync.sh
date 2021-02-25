#!/bin/sh

cd /home

# This is for QA2 and QA3
rsync -av jenkins admin 104.130.229.236:/home
rsync -av jenkins admin 119.9.104.189:/home
