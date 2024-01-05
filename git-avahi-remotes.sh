#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function avahi_remotes_cli () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local SELFFILE="$(readlink -m -- "$BASH_SOURCE")"
  local SELFPATH="$(dirname -- "$SELFFILE")"
  local SELFNAME="$(basename -- "$SELFFILE" .sh)"
  # cd -- "$SELFPATH" || return $?

  export LANG{,UAGE}=en_US.UTF-8
  local -A CFG=()
  CFG[cache-name]="$GIT_AVAHI_CACHE_NAME"
  CFG[rmtpfx]=avhtmp/
  CFG[oldpfx]="old/${CFG[rmtpfx]}"
  read_git_config || return $?

  local POS_ARGN=( action )
  local POS_ARGS=()
  local HOME_GITS_OPTS_PRFX=avahi-remotes.home-gits

  local OPT="$1"
  if [ "${OPT:0:7}" == --func= ]; then
    "${OPT:7}" "${@:2}"
    return $?
  fi

  local CACHE_BFN=
  if [ -n "${CFG[cache-name]}" ]; then
    CACHE_BFN="$HOME"/.cache/git/avahi/
    mkdir -p "$CACHE_BFN" || return $?
    CACHE_BFN+="${CFG[cache-name]}."
  fi
  if [ "$OPT" == --clear-cache ]; then
    rm -- "${CACHE_BFN:-/#$$#/E/NO_CACHE_NAME/}"*
    return $?
  fi

  while [ "$#" -gt 0 ]; do
    OPT="$1"; shift
    case "$OPT" in
      '' ) ;;
      --help | -h ) show_help; return 0;;
      -- ) POS_ARGS+=( "$@" ); break;;
      --*=* )
        OPT="${OPT#--}"
        CFG["${OPT%%=*}"]="${OPT#*=}";;
      -* ) return 1$(echo "E: $0: unsupported option: $OPT" >&2);;
      * )
        case "${POS_ARGN[0]}" in
          '' ) return 1$(echo "E: $0: unexpected positional argument." >&2);;
          '+' ) POS_ARGS+=( "$OPT" );;
          * ) CFG["${POS_ARGN[0]}"]="$OPT"; POS_ARGN=( "${POS_ARGN[@]:1}" );;
        esac;;
    esac
  done

  case "${CFG[action]}" in
    subpath )
      home_gits_find_subpath; return $?;;
  esac

  rename_or_rm_remotes_by_prefix avhtmp_

  case "${CFG[action]}" in
    clean )
      rename_or_rm_remotes_by_prefix "${CFG[oldpfx]}" || return $?
      rename_or_rm_remotes_by_prefix "${CFG[rmtpfx]}" || return $?
      return 0;;
    update )
      rename_or_rm_remotes_by_prefix "${CFG[rmtpfx]}" "${CFG[oldpfx]}" \
        || return $?
      home_gits_addrmt || return $?
      rename_or_rm_remotes_by_prefix "${CFG[oldpfx]}" || return $?
      return 0;;
    update-domain-cache )
      avahi-browse --all --no-db-lookup --terminate \
        --domain="${CFG[domain]}" >/dev/null
      return $?;;
  esac

  echo "E: unknown action ${CFG[action]}" >&2
  return 1
}


function read_git_config () {
  local OPTS=(
    domain
    fake-peers-dir
    home-gits-svcrgx
    )
  local OPT=
  for OPT in "${OPTS[@]}"; do
    CFG["$OPT"]="$(git config avahi-remotes."$OPT")"
  done
}


function show_help () {
  local MAXLN=9002
  local ACTION_NAMES=()
  readarray -t ACTION_NAMES < <(
    grep -Fe ' case "${CFG[action]}" in' -m 1 -A "$MAXLN" -- "$SELFFILE" \
    | grep -xPe '\s*esac' -m 1 -B "$MAXLN" | sed -nre '
    s~^\s+([a-z-]+)\s+\)$~\1~p
    ' | sort -Vu)
  echo "actions: ${ACTION_NAMES[*]}"
}


function rename_or_rm_remotes_by_prefix () {
  local OLD_PFX="$1"
  local NEW_PFX="$2"
  [ -n "$OLD_PFX" ] || return 3$(echo "E: $FUNCNAME: no OLD_PFX given" >&2)

  if [ -n "$NEW_PFX" ]; then
    echo -n "I: Rename old remotes $OLD_PFX* -> $NEW_PFX*: "
  else
    echo -n "I: Remove old remotes $OLD_PFX*: "
  fi

  local OLD_RMTS=()
  readarray -t OLD_RMTS < <(git remote)
  local RMT_CNT=0
  local OLD_RMT=
  local RMT_BN=
  for OLD_RMT in "${OLD_RMTS[@]}"; do
    RMT_BN="${OLD_RMT#$OLD_PFX}"
    [ "$RMT_BN" == "$OLD_RMT" ] && continue
    echo -n "$RMT_BN "
    let RMT_CNT="$RMT_CNT+1"
    if [ -n "$NEW_PFX" ]; then
      git remote rename "$OLD_RMT" "$NEW_PFX$RMT_BN" || return $?
    else
      git remote rm "$OLD_RMT" || return $?
    fi
  done
  echo "(n=$RMT_CNT)"
  return 0
}


function guess_pwd_repo_top() {
  local REPO_ABS="$(git rev-parse --show-toplevel)"
  local SUBPATH="$(git rev-parse --show-prefix)"
  SUBPATH="/${SUBPATH%/}"
  local PWD_REPO="${PWD%$SUBPATH}"
  if [ "$(readlink -m -- "$PWD_REPO")" == "$REPO_ABS" ]; then
    echo "$PWD_REPO"
    return 0
  fi
  echo "$REPO_ABS"
}


function check_rebase_parent_abspath () {
  # Try to infer an alternate path to a parent directory based on
  # the ("alternate") path (ALTN_PATH) of one if its subdirs
  local ORIG_ABS="$1"; shift
  local ALTN_PATH="$1"; shift
  local ALTN_ABS="$(readlink -m -- "$ALTN_PATH")"
  ORIG_ABS="${ORIG_ABS%/}"
  ALTN_ABS="${ALTN_ABS%/}"
  local SUB_PATH=
  local REBASED=
  case "$ALTN_ABS" in
    "$ORIG_ABS" )
      echo "$ALTN_PATH"
      return 0;;
    "$ORIG_ABS"/* )
      SUB_PATH="${ALTN_ABS#$ORIG_ABS/}"
      REBASED="${ALTN_PATH%/$SUB_PATH}"
      if [ "$(readlink -m -- "$REBASED")" == "$ORIG_ABS" ]; then
        echo "$REBASED"
        return 0
      fi
      ;;
  esac
  return 1
}


function home_gits_glob () {
  local ARG=
  for ARG in "$@"; do
    case "$ARG" in
      '' ) continue;;
      "$HOME/"* ) ;;
      '~/'* ) ARG="$HOME${ARG:1}";;
      * )
        echo "W: $FUNCNAME: paths must begin with '~/'. skipped: $ARG" >&2
        return 3;;
    esac
    case "$ARG" in
      *'*' )
        for ARG in "${ARG%\*}"*; do
          [ -d "$ARG" ] || continue
          echo "$ARG"
        done;;
      * ) echo "$ARG";;
    esac
  done
}


function home_gits_resolve () {
  # In order to prefer the longest prefix in the resolved path,
  # put the resolved paths in front.
  local ABS=
  for ARG in "$@"; do
    [ -n "$ARG" ] || continue
    ABS="$(readlink -m -- "$ARG")"
    [ -n "$ABS" ] || continue
    ARG="${ARG%/}/"
    ABS="${ABS%/}/"
    printf '%08d\t%s\t%s\n' "${#ABS}" "$ABS" "$ARG"
  done
}


function matches_any_prefix () {
  local TEXT="$1"; shift
  local PRFX=
  for PRFX in "$@"; do
    # echo "? $TEXT" >&2; echo "< $PRFX" >&2
    case "$TEXT" in
      "$PRFX"* ) echo "$PRFX"; return 0;;
    esac
  done
  return 1
}


function home_gits_check_avoid_paths () {
  local AVOID=
  local ERR=
  for AVOID in "$@"; do
    case "$AVOID" in
      *'*' ) ERR='should not end with "*"';;
      '~/'* ) ;;
      * ) ERR='must begin with "~/"';;
    esac
    [ -z "$ERR" ] && continue
    echo "E: ${HOME_GITS_OPTS_PRFX}-avoid: $ERR: $AVOID" >&2
    return 2
  done
  return 0
}


function home_gits_find_subpath () {
  local REPO_PATH="$1"
  [ -d "$REPO_PATH" ] || REPO_PATH="$(guess_pwd_repo_top)"
  [ -d "$REPO_PATH" ] || return 1$(
    echo "E: no repo path given and unable to detect any." >&2)

  local CHK_SYML_OPT="$HOME_GITS_OPTS_PRFX"-check-symlinks

  local ABS_HOME="$(readlink -m -- "$HOME")"
  local REPO_ABS="$(readlink -m -- "$REPO_PATH")"
  local REPO_ALTN="$(check_rebase_parent_abspath "$REPO_ABS" "$PWD")"
  case "$REPO_ALTN" in
    "$HOME" | "$HOME"/* ) ;;
    "$ABS_HOME" | "$ABS_HOME"/* ) REPO_ALTN="$HOME${REPO_ALTN#$ABS_HOME}";;
    * ) REPO_ALTN='';;
  esac
  local CONTENDERS=()
  readarray -t CONTENDERS < <(git config --get-all "$CHK_SYML_OPT")
  readarray -t CONTENDERS < <(home_gits_glob "${CONTENDERS[@]}" | sort -u)
  readarray -t CONTENDERS < <(home_gits_resolve "${CONTENDERS[@]}" \
    "$REPO_ALTN" \
    | LANG=C sort --reverse --unique)
  # printf '%s\n' "${CONTENDERS[@]}" >&2

  local AVOID_PRFXS=()
  readarray -t AVOID_PRFXS < <(
    git config --get-all "$HOME_GITS_OPTS_PRFX"-avoid)
  home_gits_check_avoid_paths "${AVOID_PRFXS[@]}" || return $?

  local PATH_FIND=
  local PATH_REPL=
  local HOME_SUB=
  local AVOID=
  local AVOIDED=
  local TAB=$'\t'
  REPO_ABS="${REPO_ABS%/}/"
  for PATH_REPL in "${CONTENDERS[@]}"; do
    PATH_REPL="${PATH_REPL#*$TAB}"   # strip length field
    PATH_FIND="${PATH_REPL%$TAB*}"
    PATH_REPL="${PATH_REPL##*$TAB}"
    case "$PATH_REPL" in
      "$HOME"/* ) PATH_REPL="${PATH_REPL#$HOME/}";;
      * )
        echo "E: $FUNCNAME: PATH_REPL outside home?! $PATH_REPL" >&2
        return 3;;
    esac
    # echo "? [~/]$PATH_REPL <- $PATH_FIND" >&2
    PATH_FIND="${PATH_FIND%/}"
    case "$REPO_ABS" in
      "$PATH_FIND" | "$PATH_FIND/"* )
        #echo "! $PATH_FIND -> [~/]$PATH_REPL" >&2
        HOME_SUB="${REPO_ABS#$PATH_FIND}"
        HOME_SUB="${HOME_SUB#/}"
        HOME_SUB="${PATH_REPL}${HOME_SUB}"
        AVOID="$(matches_any_prefix '~/'"$HOME_SUB" "${AVOID_PRFXS[@]}")"
        if [ -n "$AVOID" ]; then
          AVOIDED+="$AVOID (… ${HOME_SUB#${AVOID#\~/}} ), "
          continue
        fi
        echo "$HOME_SUB"
        return 0;;
    esac
  done

  echo "W: Cannot detect home subpath of repo path $REPO_PATH" >&2
  [ -n "${AVOIDED[0]}" ] && echo W: \
    "These candidate paths were avoided as configured: ${AVOIDED%, }" >&2
  return 1
}


function home_gits_addrmt () {
  [ -n "$REPO_PATH" ] || local REPO_PATH="$(home_gits_find_subpath)"
  home_gits_addrmt__fake_peers || return $?
  home_gits_addrmt__avahi_peers || return $?
}


function home_gits_addrmt__avahi_peers () {
  [ -n "${CFG[home-gits-svcrgx]}" ] || return 0
  [ -n "$REPO_PATH" ] || local REPO_PATH="$(home_gits_find_subpath)"
  [ -n "$REPO_PATH" ] || return 3

  local AVH_PEERS=()
  local PEER_CACHE=
  if [ -n "$CACHE_BFN" ]; then
    PEER_CACHE="$CACHE_BFN"peer-urls.lst
    [ -s "$PEER_CACHE" ] && readarray -t AVH_PEERS <"$PEER_CACHE"
  fi
  if [ -n "${AVH_PEERS[*]}" ]; then
    echo -n 'I: Reading cached peer list: '
  else
    echo -n 'I: Scanning avahi peers: '
    readarray -t AVH_PEERS < <(avahi-find-first-by-regexp \
      --domain="${CFG[domain]}" "${CFG[home-gits-svcrgx]}" \
      --cached --all --url --txt=raw \
      | tee -- "${PEER_CACHE:-/dev/null}")
    [ -n "${AVH_PEERS[0]}" ] || AVH_PEERS=()
  fi
  echo "found ${#AVH_PEERS[@]}."
  [ "${#AVH_PEERS[@]}" == 0 ] && return 0
  local AVH_INFO=()
  local AVH_URL=
  local -A AVH_TXTS=()
  local AVH_TXT=
  local RMT_NAME=
  local RMT_ADDR=

  for AVH_URL in "${AVH_PEERS[@]}"; do
    readarray -t AVH_INFO < <(<<<"$AVH_URL" sed -re '
      s! \x22!\n!
      s!\x22 \x22!\n!g
      s!\x22+ *$!!
      ')
    AVH_URL="${AVH_INFO[0]}"
    case "$AVH_URL" in
      git-*://* ) AVH_URL="${AVH_URL#git-}";;
    esac
    for AVH_TXT in "${AVH_INFO[@]:1}"; do
      case "$AVH_TXT" in
        path=* | \
        keys=* | \
        user=* )
          AVH_TXTS["${AVH_TXT%%=*}"]="${AVH_TXT#*=}";;
      esac
    done
    AVH_URL="${AVH_URL/:\/\//://${AVH_TXTS[user]}@}"
    AVH_URL="${AVH_URL}/${AVH_TXTS[path]}$REPO_PATH"

    RMT_ADDR="${AVH_INFO[0]}/"
    RMT_ADDR="${RMT_ADDR#*://}"
    RMT_ADDR="${RMT_ADDR/\.local:/:}"
    RMT_ADDR="${RMT_ADDR/:22\//\/}"
    RMT_ADDR="${RMT_ADDR%%/*}"
    RMT_ADDR="${RMT_ADDR//[^A-Za-z0-9_]/_}"
    RMT_NAME="${CFG[rmtpfx]}${RMT_ADDR}_${AVH_TXTS[user]}"
    gitrmt_add_nopush "$RMT_NAME" "$AVH_URL" || return $?
  done
}


function home_gits_addrmt__fake_peers () {
  [ -n "${CFG[fake-peers-dir]}" ] || return 0
  [ -n "$REPO_PATH" ] || local REPO_PATH="$(home_gits_find_subpath)"
  [ -n "$REPO_PATH" ] || return 3

  local RMT_CNT=0 RMT_NAME= RMT_ADDR=
  for RMT_ADDR in "${CFG[fake-peers-dir]}"/*/; do
    [ -d "$RMT_ADDR" ] || continue
    RMT_ADDR="${RMT_ADDR%/}"
    RMT_NAME="$(basename -- "$RMT_ADDR")"
    RMT_ADDR="$RMT_ADDR/$REPO_PATH.git"
    [ -f "$RMT_ADDR/config" ] || continue
    RMT_NAME="${CFG[rmtpfx]}$RMT_NAME"
    RMT_ADDR="file://$RMT_ADDR"
    gitrmt_add_nopush "$RMT_NAME" "$RMT_ADDR" || return $?
    (( RMT_CNT+= 1 ))
  done
}


function gitrmt_add_nopush () {
  local RMT_NAME="$1"; shift
  local RMT_URL="$1"; shift
  echo "I: adding remote $RMT_NAME = $RMT_URL"
  git remote add "$RMT_NAME" "$RMT_URL" || return $?
  git remote set-url --push "$RMT_NAME" '' || return $?
}










avahi_remotes_cli "$@"; exit $?
