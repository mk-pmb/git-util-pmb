#!/bin/sed -rf
# -*- coding: UTF-8, tab-width: 2 -*-

1{/^#? ?On branch \S+$/{N
  s~\n#?Your branch is( ahead of )~,\1~
}}
