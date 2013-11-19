#!/usr/bin/env bash
# Markdown-wdiff -- format diff of Markdown files with decoration
# Usage:
#     diff -u old.md new.md | markdown-wdiff.sh
#     git diff origin/master -- README.md docs/tutorial/README.md | markdown-wdiff.sh
#
# Author: Jaeho Shin <netj@cs.stanford.edu>
# Created: 2013-11-18
set -eu

# word diff the given unified diff as input, and format it by hunks
sed '
# format prologue
1,/^diff /{
    /^diff/! s/^/    /
}

# format file headers
/^diff /,/^+++ /{
    /^diff /{
        s|^diff .* \([^/]/\)\(.*\)|<div class="file-start"><code>\2</code></div>|
        a\
\

    }
    /^<div class="file-start">/! s/^/    /
}

# format ins/del of words
s|\[-|<del class="del">|g; s|-]|</del>|g
s|{+|<ins class="ins">|g; s|+}|</ins>|g

# format hunks
/^@@ -.* +.* @@/{
    s| @@.*| @@|
    s|^|<div class="hunk-start"><code>|
    s|$|</code></div>|
}
'

# attach a small stylesheet
echo '
<style>
    .del,.ins{ display: inline-block; margin-left: 0.5ex; }
    .del     { background-color: #fcc; }
         .ins{ background-color: #cfc; }

    pre:first-of-type { width: 78%; margin-left: auto; margin-right: auto; }
    .file-start + p + pre,
    .file-start + pre { margin-left: 61.8%; }
    .file-start,
    .hunk-start{ text-align: right; }

    .file-start code{ font-size: inherit; }

    .file-start/*:not(:first-of-type)*/{
        font-size: 150%;
        margin-top: 23.6%;
        border-bottom: 1ex solid #ccc;
        padding-bottom: 1ex;
    }
    .hunk-start{
        margin-top: 2ex;
        border-bottom: 1ex dashed #ccc;
        padding-bottom: 1ex;
    }
</style>
'
