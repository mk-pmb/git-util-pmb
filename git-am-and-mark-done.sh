#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function am_and_mark_done () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly

  local -A CFG=(
    [health-check]=
    [limit]=
    [am-flags]=
    [time-travel]='flinch-if-impersonating'
    )
  local PATCH_FILES_TODO=()
  local ARG=
  local N_DONE=0
  local SECONDS_PER_DAY=86400
  while [ "$#" -ge 1 ]; do
    ARG="$1"; shift
    case "$ARG" in
      '' ) continue;;
      -d ) ARG='--committer-date-is-author-date';;
      -F ) ARG='--fully-impersonate-all-authors';;
      -T ) ARG='--time-travel=ignore';;
    esac
    case "$ARG" in
      --committer-date-is-author-date | \
      '' ) CFG[am-flags]+="$ARG "; continue;;

      --fully-impersonate-all-authors | \
      '' ) CFG["${ARG#--}"]=+; continue;;

      --health-check=* | \
      --limit=* | \
      --time-travel=* | \
      '' )
        ARG="${ARG#--}"
        CFG["${ARG%%=*}"]="${ARG#*=}"
        case "$ARG" in
          health-check=* )
            health_check_now 'when parsing the option.' || return $?;;
        esac
        continue;;

      -* ) echo "E: Unsupported option: $ARG" >&2; return 4;;
      *.patch )
        [ -f "$ARG" ] || return 4$(echo "E: not a regular file: $ARG" >&2)
        PATCH_FILES_TODO+=( "$ARG" );;
      * ) set -- "$ARG"*.patch "$@";;
    esac
  done

  check_time_travel || return $?
  [ "${CFG[time-travel]}" == 'check' ] && return 0

  for ARG in "${PATCH_FILES_TODO[@]}"; do
    am_and_mark_done__one "$ARG" || return $?
  done

  [ "$N_DONE" -ge 1 ] || return 4$(echo "E: No filenames or prefixes given" >&2)
}


function am_and_mark_done__one () {
  local SRC="$1"
  [ -z "${CFG[limit]}" ] || [ "$N_DONE" -lt "${CFG[limit]}" ] || return 3$(
    echo "E: Flinching from processing file due to --limit option: $SRC" >&2)
  local WANT_SUBJ="$(git-find-commit-titles-in-patch-file -- "$SRC")"
  case "$WANT_SUBJ" in
    '' ) echo "E: Failed to detect commit title in patch: $SRC" >&2; return 4;;
    *'=?'*'?='* ) decode_want_subj || return $?;;
  esac

  local GIT_ENV=
  if [ -n "${CFG[fully-impersonate-all-authors]}" ]; then
    local PATCH_DATE= AU_NAME= AU_MAIL=
    PATCH_DATE="$(find_patch_header_value Date "$SRC")"
    [ -n "$PATCH_DATE" ] || return 4
    AU_NAME="$(find_patch_header_value From "$SRC")"
    AU_MAIL=
    case "$AU_NAME" in
      *' <'*'@'*'>' )
        AU_NAME="${AU_NAME%'>'}"
        AU_MAIL="${AU_NAME##*'<'}"
        AU_NAME="${AU_NAME%' <'*}"
        ;;
      * )
        echo E: $FUNCNAME: "Unsupported 'From:' header syntax: $AU_NAME" >&2
        return 4;;
    esac
    GIT_ENV+='GIT_COMMITTER_DATE="$PATCH_DATE" '
    GIT_ENV+='GIT_COMMITTER_NAME="$AU_NAME" '
    GIT_ENV+='GIT_COMMITTER_EMAIL="$AU_MAIL" '
  fi

  eval "$GIT_ENV"' vdo git am ${CFG[am-flags]} -- "$SRC"'
  local AM_RV="$?"
  if [ "$AM_RV" != 0 ]; then
    vdo git am --abort
    return "$AM_RV"
  fi

  local CRNT_SUBJ="$(git log -n 1 --pretty=%B | head --lines=1)"
  if [ "$CRNT_SUBJ" != "$WANT_SUBJ" ]; then
    echo "W: expected commit title: $WANT_SUBJ" >&2
    echo "W: actual   commit title: $CRNT_SUBJ" >&2
    echo "W: git am messed up the commit title! Auto-fixing." >&2
    # return 8
    eval "$GIT_ENV"' git commit --amend --message="$WANT_SUBJ"' || return $?
  fi

  health_check_now "after patch $SRC" || return $?
  mv --verbose --no-target-directory -- "$SRC"{,ed} || return $?
  (( N_DONE += 1 ))
}


function find_patch_header_value () {
  # args: header_name_lowercase patch_file
  local VAL="$(sed -nre 's~\s+$~~; /^$/q; s~'^"$1:"'\s+~~ip' -- "$2")"
  case "$VAL" in
    '' ) echo "E: Cannot find any '$1:' header in patch: $2" >&2;;
    *$'\n'* ) echo "E: Found too many '$1:' headers in patch: $2" >&2;;
    * ) echo "$VAL"; return 0;;
  esac
  return 4
}


function health_check_now () {
  eval "${CFG[health-check]}" || return $?$(
    echo "E: Health check failed (rv=$?) ${1:-E_UNKNOWN_OCCASION}" >&2)
}


function vdo () {
  "$@"
  local RV=$?
  if [ "$RV" == 0 ]; then
    echo "D: success: $*"
  else
    echo "W: failed (rv=$RV): $*" >&2
  fi
  return "$RV"
}


function decode_want_subj () {
  local DECODED="$(decode-mime-header-value "$WANT_SUBJ")"
  # ^-- using the decoder from text-transforms-pmb
  case "$DECODED" in
    '' | *'=?'*'?='* )
      echo "E: Failed to decode subject charset encoding: $WANT_SUBJ" >&2
      return 8;;
  esac
  WANT_SUBJ="$DECODED"
}


function check_time_travel () {
  local TT_MODE="${CFG[time-travel]}"
  case "$TT_MODE" in
    *-if-impersonating )
      [ -n "${CFG[fully-impersonate-all-authors]}" ] || return 0
      TT_MODE="${TT_MODE%-if-*}";;
  esac
  case "$TT_MODE" in
    accept | ignore ) return 0;;
    check | validate | flinch ) ;;
    * )
      echo E: $FUNCNAME: "Unsupported setting: --time-travel='$TT_MODE'" >&2
      return 4;;
  esac
  set -- "${PATCH_FILES_TODO[@]}"
  local PREV_UTS=0 TT_PREV_NAME='(improbably old HEAD commit)'
  local KEY= VAL= PATCH_DATE=
  for KEY in commit author ; do
    VAL="$(git show --no-patch --format=%${KEY:0:1}t:%${KEY:0:1}D HEAD)"
    VAL="${VAL:-0}"
    [ "${VAL%%:*}" -ge 1 ] || return 4$(
      echo E: $FUNCNAME: "Unable to find HEAD $KEY date: '$VAL'" >&2)
    [ "${VAL%%:*}" -gt "$PREV_UTS" ] || continue
    PATCH_DATE="${VAL#*:}"
    PREV_UTS="${VAL%%:*}"
    TT_PREV_NAME="(HEAD $KEY date)"
  done

  [ "$TT_MODE" == validate ] && DELTA_SEC="$PREV_UTS" SRC="$TT_PREV_NAME" \
    DELTA_HR=00:00:00 check_time_travel__tabulate

  local TT_NAME_MAXLEN=20
  local TT_FILES=()
  while [ "$#" -ge 1 ]; do
    check_time_travel__one_patch "$1" || return $?
    shift
  done

  [ "${#TT_FILES[@]}" -ge 1 ] || return 0
  echo E: 'Flinching from backwards time travel without option' \
    '--time-travel=ignore.' >&2
  return 4
}


function check_time_travel__one_patch () {
  local SRC="$1"
  local PATCH_DATE="$(find_patch_header_value Date "$SRC")"
  [ -n "$PATCH_DATE" ] || return 4$(echo E: $FUNCNAME: >&2 \
    "Unable to detect patch date in '$SRC'")
  local PATCH_UTS="$(date +%s -d "$PATCH_DATE")"
  [ "${PATCH_UTS:-0}" -ge 1 ] || return 4$(echo E: $FUNCNAME: >&2 \
    "Unable to parse patch date '$PATCH_DATE' in '$SRC'")

  local DELTA_SEC=$(( PATCH_UTS - PREV_UTS ))
  # ^-- e.g. patch at UTS 30, but previous at 40 = -10 sec TT (- = backwards).
  [ "$DELTA_SEC" -ge 0 ] || TT_FILES+=( "$SRC" )

  local DELTA_HR="${DELTA_SEC#-}" DAYS=
  (( DAYS = DELTA_HR / SECONDS_PER_DAY ))
  if [ "$DAYS" == 0 ]; then DAYS=; else DAYS+='d,'; fi
  DELTA_HR="$DAYS$(TZ=UTC printf -- '%(%T)T' "$DELTA_HR")"

  if [ "$TT_MODE" == validate ]; then
    check_time_travel__tabulate
  elif [ "$DELTA_SEC" -lt 0 ]; then
    [ "${#SRC}" -le "$TT_NAME_MAXLEN" ] || SRC="${SRC:0:$TT_NAME_MAXLEN}…"
    echo W: "Backwards time travel: Date '$PATCH_DATE' in '$SRC'" \
      "is $DELTA_HR before '$TT_PREV_NAME'!" >&2
  fi
  PREV_UTS="$PATCH_UTS"
  TT_PREV_NAME="$SRC"
}


function check_time_travel__tabulate () {
  case "$PATCH_DATE" in
    [A-Z][a-z][a-z]', '[0-9]' '* ) PATCH_DATE="${PATCH_DATE/ /  }";;
  esac
  local NEG="${DELTA_SEC:0:1}"
  [ "$NEG" == '-' ] || NEG=
  printf -- '%-31s\t' "$PATCH_DATE"   # usually 31 chars
  printf -- '% 11d\t' "$DELTA_SEC"
  # 10 digits are sufficient for max 32-bit UTS, +1 for sign
  printf -- '% 16s%s\t' "${NEG:-+}$DELTA_HR" "${NEG:+  !!}"
  echo "$SRC"
}


















am_and_mark_done "$@"; exit $?
