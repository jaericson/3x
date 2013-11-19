#!/usr/bin/env bash
# Summarize commit history and diff of given Markdown files in Git
# Author: Jaeho Shin <netj@cs.stanford.edu>
# Created: 2013-11-18
set -eu

since=$1; shift

# summarize commit history
{
    echo "\$ git log --oneline "$since"..HEAD $*"
    git log --oneline "$since"..HEAD "$@"
} |
sed 's/^/    /'
echo

# and embed the overall word diff
git diff ${GIT_DIFF_OPTS:-} --word-diff --patch-with-stat \
    --minimal --patience \
    "$since" -- "$@" |
markdown-wdiff.sh
