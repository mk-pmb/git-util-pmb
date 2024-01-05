#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function whatsup_cli_main () {
  # whazzuuuuuuuuuppp? extended git-status.
  local GIT_STATUS_ARGS=( "$@" )
  export LANG{,UAGE}=en_US.UTF-8

  local COLUMNS="$(stty size 2>/dev/null | grep -oPe '\d+$')"
  COLUMNS="${COLUMNS:-80}"

  local GIT_TOPLEVEL="$(git rev-parse --show-toplevel)"
  local WARNINGS="$(collect_warnings)"
  ( [ -z "$WARNINGS" ] || echo "$WARNINGS"
    git branch -v
    git-log-concise -n 3 | cut -b 1-$(( $COLUMNS - 1 )) | sed -rf  <(echo '
      s~   +~\t~
      s~^([^\t]+)\t(\S+)\s+~· \f<>\1  \f<purple>\2\f<>  ~g
      1{s~^·~→~g; s~(\f<>)  ~ \f<brown>»\1~}
      ') | lookup_colornames
    git -c color.status=always status "${GIT_STATUS_ARGS[@]}" | sed -rf <(echo '
      1{/^#? ?On branch \S+$/{N
        s~\n#?Your branch is( ahead of )~,\1~
      }}
      ') | sed -rf <(echo '
      1{/^#? ?On branch \S+$/d}
      #1{/^#? ?Changes to be committed:$/d}
      #1{/^#? ?Changes not staged for commit:$/d}
      #1{/^#? ?Untracked files:$/d}
      /^#?\s*$/d
      /^#? +\(use "git push" to (publish) /d
      /^#? +\(use "git reset HEAD <file>\.*" to (unstage)[ )]/d
      /^#? +\(use "git add(|\/rm) <file>\.*" to (update|include)[ )]/d
      /^#? +\(use "git checkout -- <file>\.*" to discard changes /d
      s~^#?[^\t\f]*~\f<dimgray>&\f<>~
      ') | lookup_colornames
    [ -z "$WARNINGS" ] || echo "$WARNINGS"
  ) | smart-less-pmb
  return 0
}


function lookup_colornames () {
  sed -rf <(echo '
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
    ')
}


function collect_warnings () {
  (
    maybe_warn_gitfile
  ) | sed -rf <(echo '
    s~^W: ~\f<yellow>&~
    ') | lookup_colornames
}


function maybe_warn_gitfile () {
  [ -f "$GIT_TOPLEVEL/.git" ] || return 0
  local GITDIR="$(sed -nre 's~^gitdir:\s+~~p;q' -- "$GIT_TOPLEVEL/.git")"
  [ -n "$GITDIR" ] || return 0
  local GD_HR="$GITDIR"
  case "$GD_HR" in
    "$HOME" ) GD_HR='~/';;
    "$HOME"/* ) GD_HR='~'"${GD_HR:${#HOME}}";;
  esac
  [[ "$GITDIR" == */ ]] && echo "W: gitfile path ends in '/'"
  [[ "$GITDIR" == */.git ]] && echo "W: gitfile points to $GD_HR =>" \
    "this repo here may have file system limitations that would not apply in" \
    "${GD_HR%.git}."
}







whatsup_cli_main "$@"; exit $?
