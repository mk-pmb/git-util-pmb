#!/bin/sed -urf
# -*- coding: UTF-8, tab-width: 2 -*-

s~^\* \S+~\f<lightblue>&~       # current branch
s~^\+ \S+~\f<blue>&\f<reset>~   # worktrees
