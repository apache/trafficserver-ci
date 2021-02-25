#!/bin/bash

cd /home/jenkins/RPMS || exit

rm -f CentOS6/*
rm -f CentOS7/*
rm -f F26/*
rm -f F27/*

cd CentOS6 && ln -s ../v7.1.2/*.el6.* . && cd ..
cd CentOS7 && ln -s ../v7.1.2/*.el7.* . && cd ..
cd F26 && ln -s ../v7.1.2/*.fc26.* . && cd ..
cd F27 && ln -s ../v7.1.2/*.fc27.* . && cd ..
