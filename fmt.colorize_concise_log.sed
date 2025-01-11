#!/bin/sed -rf
# -*- coding: UTF-8, tab-width: 2 -*-

s~   +~\t~
s~^([^\t]+)\t(\S+)\s+~· \f<>\1  \f<purple>\2\f<>  ~g
1{s~^·~→~g; s~(\f<>)  ~ \f<brown>»\1~}
