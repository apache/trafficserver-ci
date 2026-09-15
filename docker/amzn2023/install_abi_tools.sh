#!/bin/bash

set -x

rm -rf github
mkdir github
cd github
git clone https://github.com/lvc/installer.git
cd installer
for i in abi-dumper abi-tracker abi-compliance-checker vtable-dumper abi-monitor; do
  sudo make install prefix=/usr/local target=${i}
done
rm -rf github
