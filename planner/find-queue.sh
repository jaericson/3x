#!/usr/bin/env bash
# find-queue.sh -- Find current queue based on $_3X_QUEUE
# 
# > . find-queue.sh
# > echo "$queue"
# > cd "$queueDir"
#
# Author: Jaeho Shin <netj@cs.stanford.edu>
# Created: 2013-06-24

_3X_ROOT=$(3x-findroot)
export _3X_ROOT

export _3X_ARCHIVE="$_3X_ROOT"/.3x/files

# some predefined paths
export queueRunner="$TOOLSDIR"/runner

# determine the current queue
: ${_3X_QUEUE:=$(readlink "$_3X_ROOT"/.3x/Q || echo main)}
case $_3X_QUEUE in
    ../run/queue/*)
        # short circuit for symlink
        _3X_QUEUE=${_3X_QUEUE#../run/queue/}
        ;;
    */*)
        # extract queue name if it looks like a path
        _3X_QUEUE=$(readlink -f "$_3X_QUEUE")
        _3X_QUEUE=${_3X_QUEUE#$_3X_ROOT/}
        case $_3X_QUEUE in
            run/queue/*)
                _3X_QUEUE=${_3X_QUEUE#run/queue/}
                ;;
            *)
                error "$_3X_QUEUE: Invalid queue name"
                ;;
        esac
        ;;
esac
export _3X_QUEUE
export queue="run/queue/$_3X_QUEUE"
export queueDir="$_3X_ROOT/$queue"
#[ -d "$queue" ] || error "$_3X_QUEUE: No such queue"

queue-is-active() {
    set -- "$queueDir"/is-active.*
    [ -e "$1" ]
}
