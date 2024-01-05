#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function suggest_add_by_fext () {
  export LANG{,UAGE}=C

  local STATUS_ARGS=(
    --porcelain -z
    --untracked-files=all
    )
  local -A CFG=()
  local GIT_REPO_PATH="$(readlink -m -- "$(git rev-parse --git-dir)")"
  [ -d "$GIT_REPO_PATH" ] || return 2$(
    echo 'E: unable to determine git repo path!' >&2)
  local GIT_ROOT_PRFX="$(git rev-parse --show-prefix)"
  [ "$GIT_ROOT_PRFX" == / ] || GIT_ROOT_PRFX="${GIT_ROOT_PRFX%/}"
  local GIT_ROOT_CDUP="$(git rev-parse --show-cdup)"
  case "$GIT_ROOT_CDUP" in
    '' | */ ) ;;
    * ) GIT_ROOT_CDUP+=/;;
  esac
  if [ "${GIT_ROOT_CDUP:0:1},${GIT_ROOT_PRFX:0:1}" == '/,' ]; then
    # i.e. GIT_ROOT_CDUP is an absolute path and GIT_ROOT_PRFX is empty,
    #   probably because $PWD is inside a bare repo with a worktree.
    GIT_ROOT_PRFX="$GIT_ROOT_CDUP"
  fi

  CFG[rslt-lst]="$GIT_REPO_PATH"/gax-suggest.lst

  local -A STATS=()
  STATS[warn]=0
  local OPT=
  while [ "$#" -gt 0 ]; do
    OPT="$1"; shift
    case "$OPT" in
      -v ) OPT=--verbose;;
    esac
    case "$OPT" in
      '' ) ;;
      --add-deleted | \
      --add-huge | --add-tiny | \
      --add-links | --add-texts | \
      --add-blobs | --add-non-blobs )
        CFG[auto-add:some]=+
        OPT="${OPT#--add-}"
        OPT="${OPT%s}"
        CFG[auto-add:"$OPT"]=+;;
      --verbose )
        CFG["${OPT#--}"]=+;;
      -- ) POS_ARGS+=( "$@" ); break;;
      --rslt-lst=* )
        OPT="${OPT#--}"; CFG["${OPT%%=*}"]="${OPT#*=}";;
      -* ) echo "E: $0: unsupported option: $OPT" >&2; return 3;;
      * ) STATUS_ARGS+=( "$OPT" );;
    esac
  done

  local CANDIDATES=()
  readarray -t CANDIDATES < <(git status "${STATUS_ARGS[@]}" \
    | tr '\000' '\n' | sed -re '
    /^R  /{N;s~^R(.) ~RA ~;s~\n~\nRD ~;d}
    ')

  local RSLT_TMP="${CFG[rslt-lst]}.$$.tmp"
  if [ -n "${CFG[rslt-lst]}" ]; then
    >"$RSLT_TMP" || return $?
  fi

  local C_STATE_REPO=
  local C_STATE_WT=
  local C_FN=
  local NL=$'\n'
  local C_GRP=
  local -A BY_GRP=()
  local -A GRP_CNTS=()
  local ADD_WHERE=
  local ADD_DELETED=
  local ADD_ANNEX=()
  local ADD_PLAIN=()
  for C_FN in "${CANDIDATES[@]}"; do
    C_STATE_REPO="${C_FN:0:1}"
    C_STATE_WT="${C_FN:1:1}"
    [ "${C_FN:2:1}" == ' ' ] || continue$(echo "W: expected 3rd character of" \
      "status line to be a space character, not [${C_FN:2:1}]: [$C_FN]" >&2)
    C_FN="${C_FN:3}"
    [ -n "$C_FN" ] || continue
    if [ "${C_FN:0:1}" == '"' ]; then
      echo "E: Strange filename: ‹$C_FN›" >&2
      return 8
    fi
    case "$C_FN" in
      "${GIT_ROOT_PRFX:-///}"/* ) C_FN="${C_FN#$GIT_ROOT_PRFX/}";;
      * ) C_FN="$GIT_ROOT_CDUP$C_FN";;
    esac
    if [ -n "${CFG[rslt-lst]}" ]; then
      case "/$C_FN" in
        */"${CFG[rslt-lst]}".*.tmp | \
        */"${CFG[rslt-lst]}" ) continue;;
      esac
    fi
    C_GRP=
    [ "$C_STATE_WT" == D ] && C_GRP='!deleted'
    [ -n "$C_GRP" ] || C_GRP="$(suggest_group "$C_FN")"
    case "$C_GRP" in
      '!non-file' ) continue;;
      '!git-repo' )
        pwarn "skip: git-repo: $C_FN"
        continue;;
      '!deleted' )
        ADD_WHERE=plain
        ADD_DELETED='--all'
        [ -n "${CFG[auto-add:deleted]}" ] && ADD_WHERE+=+
        C_GRP="${C_GRP:1}";;
      '!'* ) echo "E: failed to guess: ${C_GRP#\!}: $C_FN"; return 7;;
      '+'* )
        ADD_WHERE=annex
        [ -n "${CFG[auto-add:blob]}" ] && \
          filename_looks_sane_for_annex "$C_FN" && ADD_WHERE+=+
        C_GRP="${C_GRP:1}";;
      '='* )
        ADD_WHERE=plain
        [ -n "${CFG[auto-add:non-blob]}" ] && ADD_WHERE+=+
        C_GRP="${C_GRP:1}";;
    esac
    [ -n "$C_GRP" ] || C_GRP='??'
    [ -n "${CFG[auto-add:${C_GRP%%.*}]}" ] && ADD_WHERE+=+
    case "$GIT_ROOT_CDUP" in
      /* ) C_FN="${C_FN#${GIT_ROOT_CDUP%/}/}";;
    esac
    case "$ADD_WHERE" in
      annex+* ) ADD_ANNEX+=( "$C_FN" );;
      plain+* ) ADD_PLAIN+=( "$C_FN" );;
    esac
    if [ -n "${CFG[rslt-lst]}" ]; then
      printf "%s\t%s\n" "$C_GRP" "$C_FN" >>"$RSLT_TMP"
    fi
    [ -n "${BY_GRP[$C_GRP]}" ] && BY_GRP["$C_GRP"]+="$NL"
    BY_GRP["$C_GRP"]+="$C_FN"
    let GRP_CNTS["$C_GRP"]="${GRP_CNTS[$C_GRP]:-0}+1"
  done

  local GRP_NAMES=()
  readarray -t GRP_NAMES < <(printf '%s\n' "${!BY_GRP[@]}" | sort -Vu)
  GRP_CNTS[';counts']=
  GRP_CNTS[';total']=0
  for C_GRP in "${GRP_NAMES[@]}"; do
    [ -n "$C_GRP" ] || continue
    GRP_CNTS[';counts']+="${GRP_CNTS[$C_GRP]} $C_GRP$NL"
    let GRP_CNTS[';total']="${GRP_CNTS[;total]}+${GRP_CNTS[$C_GRP]}"
  done

  echo -n "# type counts: *:${GRP_CNTS[;total]}"
  <<<"${GRP_CNTS[;counts]}" sort -rg | sed -nre '
    s~^\s*([0-9]+)\s+(.*$)~\2:\1~p' | sed -re '
    s~^~, ~
    ' | tr -d '\n'
  echo

  if [ "${#ADD_ANNEX[@]}" -gt 0 ]; then
    echo "# auto-add to annex: ${#ADD_ANNEX[*]}"
    dump_list_if_verbose "${ADD_ANNEX[@]}"
    git annex add "${ADD_ANNEX[@]}" || return $?
  fi
  if [ "${#ADD_PLAIN[@]}" -gt 0 ]; then
    echo "# auto-add directly: ${#ADD_PLAIN[*]}"
    dump_list_if_verbose "${ADD_PLAIN[@]}"
    git add $ADD_DELETED "${ADD_PLAIN[@]}" || return $?
  fi

  if [ -n "${CFG[verbose]}" ]; then
    for C_GRP in "${GRP_NAMES[@]}"; do
      [ -n "$C_GRP" ] || continue
      echo "# type: $C_GRP"
      echo "${BY_GRP[$C_GRP]}"
    done
  fi

  if [ -s "${CFG[rslt-lst]}" ]; then
    mv -- "$RSLT_TMP" "${CFG[rslt-lst]}"
    # echo -n "# list: "; wc -l "${CFG[rslt-lst]}"
  else
    [ ! -f "$RSLT_TMP" ] || rm -- "$RSLT_TMP"
  fi

  if [ "${STATS[warn]}" != 0 ]; then
    echo -n '# messages:'
    for C_GRP in warn; do
      echo -n " $C_GRP:${STATS[$C_GRP]}"
    done
    echo
  fi
  return 0
}


function dump_list_if_verbose () {
  [ -n "${CFG[verbose]}" ] || return $?
  printf '%s\n' "$@" | nl -ba | sed -re 's~^ ?~#~'
}


function suggest_group () {
  local FN="$1"
  if [ "${FN%/}" != "$FN" ]; then
    if lookslike_git_repo "$FN"; then echo '!git-repo'; return 0; fi
    echo '!dir'; return 0
  fi
  if [ -L "$FN" ]; then echo =link; return 0; fi
  [ -f "$FN" ] || echo "non-file: $FN" >&2
  if [ ! -f "$FN" ]; then echo '!non-file'; return 2; fi
  local F_SIZE="$(stat -c '%s' -- "$FN")"
  if [ -z "$F_SIZE" ]; then echo '!no-size'; return 2; fi
  if [ "${F_SIZE}" -le 256 ]; then echo =tiny; return 0; fi
  if [ "${F_SIZE}" -ge 1024000 ]; then echo +huge; return 0; fi

  case "${FN,,}" in
    *.maff | *.cab | *.rar | \
    *.zip | *.gz | *.tar | *.tgz )
      echo +blob.compressed; return 0;;
    *.bmp | *.svg | *.png | \
    *.gif | *.jpg | *.jpeg )
      echo +blob.image; return 0;;
    *.mid | *.ogg | *.flac | *.aac | *.wma | \
    *.wav | *.mp2 | *.mp3 )
      echo +blob.audio; return 0;;
    *.html | *.css | *.js | *.txt )
      echo =text; return 0;;
  esac
  F_TYPE="$(file --brief --mime -- "$FN" | sed -rf <(echo '
    s~; charset=(binary)$~\n\1~
    s~; ~;~g
    s~\n~,~g
    s~\s~_~g
    ') )"
  case "$F_TYPE" in
    application/postscript | \
    application/postscript';charset='* | \
    text/* )
      echo =text; return 0;;
    image/* )
      echo +blob.image; return 0;;
    application/zip | \
    application/*-compressed,binary )
      echo +blob.compressed; return 0;;
    application/*,binary | \
    application/octet-stream )
      echo +blob; return 0;;
  esac
  echo "?$F_TYPE?"
}


function pwarn () {
  echo "W: $*" >&2
  let STATS[warn]="${STATS[warn]}+1"
}


function filename_looks_sane_for_annex () {
  local FN="$1"
  local BFN="$(basename -- "$FN")"
  local FXT="${BFN##*\.}"
  [ "${#FXT}" -le 6 ] || return 1$(pwarn "long FNE: $FN")
  [ "$FXT" == "${FXT,,}" ] || return 1$(
    pwarn "uppercase letters in FNE: $FN")
  local UNUSUAL="$(<<<"$FXT" grep -oPe '[^a-z0-9]' | sort -u | tr -d '\n')"
  [ -z "$UNUSUAL" ] || return 1$(
    pwarn "unusual characters in FNE: [$UNUSUAL], $FN")
}


function lookslike_git_repo () {
  local REPO_DIR="$1"
  [ -d "$REPO_DIR"/.git ] && REPO_DIR+=/.git
  [ -f "$REPO_DIR"/config ] || return 1
  [ -f "$REPO_DIR"/HEAD ] || return 1
  [ -d "$REPO_DIR"/logs/refs ] || return 1
  [ -d "$REPO_DIR"/objects/info ] || return 1
  [ -d "$REPO_DIR"/refs ] || return 1
  return 0
}
















suggest_add_by_fext "$@"; exit $?
