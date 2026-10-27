#!/bin/bash

if [ -d HMM/build ]; then
  rm -r HMM/build
fi

cd HMM
mkdir build
cd build
cmake ..
make -j 4