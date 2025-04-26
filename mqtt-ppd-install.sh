#!/bin/bash

pushd mqtt-ppd
  make clean && make && make install
popd
