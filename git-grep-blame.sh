#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function git_grep_blame () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  exec < <(git grep -n "$@" | grep -oPe '^([^:]+):([0-9]+):')
  local BUF= LNUM= FILE= COMMIT= OTHER_FILE= MAIL= UTS=
  while IFS= read -r BUF; do
    BUF="${BUF%:}"
    LNUM="${BUF##*:}"
    FILE="${BUF%:*}"
    BUF="$(git blame -t --show-email -L "$LNUM,$LNUM" -- "$FILE")"
    [ -n "$BUF" ] || continue$(
      echo W: "Failed to git-blame file '$FILE'" >&2)
    COMMIT="${BUF%% *}"; BUF="${BUF#* }"
    case "$BUF" in
      '(<'*@*'> '* )
        # Next field is email, as expected
        OTHER_FILE=
        BUF="${BUF#\(\<}";;
      *' (<'*@*'> '* )
        # There is an extra file name listed
        OTHER_FILE="${BUF%% \(\<*}"
        BUF="${BUF#* \(\<}";;
      * )
        echo W: "Found no email address in this line, remainder: ‹$BUF›" >&2
        continue;;
    esac
    MAIL="${BUF%%\> *}"; BUF="${BUF#*\> }"
    UTS="${BUF%% *}"; BUF="${BUF#* }"
    UTS="${UTS%\)}"
    BUF="${BUF#*\)}"
    BUF="${BUF# }"
    # local -p; echo # printf '%s\t'
    printf -- '%(%F %T)T  %s' "$UTS" "$COMMIT"
    printf -- '  %- 40s' "$FILE"
    printf -- '  %- 40s' "$MAIL"
    printf -- '  % 4d' "$LNUM"
    echo "  $BUF"
  done
}


git_grep_blame "$@"; exit $?
