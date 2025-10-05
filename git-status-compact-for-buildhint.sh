#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-
git log --format=%h -n 10 | tr '\n' :
GIT_STATUS='
  s~^ (\S)~=\1~
  s~^(.) ~\1=~
  s~\.[A-Za-z]{1,8}$~\n&~
  s~^(..) [^\n]*\n?~\1~'
  # ^-- Censor the filename except maybe what was protected by the \n.
GIT_STATUS="$(git status --porcelain -uno | sed -re "$GIT_STATUS" | grep . |
  sort | uniq -c | sed -re 's~^\s*([0-9]+)\s~\1×~')"
GIT_STATUS="${GIT_STATUS//$'\n'/,}"
[ -n "$GIT_STATUS" ] || GIT_STATUS='clean'
echo "$GIT_STATUS"
