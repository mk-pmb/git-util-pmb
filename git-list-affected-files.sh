#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function git_list_affected_files () {
  git log --oneline --numstat "$@" | sed -re '
    /\t/!{
      s~^~\r~ # Add even to 1st line, to not match the numbers regexp!
      s~ ~\t~
      s~$~\t~
    }
    s~^\S+\t\S+\t~ ~
    1s~^\r~~
    $s~$~\r~
    ' | tr -d '\n' | tr '\r' '\n' | sed -re 's~\t$~&/~'
}










git_list_affected_files "$@"; exit $?
