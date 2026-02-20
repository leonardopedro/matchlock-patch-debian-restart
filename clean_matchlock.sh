#!/bin/bash
set -x
cd ../matchlock || exit 1
git checkout .
git clean -fd
find . -name "*.rej" -delete
find . -name "*.orig" -delete
