#! /usr/bin/env bash

MARGS=""

for A in "$@" ; do
    MARGS="$RARGS ${A/test\/FlFrameworkTestApp\//}"
done

echo "running in the test app directory (test/FlFrameworkTestApp)"
cd test/FlFrameworkTestApp

echo "running test command: bash $0 $MARGS"
bash $0 $MARGS
