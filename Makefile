# Makefile for ExpKit
# Author: Jaeho Shin <netj@cs.stanford.edu>
# Created: 2012-10-30

export PATH := $(PWD)/node_modules/.bin:$(PATH)

export BINDIR         := bin
export TOOLSDIR       := tools
export LIBDIR         := lib
export DATADIR        := data
export GUIDIR         := gui
export DOCSDIR        := docs

PACKAGENAME := exp
PACKAGEEXECUTES := bin/exp

include buildkit/modules.mk

buildkit/modules.mk:
	git submodule init
	git submodule update

gui-test-loop:
	while sleep .1; do EXPROOT="$(PWD)/test-exp"  exp -v gui; done


count-loc:
	@[ -d @prefix@ ] || { echo Run make first; false; }
	wc -l $$(find Makefile @prefix@/{tools,bin} gui/{client,server} -type f) shell/package.json \
	    $$(find * \( -name .build -o -name node_modules \) -prune -false -o -name '.module.*') \
	    | sort -n
