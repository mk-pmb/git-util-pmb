#!/bin/sed -rf
# -*- coding: UTF-8, tab-width: 2 -*-

s~\f<(reset|)>~\f<0>~g
s~\f<(bold)>~\f<1>~g
s~\f<(reverse|rev)>~\f<7>~g

s~\f<((dim|)gray)>~\f<90>~g
s~\f<(silver)>~\f<97>~g
s~\f<(brown)>~\f<33>~g
s~\f<(yellow)>~\f<93>~g
s~\f<((dark|)green)>~\f<32>~g
s~\f<(lightgreen)>~\f<92>~g
s~\f<(purple)>~\f<35>~g
s~\f<(blue)>~\f<34>~g
s~\f<((light|sky)blue)>~\f<94>~g
s~\f<(bright purple)>~\f<95>~g

s~\f<([a-z]+)>~\f<0>\f<7>??\1??\f<0>~g
s~\f<([0-9;]+)>~\x1b[\1m~g
