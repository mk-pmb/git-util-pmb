#!/bin/sed -nurf
# -*- coding: UTF-8, tab-width: 2 -*-
#
# Finding the subject of a git patch file is non-trivial because it may
# stretch onto multiple lines.
#
# ATTN: You'll want to check for potential MIME encoding, which is not
#       handled in this simple script. See decode-mime-header-value
#       from text-transforms-pmb.

: skip
  s~^subject:\s+~\n~ig
  /^\n/{s!^\n!!;b subj}
  n
b skip

: subj
  N
  s!\n[ \t]\s*! !g
  /\n/{
    s~\n.*$~~
    s!^\[PATCH[0-9 /]*\]\s+!!
    p
    b skip
  }
b subj
