#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function glfd_cli_main () {
  local DBGLV="${DEBUGLEVEL:-0}"
  local KEY= VAL=
  local GIT_OPT=( --pretty='format:@%at %ct %H %s' --numstat )

  local -A FLAGS=(
    [abbrev]=+
    [author-date]=-
    [commit-date]=-
    [earliest]=+
    [hash]=+
    [headings]=+
    [json-date]=-
    [latest]=+
    [local-date]=+
    [mention-date]=+
    [subj]=-
    [uts]=-
    [reverse]=-
    )
  local -A CFG=(
    [sort_cmp]='version-sort'
    [sort_what]='filename'
    )

  while [ "${1:0:1}" == - ]; do
    # Check very simple options:
    case "$1" in
      -- ) shift; break;;

      --sort=filename | \
      --sort=table | \
      --sort=no ) CFG[sort_what]="${1#*=}"; shift; continue;;
      --sort=* ) echo E: 'unsupported sort criterion' >&2; return 4;;

    esac
    # Check if arg may be a flag option:
    KEY="${1#--}"
    if [ -n "${FLAGS[${KEY#no-}]}" ]; then
      VAL=-
      [ "${KEY:0:3}" == no- ] || VAL=+
      FLAGS["${KEY#no-}"]="$VAL"
      shift
      continue
    fi
    GIT_OPT+=( "$1" )
    shift
  done

  local SORT_CMD='sort'
  [ -z "${CFG[sort_cmp]}" ] || SORT_CMD+=" --${CFG[sort_cmp]}"
  [ "${FLAGS[reverse]}" == - ] || SORT_CMD+=' --reverse'

  local -A DB=(
    # Database key format: [el][aco]:<filename>
    #   [el] = `e`arliest or `l`atest
    #   [acm] = `a`uthor or `c`ommit date or `m`ention
    # Value format: <uts><space><hash><space><subject>
    )

  glfd_read_db < <(git log "${GIT_OPT[@]}" "$@") || return $?
  [ "${FLAGS[headings]}" == - ] || glfd_print_headings || return $?
  case "${CFG[sort_what]}" in
    table ) exec > >( $SORT_CMD );;
  esac
  glfd_print_results || return $?

  # Close stdout and wait until potential stdout pipes are done:
  exec >&-
  wait
  # Give the potential stdout pipes a bit more time to print their output
  # before the user's shell will print its prompt:
  tty --silent && sleep 0.1s
}


function glfd_read_db () {
  local COMMIT_TITLE_LINE_RGX='^\S+ '

  local FILE_NAME_LINE_RGX='^-?[0-9]*\t-?[0-9]*\t'
  # The regexp slightly overmatches: In addition to positive numbers
  # and a solitary hyphen-minus (for symlink entries), it may also
  # match negative numbers and empty tabulated cells, which doesn't
  # matter because they won't be in the input.
  # Even if someone uses two tabulators in their commit title and the
  # commit SHA-1 happens to be all numeric, the SHA-1 and commit title
  # will be separated by a space, and thus won't match here.

  local SUSPICIOUS_FILENAME_RGX='[^A-Za-z0-9_=@:./+-]'

  local -A COMMIT=( [a_uts]=0 [c_uts]=0 )
  local FILE= EVENT_TYPE= TIME_DIRECTION= CMP_OP= CMP_VAL=
  while IFS= read -rs VAL; do
    case "$VAL" in
      '@'* )
        VAL="${VAL:1}"
        VAL="${VAL//$'\n'/ }"
        VAL="${VAL//$'\r'/}"
        VAL="${VAL//$'\t'/ }"
        COMMIT[a_uts]="${VAL%% *}"; VAL="${VAL#* }"
        COMMIT[c_uts]="${VAL%% *}"; VAL="${VAL#* }"
        COMMIT[hash]="${VAL%% *}"; VAL="${VAL#* }"
        COMMIT[subj]="$VAL"
        [ "$DBGLV" -lt 2 ] || local -p | grep -Pe '^COMMIT=' >&2
        ;;

      [0-9-]*$'\t'[0-9-]*$'\t'* )
        FILE="${VAL#*$'\t'*$'\t'}"
        for EVENT_TYPE in a c; do
          CMP_VAL="${COMMIT[${EVENT_TYPE}_uts]}"
          for KEY in e-lt l-gt; do
            TIME_DIRECTION="${KEY:0:1}"
            CMP_OP="${KEY:1}"
            KEY="${TIME_DIRECTION}${EVENT_TYPE}:$FILE"
            VAL="${DB[$KEY]%% *}"
            [ "$DBGLV" -lt 2 ] || echo "  $KEY:" \
              "(db) ${VAL:-°} $CMP_OP ${CMP_VAL:-°} (current commit)?"
            [ -z "$VAL" ] || [ "${VAL:-0}" $CMP_OP "${CMP_VAL:-0}" ] || VAL=
            if [ -z "$VAL" ]; then
              VAL="$CMP_VAL ${COMMIT[hash]} ${COMMIT[subj]}"
              DB["$KEY"]="$VAL"
              [ "$DBGLV" -lt 2 ] || printf -- '\t%s\t%s\n' "$KEY" "$VAL" >&2
              # also set "mention" date:
              DB["${TIME_DIRECTION}m:$FILE"]="$VAL"
            fi
          done
        done
        ;;
    esac
  done
}


function glfd_print_headings () {
  local BUF= ROW_SEMIFIXED= ROW_VARLEN=
  for TIME_DIRECTION in earliest latest; do
    [ "${FLAGS[$TIME_DIRECTION]}" == + ] || continue
    for EVENT_TYPE in author commit mention; do
      BUF="${TIME_DIRECTION}_${EVENT_TYPE}_"
      [ "${FLAGS[${EVENT_TYPE}-date]}" == + ] || continue
      for KEY in uts {local,json}-date hash; do
        [ "${FLAGS[$KEY]}" == + ] || continue
        ROW_SEMIFIXED+="$BUF${KEY//-/_}"$'\t'
      done
      for KEY in subj; do
        [ "${FLAGS[$KEY]}" == + ] || continue
        ROW_VARLEN+=$'\t'"$BUF${KEY//-/_}"
      done
    done
  done
  echo "${ROW_SEMIFIXED}filename${ROW_VARLEN}"
}


function glfd_print_results () {
  local BUF= ROW_SEMIFIXED= ROW_VARLEN=

  # Read (and maybe sort) filenames:
  BUF='cat'
  case "$OUTPUT_SORT_MODE" in
    table ) ;;
    no ) ;;
    filename ) BUF="$SORT_CMD";;
  esac
  local FILES=()
  readarray -t FILES < <(printf -- '%s\n' "${!DB[@]}" |
    sed -nre 's~^lc:~~p' | $BUF)

  for FILE in "${FILES[@]}"; do
    ROW_SEMIFIXED=
    ROW_VARLEN=
    for TIME_DIRECTION in earliest latest; do
      [ "${FLAGS[$TIME_DIRECTION]}" == + ] || continue
      for EVENT_TYPE in author commit mention; do
        [ "${FLAGS[${EVENT_TYPE}-date]}" == + ] || continue
        KEY="${TIME_DIRECTION:0:1}${EVENT_TYPE:0:1}:$FILE"
        BUF="${DB[$KEY]}"

        # First value in BUF is the UTS.
        VAL="${BUF%% *}"; BUF="${BUF#* }"
        [ "${FLAGS[uts]}" == - ] || ROW_SEMIFIXED+="$VAL"$'\t'
        [ "${FLAGS[local-date]}" == - ] || ROW_SEMIFIXED+="$(
          printf '%(%F,%T)T' "$VAL")"$'\t'
        [ "${FLAGS[json-date]}" == - ] || ROW_SEMIFIXED+="$(
          TZ=UTC printf '%(%FT%TZ)T' "$VAL")"$'\t'

        # Next value in BUF is the hash.
        VAL="${BUF%% *}"; BUF="${BUF#* }"
        if [ "${FLAGS[hash]}" == + ]; then
          if [ "${FLAGS[abbrev]}" == + ]; then
            ROW_SEMIFIXED+="${VAL:0:7}"$'\t'
          else
            ROW_SEMIFIXED+="$VAL"$'\t'
          fi
        fi

        # Remaining BUF is the subject.
        [ "${FLAGS[subj]}" == - ] || ROW_VARLEN+=$'\t'"$BUF"
      done
    done
    echo "${ROW_SEMIFIXED}$FILE${ROW_VARLEN}"
  done
}










glfd_cli_main "$@"; exit $?
