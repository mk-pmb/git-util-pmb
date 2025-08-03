#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function git_list_affected_files () {
  local FILE_NAME_LINE_RGX='^-?[0-9]*\t-?[0-9]*\t'
  # The regexp slightly overmatches: In addition to positive numbers
  # and a solitary hyphen-minus (for symlink entries), it may also
  # match negative numbers and empty tabulated cells, which doesn't
  # matter because they won't be in the input.
  # Even if someone uses two tabulators in their commit title and the
  # commit SHA-1 happens to be all numeric, the SHA-1 and commit title
  # will be separated by a space, and thus won't match here.

  local SUSPICIOUS_FILENAME_RGX='[^A-Za-z0-9_=@:./+-]'

  local COMMIT_TITLE_LINE_RGX='^[0-9a-f]+ '

  git log --oneline --numstat "$@" | sed -re '
    /'"$FILE_NAME_LINE_RGX"'/{
      : file_name_line
      # extract only the filename:
      s~^\S+\t\S+\t~~

      /^"/!{ # If git has not quoted the filename, maybe we should:
        /'"$SUSPICIOUS_FILENAME_RGX"'/{s~^~"~;s~$~"~}
      }

      # Add separator after file name (the last will be stripped later):
      s~$~ ~

      b common
    }

    /'"$COMMIT_TITLE_LINE_RGX"'/{
      : commit_title_line
      # defuse some control characters in commit title:
      s~\r~ ~g
      s~\t~ ~g

      # Tabulate SHA-1 and title:
      s~^(\S+) ~\r\1\t~
      s~$~\t~

      b common
    }

    : unknown_line_type
    s~\s+~ ~g
    s~^~\r#\t??\t~
    s~$~\r# ~

    : common
    $s~$~\r~
    ' | tr -d '\n' | tr '\r' '\n' | sed -re '
    s~ $~~ # Trim separator after last file
    s~\t$~&/~ # Mark empty commits with path /, a path impossible for git.
    '
}










git_list_affected_files "$@"; exit $?
