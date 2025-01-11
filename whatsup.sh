#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function whatsup_cli_main () {
  # whazzuuuuuuuuuppp? extended git-status.
  local GIT_STATUS_ARGS=( "$@" )
  export LANG{,UAGE}=en_US.UTF-8
  local SELFPATH="$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")" # busybox

  local COLUMNS="$(stty size 2>/dev/null | grep -oPe '\d+$')"
  COLUMNS="${COLUMNS:-80}"

  local GIT_TOPLEVEL="$(git rev-parse --show-toplevel)"
  local GIT_STATUS_OPTS=(
    -c color.status=always
    )

  local SEDFMT="$SELFPATH/fmt.|.sed"

  local IMPORTANT_HINTS=()
  maybe_warn_broken_basic_programs || return $?
  maybe_warn_gitfile || return $?

  ( print_important_hints
    [ -d "$GIT_TOPLEVEL" ] || return 4
    git branch -v
    git-log-concise -n 3 | cut -b 1-$(( $COLUMNS - 1 )) |
      "${SEDFMT//|/colorize_concise_log}"
    git "${GIT_STATUS_OPTS[@]}" status "${GIT_STATUS_ARGS[@]}" |
      "${SEDFMT//|/unclutter_git_status.stage1}" |
      "${SEDFMT//|/unclutter_git_status.finally}"
    print_important_hints
  ) |
    "${SEDFMT//|/colorize_loglevels}" |
    "${SEDFMT//|/lookup_colornames}" |
    smart-less-pmb
  return 0
}


function imphint () { IMPORTANT_HINTS+=( "$*" ); }


function print_important_hints () {
  [ "${#IMPORTANT_HINTS[@]}" -ge 1 ] || return 0
  # ^-- With no arguments, printf would hallucinate an empty string argument.
  printf '%s\n' "${IMPORTANT_HINTS[@]}"
}


function maybe_warn_broken_basic_programs () {
  local VAL=
  for VAL in {/usr,/opt,}/bin/sed; do
    [ -x "$VAL" ] || continue
    [ "$(echo -e '\x0C' | "$VAL" -re 's~\f~F~')" == F ] ||
      imphint W: "Your $VAL does not understand '\f'."
  done
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
  [[ "$GITDIR" == */ ]] && imphint "W: gitfile path ends in '/'"
  maybe_warn_gitfile__check_fstype || return $?
}


function maybe_warn_gitfile__check_fstype () {
  local MSG="H: gitfile points to $GD_HR"
  local GD_FS="$(stat --file-system -c %T -- "$GITDIR")"
  local WD_FS="$(stat --file-system -c %T -- .)"
  [ "$GD_FS" == "$WD_FS" ] || case "$WD_FS -> $GD_FS" in
    ext[0-9]*' -> 'ext[0-9]* ) ;;
    * )
      MSG="W${MSG:1} which uses a different file system ($GD_FS) $(
        )than this worktree ($WD_FS)."
      MSG+=" The report thus ignored file permissions."
      GIT_STATUS_OPTS+=( -c core.filemode=false )
      ;;
  esac
  imphint "$MSG"
}







whatsup_cli_main "$@"; exit $?
