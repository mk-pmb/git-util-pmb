#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function gax_cli_main () {
  local SELFPATH="$(readlink -m -- "$BASH_SOURCE"/..)"
  source -- "$SELFPATH/with_dotgit_worktree_symlink.sh" --lib || exit $?

  local GAX_ACTION="$1"; shift
  local GAX_CMD=( git-annex )
  local GAX_ARGS=()
  local -A CFG=()
  local VAL=
  export LANG{,UAGE}=C

  case "$GAX_ACTION" in
    --help | help )
      git annex "$GAX_ACTION" "$@" 2>&1 | smart-less-pmb
      return ${PIPESTATUS[0]};;
    auto-add | AA )
      GAX_ARGS+=( --add-blobs )
      GAX_ARGS+=( --add-non-blobs )
      GAX_ACTION='suggest';;
    exec ) GAX_ACTION=; GAX_CMD=();;
    up | upload )
      GAX_ACTION='git-annex-upload-to-all-remotes'
      GAX_CMD=();;
    rekey )
      CFG[announce-rv]=+
      VAL="$(git config --get annex.backends | grep -oPe '^\S+')"
      [ -n "$VAL" ] || return 4$(echo "E: Failed to read config:" \
        "Cannot determine preferred backend!" >&2)
      GAX_ARGS=( "--backend=$VAL" )
      GAX_ACTION='migrate';;
  esac

  case "$GAX_ACTION" in
    init )
      case "$*" in
        '' ) GAX_ARGS=( "$(basename "$PWD") @ $HOSTNAME" );;
        -* ) ;;
        *' @' ) GAX_ARGS=( "$* $HOSTNAME" ); shift "$#";;
      esac;;
    suggest )
      GAX_ACTION='git-annex-suggest-add-by-fext'; GAX_CMD=();;
    syg )
      # GAX_ACTION='sync'; GAX_ARGS=( --content "${GAX_ARGS[@]}" )
      # ^-- "--content" doesn't take path arguments
      GAX_ACTION='gax_sync_and_get'; GAX_CMD=()
      ;;
    unresolve )
      GAX_ACTION="gax_$GAX_ACTION"; GAX_CMD=();;
  esac

  [ -z "$GAX_ACTION" ] || GAX_CMD+=( "$GAX_ACTION" )
  [ -n "$debian_chroot" ] || export debian_chroot='gax'
  [ -n "${CFG[announce-cmd]}" ] \
    && echo "I: gonna run: ${GAX_CMD[*]} ${GAX_ARGS[*]}"

  with_dotgit_worktree_symlink "${GAX_CMD[@]}" "${GAX_ARGS[@]}" "$@"
  local GAX_RV="$?"

  [ -n "${CFG[announce-rv]}" ] \
    && echo "I: finished with rv=$GAX_RV: ${GAX_CMD[*]} ${GAX_ARGS[*]}"

  case "$GAX_ACTION:$GAX_RV" in
    #
    #-----v----------v----------v----------v----------v----------v-----
    *:0 ) ;; # gax succeeded -> skip the hints below this line. -.
    #-----v----------v----------v----------v----------v----------v-----
    #
    upd:* | update:* ) echo "H: Did you mean syg = sync+get?" >&2;;
    * ) echo "W: $GAX_ACTION: rv=$GAX_RV" >&2;;
  esac

  return "$GAX_RV"
}


function undo_auto_sync () {
  local CMSG="$(git log -n 1 --pretty=%B | head --bytes=64)"
  echo "D: check auto-commit: detected commit message: '$CMSG'" >&2
  case "${CMSG,,}" in
    'git-annex in' | \
    'git-annex in '* | \
    'git-annex automatic sync' )
      echo "W: gonna soft-reset: detected commit message: '$CMSG'" >&2
      git reset --soft HEAD~1
      return $?;;
  esac
}


function gax_sync_and_get () {
  echo -n 'prepare sync… '
  git-annex sync
  undo_auto_sync || return $?
  local GET_DOT=
  [ "$#" == 0 ] && GET_DOT=.
  echo -n 'prepare get… '
  git-annex get $GET_DOT "$@"
  local GAX_RV="$?"
  echo "rv[get]=$GAX_RV"
  return "$GAX_RV"
}


function gax_unresolve () {
  local ANX_OBJ="$1"; shift
  case "$ANX_OBJ" in
    .git/annex/* ) ANX_OBJ="./$ANX_OBJ";;
    [A-Za-z0-9_\.\/]* ) ;;
    * ) ANX_OBJ="./$ANX_OBJ";;
  esac
  local ANX_SUB='.git/annex/'
  local REPO_PATH="${ANX_OBJ%/$ANX_SUB*}"
  [ "$REPO_PATH" == "$ANX_OBJ" ] && return 3$(
    echo "E: cannot find repo path in $ANX_OBJ" >&2)
  ANX_OBJ="$ANX_SUB${ANX_OBJ##*/$ANX_SUB}"

  local PRUNES=( '(' -false
    -o -name .git
    -o -name .svn
    ')' -prune ',' )
  find "$REPO_PATH/" -xdev "${PRUNES[@]}" -type l \
    '(' -lname "$ANX_OBJ" -o -lname "*/$ANX_OBJ" ')' \
    "$@" || return $?
}














gax_cli_main "$@"; exit $?
