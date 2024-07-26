#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function git_grep_blame () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  exec < <(git grep -n "$@" | grep -oPe '^([^:]+):([0-9]+):')
  local BUF= LNUM= FILE= COMMIT= MAIL= UTS=
  while IFS= read -r BUF; do
    BUF="${BUF%:}"
    LNUM="${BUF##*:}"
    FILE="${BUF%:*}"
    BUF="$(git blame -t --show-email -L "$LNUM,$LNUM" -- "$FILE")"
    [ -n "$BUF" ] || continue$(
      echo W: "Failed to git-blame file '$FILE'" >&2)
    COMMIT="${BUF%% *}"; BUF="${BUF#* }"
    MAIL="${BUF%% *}"; BUF="${BUF#* }"
    MAIL="${MAIL#\(}"
    UTS="${BUF%% *}"; BUF="${BUF#* }"
    UTS="${UTS%\)}"
    BUF="${BUF#*\)}"
    BUF="${BUF# }"
    # local -p; echo # printf '%s\t'
    printf -- '%(%F %T)T' "$UTS"
    printf -- '\t%s' "$COMMIT"
    printf -- '\t%s' "$FILE"
    printf -- '\t%s' "$LNUM"
    printf -- '\t%s' "$BUF"
    # printf -- '\t%s' "$MAIL"
    echo
  done
}


git_grep_blame "$@"; exit $?
