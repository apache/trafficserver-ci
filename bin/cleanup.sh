#!/bin/sh

cd /var/jenkins/workspace || exit 1

rm -rf in_tree-*/src
rm -rf out_of_tree-*/src
