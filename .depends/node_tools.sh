#!/bin/sh
# install node modules
set -eu

self=$0
name=`basename "$0" .sh`

cd "$DEPENDSDIR"

mkdir -p "$name"
cd ./"$name"
cp -f ../"$name".json package.json
date >README.md
npm install
cd - >/dev/null

mkdir -p bin
for x in "$name"/node_modules/.bin/*; do
    ln -sfn ../"$x" bin/
done
