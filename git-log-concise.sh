#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function glc_main () {
  set -o pipefail

  if tty --silent <&1; then
    "$FUNCNAME" "$@" | pager $( (
      man pager | grep -Pe '^\s*(-\w |)(or |)--quit-if-one-screen(\s|$)'
    ) | grep -oPe '--\S+' )
    return $?
  fi

  local GIT_TASK='log'
  case "$1" in
    --reflog ) GIT_TASK="${1#--}"; shift;;
  esac

  local COLS=(
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

  local GIT_OPTS=(
    --pretty="$(printf -- '%s' "${COLS[@]}")"
    --date=local
    )

  local OPT="$1"
  case "$OPT" in
    --bury | \
    --hoist | \
    --redo )
      GIT_OPTS+=( --reverse -n )
      shift;;
  esac

  [ "$#" == 0 ] && GIT_OPTS+=( --max-count 5 )

  local LOG_LINES= # Do the real assignment next line to preserve return value
  LOG_LINES="$(glc_core "$@")" || return $?

  case "$OPT" in
    --hoist ) log_sed '2s!  ! ⬐!;$s!   ! ⬊_!' <<<"$LOG_LINES";;
    --bury )  log_sed '2s!   ! ⬈‾!;$s!   ! ⬑ !' <<<"$LOG_LINES";;
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
  LOG_LINES="$(sed -rf <(echo "$*") <<<"$LOG_LINES")"
}


function glc_core () {
  local SED='
    # From first date, we only want the weekday:
    s~,[^<>]*</wkd>~~
    # Kill seconds and timezone:
    s~:[0-9]{2} [+-][0-9]{4}</tz>~~

    s~\t<author>~                                                           &~
    s~^(.{1,100}) *\t<author>~\1 ~
    s~ *\t<author>~ ~
    '
  LANG=C git "$GIT_TASK" "${GIT_OPTS[@]}" "$@" | LANG=C sed -urf <(echo "$SED")
  local RV="${PIPESTATUS[*]}"
  let RV="${RV// /+}"
  return "$RV"
}


function glc_summarize_commit_hashes () {
  local HASHES="$(<<<"$LOG_LINES" cut -d $'\a' -sf 2- | cut -d ' ' -sf 1)"
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
