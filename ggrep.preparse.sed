#!/bin/sed -urf
# -*- coding: UTF-8, tab-width: 2 -*-

# Replace some control characters to make output more readable,
# and to ensure we can safely use them as our own markers:
s~\t~»\t~g
s~\f~¦¦\t~g
s~\r~«\t~g

# Simplify color codes:
s~\x1b\[[0;]*m~\r~g
s~\x1b\[[0-9;]+m~\f~g
s~\f[:-]\r([0-9]+)\f[:-]\r~\t\1\t~
/^\f--\r$/d
