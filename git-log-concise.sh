#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function glc_main () {
  set -o pipefail

  local PAGER="$(which -- less more pager 2>/dev/null | grep -m 1 -Pe '^/')"
  [ -z "$PAGER" ] || PAGER="$(basename -- "$PAGER")"
  [ -z "$PAGER" ] || PAGER+=" $($PAGER --help 2>/dev/null |
    grep -m 1 -oPe '(^|\s)--quit-if-one-screen(\s|$)' | grep -oPe '--\S+')"

  if tty -s <&1; then
    [ -n "$GLC_INTERACTIVE" ] || local GLC_INTERACTIVE=true
    if [ -n "$PAGER" ]; then
      "$FUNCNAME" "$@" |& $PAGER
      return $?
    fi
  fi
  [ -n "$GLC_INTERACTIVE" ] || local GLC_INTERACTIVE=false

  local GIT_TASK='log'
  case "$1" in
    --reflog ) GIT_TASK="${1#--}"; shift;;
  esac

  local COLS=(
    '%at</uts>'
    '%aD</wkd>'
    # ^-- The only easy way to get the weekday from git v2.25.1 log
    ' '
    '%ai</tz>'  # Mark timezone so we can delete it
    '    '
    $'\a'   # commit start marker for command generation
    '%h'    # commit hash, abbreviated
    '  '
    '%s'
    )
  case "$1" in
    --authors | --who )
      # Display authors after subjects because our tabulation cannot deal
      # with multi-byte characters and author names are likely to contain
      # them. (I mostly work with en-US repos so their subject lines tend
      # to only use Basic Latin characters.)
      COLS+=( $'\t<author>%aN <%aE>' )
      shift;;
  esac

  local GIT_LOG_REVERSE=
  local GIT_OPTS=(
    --pretty="$(printf -- '%s' "${COLS[@]}")"
    --date=local
    )

  local OPT="$1"
  case "$OPT" in
    --reverse ) GIT_LOG_REVERSE="$OPT"; shift;;
    --bury | \
    --hoist | \
    --redo )
      GIT_OPTS+=( -n )
      GIT_LOG_REVERSE='--reverse'
      shift;;
  esac

  [ "$#" == 0 ] && GIT_OPTS+=( --max-count 5 )

  local LOG_LINES= # Do the real assignment next line to preserve return value
  LOG_LINES="$(glc_core "$@")" || return $?

  case "$OPT" in
    --hoist ) log_sed '2s!  ! ⬐!;$s!   ! ⬊_!';;
    --bury )  log_sed '2s!   ! ⬈‾!;$s!   ! ⬑ !';;
    * );;
  esac
  echo "${LOG_LINES//$'\a'/}"

  case "$OPT" in
    --bury | \
    --hoist | \
    --redo ) glc_summarize_commit_hashes;;
  esac

  return "${PIPESTATUS[0]}"
}


function log_sed () {
  LOG_LINES="$(echo "$LOG_LINES" | sed -re "$*")"
}


function glc_core () {
  local SED='
    # We no longer need the unix timestamp:
    s~^[0-9]+</uts>~~
    # From first date, we only want the weekday:
    s~,[^<>]*</wkd>~~
    # Kill seconds and timezone:
    s~:[0-9]{2} [+-][0-9]{4}</tz>~~

    s~\t<author>~                                                           &~
    s~^(.{1,100}) *\t<author>~\1 ~
    s~ *\t<author>~ ~
    s~\a<time-travel>([^<>]+)</time-travel>|$\
      ~\x1B[7m !! time travel: \1 !! \x1B[0m~
    '
  LANG=C git "$GIT_TASK" $GIT_LOG_REVERSE "${GIT_OPTS[@]}" "$@" |
    glc_detect_timetravel |
    LANG=C sed -re "$SED"
  local RV="${PIPESTATUS[*]}"
  let RV="${RV// /+}"
  return "$RV"
}


function glc_detect_timetravel () {
  local LN= PREV_UTS= UTS= SECONDS_PER_DAY=86400 N_TT=0
  while IFS= read -r LN; do
    UTS="${LN%%'</uts>'*}"
    LN="${LN#*'</uts>'}"
    glc_detect_timetravel__check || return $?
    echo "$LN"
    PREV_UTS="$UTS"
  done
  glc_detect_timetravel__report
}


function glc_detect_timetravel__check () {
  [ -n "$PREV_UTS" ] || return 0
  local DELTA_SEC= DELTA_DAYS=
  (( DELTA_SEC = UTS - PREV_UTS ))
  [ -z "$GIT_LOG_REVERSE" ] || (( DELTA_SEC = -DELTA_SEC ))
  [ "$DELTA_SEC" -ge 1 ] || return 0
  (( N_TT += 1 ))
  LN+=$'\t\a'"<time-travel>"
  (( DELTA_DAYS = DELTA_SEC / SECONDS_PER_DAY ))
  [ "$DELTA_DAYS" == 0 ] || LN+="${DELTA_DAYS}d+"
  LN+="$(TZ=UTC printf -- '%(%T)T' "$DELTA_SEC")"
  LN+='</time-travel>'
}


function glc_detect_timetravel__report () {
  local WHAT_WHERE='time travel in the time period shown.'
  if [ "$N_TT" != 0 ]; then
    echo W: "Found $N_TT occurrences of apparent $WHAT_WHERE" >&2
    return 0
  fi
  $GLC_INTERACTIVE || return 0
  echo "# Found no evidence of $WHAT_WHERE"
}


function glc_summarize_commit_hashes () {
  local HASHES="$(echo "$LOG_LINES" | cut -d $'\a' -sf 2- | cut -d ' ' -sf 1)"
  HASHES="${HASHES//$'\n'/ }"
  local BASE="${HASHES%% *}"
  local LATEST="${HASHES##* }"
  local CHERRIES="${HASHES#* }"
  case "$OPT" in
    --bury  )
      CHERRIES="'$LATEST' $CHERRIES"
      LATEST="${CHERRIES##* }"
      CHERRIES="${CHERRIES% *}"
      ;;
    --hoist ) CHERRIES="${CHERRIES#* } '${CHERRIES%% *}'";;
  esac
  echo "# git stash" \
    "&& git reset --hard $BASE" \
    "&& git chp $CHERRIES" \
    "&& git diff $LATEST"
}






















glc_main "$@"; exit $?
