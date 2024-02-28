#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function why_does_patch_not_apply () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local DBGLV="${DEBUGLEVEL:-0}"
  local PATCH_FILE="$1"; shift
  case "$PATCH_FILE" in
    -0 ) PATCH_FILE="$(ls -- 0*.patch | head --lines=1)";;
  esac
  local PATCH_LINES="$(cat -- "$PATCH_FILE")"
  local ORIG_FILE=
  local DEST_FILE=

  case "$PATCH_LINES" in
    'From '*$'\nSubject: '*$'\n---\n'*$'\ndiff --git '* )
      unpack_git_mail_patch || return $?;;
  esac
  [ -n "$PATCH_LINES" ] || return 4$(echo "E: Empty patch." >&2)

  local HUNK_NUM=0
  local MISMATCHES=0
  while [ -n "$PATCH_LINES" ]; do
    verify_next_hunk || return $?
  done

  if [ "$MISMATCHES" == 0 ]; then
    echo "+OK This patch file should be applicable."
  else
    echo "E: Found $MISMATCHES problems in: $PATCH_FILE" >&2
  fi
  return "$MISMATCHES"
}


function unpack_git_mail_patch () {
  PATCH_LINES="diff --git ${PATCH_LINES#*$'\ndiff --git '}"
  PATCH_LINES="${PATCH_LINES%$'\n'}"
  PATCH_LINES="${PATCH_LINES%$'\n'}"
  local TRAIL="${PATCH_LINES##*$'\n'}"
  [ -n "$TRAIL" ] || return 4$(
    echo "E: Missing git version line below patches" >&2)
  [ -z "${TRAIL//[0-9.]/}" ] || return 4$(
    echo "E: Unsupported git version format: '$TRAIL'" >&2)
  PATCH_LINES="${PATCH_LINES%$'\n'"$TRAIL"}"
  PATCH_LINES="${PATCH_LINES% }"
  PATCH_LINES="${PATCH_LINES%$'\n'--}"
}


function parse_git_patch_header () {
  ORIG_FILE="${PATCH_LINES%%$'\n'*}"
  ORIG_FILE="${ORIG_FILE#diff --git }"
  DEST_FILE="${ORIG_FILE#* }"
  ORIG_FILE="${ORIG_FILE%% *}"
  # ^-- We cannot expect prefixes `a/` amd `b/` here because either side
  #     might be `/dev/null`.
  ORIG_FILE="${ORIG_FILE#a/}"
  DEST_FILE="${DEST_FILE#b/}"
  PATCH_LINES="${PATCH_LINES#*$'\n'}"

  echo "File to be patched: '$DEST_FILE'"
  [ -n "$DEST_FILE" ] || return 4$(echo "E: Empty filename!" >&2)

  case "$PATCH_LINES" in
    'deleted file mode '* | \
    'new file mode '* )
      PATCH_LINES="${PATCH_LINES#*$'\n'}";;
  esac

  if [[ "$PATCH_LINES" == 'similarity index '* ]]; then
    SIMILARITY="${PATCH_LINES%%$'\n'*}"
    SIMILARITY="${SIMILARITY#* * }"
    SIMILARITY="${SIMILARITY%\%}"
    [ "$SIMILARITY" -ge 0 -a "$SIMILARITY" -le 100 ] || return 4$(
      echo "E: Expected similarity index to be 0..100%, not '$SIMILARITY'." >&2)
    PATCH_LINES="${PATCH_LINES#*$'\n'}"
    [[ "$PATCH_LINES" == 'rename from '* ]] || return 4$(
      echo "E: Expected 'rename from' after 'similarity index'" >&2)
    PATCH_LINES="${PATCH_LINES#*$'\n'}"
    [[ "$PATCH_LINES" == 'rename to '* ]] || return 4$(
      echo "E: Expected 'rename to' after 'similarity index'" >&2)
    if [[ "$PATCH_LINES" == *$'\n'* ]]; then
      PATCH_LINES="${PATCH_LINES#*$'\n'}"
    else
      PATCH_LINES=
      return 0
    fi
  fi

  local HASHES="${PATCH_LINES%%$'\n'*}"
  PATCH_LINES="${PATCH_LINES#*$'\n'}"
  case "$HASHES" in
    'index '*..* ) ;;
    * ) echo "E: Unsupported index hashes line: '$HASHES'" >&2; return 3;;
  esac

  local OLD_FILE="${PATCH_LINES%%$'\n'*}"
  PATCH_LINES="${PATCH_LINES#*$'\n'}"
  case "$OLD_FILE" in
    "--- $ORIG_FILE" | \
    "--- a/$ORIG_FILE" | \
    '--- /dev/null' ) ;;
    * )
      echo "E: Unsupported old filename: '$OLD_FILE'," >&2
      echo "E:                  expected '--- a/$ORIG_FILE'" >&2
      return 3;;
  esac

  local NEW_FILE="${PATCH_LINES%%$'\n'*}"
  PATCH_LINES="${PATCH_LINES#*$'\n'}"
  case "$NEW_FILE" in
    "+++ $DEST_FILE" | \
    "+++ b/$DEST_FILE" | \
    '+++ /dev/null' ) ;;
    * )
      echo "E: Unsupported new filename: '$NEW_FILE'," >&2
      echo "E:                  expected '+++ b/$DEST_FILE'" >&2
      return 3;;
  esac
}


function verify_next_hunk () {
  local SIMILARITY=
  case "$PATCH_LINES" in
    'diff --git '* ) parse_git_patch_header || return $?;;
  esac

  (( HUNK_NUM += 1 ))
  echo -n "Checking hunk #$HUNK_NUM: "
  [ -n "${PATCH_LINES:0:1}" ] || case "$SIMILARITY" in
    100 )
      echo 'rename only.'
      return 0;;
    * )
      echo "E: Hunk seems to not contain any diff lines." >&2
      return 5;;
  esac

  local ATAT_LINE="${PATCH_LINES%%$'\n'*}"
  PATCH_LINES="${PATCH_LINES:${#ATAT_LINE}}"
  PATCH_LINES="${PATCH_LINES#$'\n'}"
  case "$ATAT_LINE" in
    '@@ -'*,*' +'*' @@ '* ) ATAT_LINE="${ATAT_LINE%% @@ *} @@";;
  esac
  case "$ATAT_LINE" in
    '@@ -'[0-9,]*' +'[0-9]' @@'* )
      ATAT_LINE="${ATAT_LINE/% @@/,1 @@}";;
  esac
  case "$ATAT_LINE" in
    '@@ -'[0-9]' +'[0-9,]*' @@'* )
      ATAT_LINE="${ATAT_LINE/ +/,1 +}";;
  esac
  case "$ATAT_LINE" in
    '@@ -'[0-9]*,[0-9]*' +'[0-9]*,[0-9]*' @@'* ) ;;
    '@@ -0,0 +'[1-9]*' @@'* ) ATAT_LINE="${ATAT_LINE/ \+/ +0,}";;
  esac
  case "$ATAT_LINE" in
    '@@ -'*,*' +'*,*' @@' ) echo -n "$ATAT_LINE"$'\t';;
    * ) echo "E: Unsupported line numbers line: '$ATAT_LINE'" >&2; return 3;;
  esac

  local -A CUR_HUNK=( [diff]="${PATCH_LINES%%$'\n@@ '*}" )
  CUR_HUNK[diff]="${CUR_HUNK[diff]%%$'\n'[a-z]*}"
  PATCH_LINES="${PATCH_LINES:${#CUR_HUNK[diff]}}"
  PATCH_LINES="${PATCH_LINES#$'\n'}"

  local ATAT_NUMS=( $(
    <<<"$ATAT_LINE" grep -oPe '^@@ \-\d+,\d+ \+\d+,\d+ @@' | tr '@,+-' ' ' ) )
  local PROJ_DIR="${PROJ_DIR%/}"
  [ -z "$PROJ_DIR" ] || PROJ_DIR+=/

  count_line_types
  verify_patch_length old "${ATAT_NUMS[1]}"
  verify_patch_length new "${ATAT_NUMS[3]}"

  local EFF_ORIG_FILE="$PROJ_DIR$ORIG_FILE"
  CUR_HUNK[lines_old]="$(
    [ "${ATAT_NUMS[1]}" == 0 ] || tail --lines="+${ATAT_NUMS[0]}" \
      -- "$EFF_ORIG_FILE" | head --lines="${ATAT_NUMS[1]}"; echo : )"
  CUR_HUNK[lines_exp]="$(
    <<<"${CUR_HUNK[diff]}" sed -nre 's!^( |\-|$)!!p'; echo :)"
  local SIDE= BUF=
  for SIDE in old exp; do
    CUR_HUNK["lines_$SIDE"]="${CUR_HUNK[lines_$SIDE]%:}"
    CUR_HUNK["lines_$SIDE"]="${CUR_HUNK[lines_$SIDE]%$'\n'}"
    if [ "$DBGLV" -ge 2 ]; then
      echo "D: old actual/expected lines ($SIDE):"
      nl -ba <<<"${CUR_HUNK[lines_$SIDE]}"
    fi
  done

  local DIFF_REPORT= # pre-declare so "local" doesn't affect return value.
  DIFF_REPORT="$(verify_next_hunk__diff_core)"
  local DIFF_RV=$?
  case "$DIFF_RV:${#DIFF_REPORT}" in
    0:0 ) echo '+OK patch context matches.';;
    1:* )
      echo "W: Patch context differs!" >&2
      (( MISMATCHES += 1 ))
      explain_differing_patch_context || return $?
      ;;
    * )
      echo "E: diff failed! diff rv=$DIFF_RV" >&2
      return 7;;
  esac
}


function explain_differing_patch_context () {
  <<<"$DIFF_REPORT" sed -rf <(echo '
    3{/^@@ /d}
    3,$s~$~¶~
    s!^\-!\x1b[31m&!
    s!^\+!\x1b[32m&!
    /^\x1b\[/s~$~\x1b[m~
    3,$s~^~¦~
    s~^~  ~
    ')
  local ADDS_DELS="$(<<<"$DIFF_REPORT" cut -b 1)"
  [[ "$ADDS_DELS" == $'-\n+\n@\n'* ]] || return 4$(
    echo "E: $FUNCNAME: Unexpected diff format for ADDS_DELS" >&2)
  ADDS_DELS="${ADDS_DELS//$'\n'/}"
  ADDS_DELS="${ADDS_DELS#-+@}"

  local HEAD_ADDS="${ADDS_DELS%%[^+]*}"
  [ -z "$HEAD_ADDS" ] || echo "H: If this hunk is misaligned," \
    "you may need to decrease the offset line numbers by ${#HEAD_ADDS}." \
    "-> $(calc_modified_atat %-${#HEAD_ADDS} %)"
  local HEAD_DELS="${ADDS_DELS%%[^-]*}"
  [ -z "$HEAD_DELS" ] || echo "H: If this hunk is misaligned," \
    "you may need to increase the offset line numbers by ${#HEAD_DELS}." \
    "-> $(calc_modified_atat %+${#HEAD_DELS} %)"
}


function calc_modified_atat () {
  local FORMULAS=( "${1:-%}" "${2:-%}" ); shift 2
  FORMULAS+=( "${1:-${FORMULAS[0]}}" "${2:-${FORMULAS[1]}}" ); shift 2
  local IDX= ORIG= CALC= VAL= RESULTS=
  for IDX in {0..3}; do
    ORIG="${ATAT_NUMS[$IDX]}"
    VAL=
    let VAL="${FORMULAS[$IDX]//%/$ORIG}"
    [ -n "$VAL" ] || return 4$(echo "E: $FUNCNAME:" >&2 \
      "Invalid formula for slot $IDX: '${FORMULAS[$IDX]}'")
    RESULTS+=" $VAL"
  done
  printf -- '@@ -%s,%s +%s,%s @@' $RESULTS
}


function verify_next_hunk__diff_core () {
  local HUNK_LEN="${#CUR_HUNK[diff]}"
  # ^-- Almost >= number of lines in the patch, so using that for the number
  #     of context lines ensures we always see the entire hunk.
  diff -U "$HUNK_LEN" \
    --label "Actual old lines currently in $EFF_ORIG_FILE" <(
      echo "${CUR_HUNK[lines_old]}") \
    --label "Expected old lines as stated in patch file $PATCH_FILE" <(
      echo "${CUR_HUNK[lines_exp]}") \
    ;
}


function count_line_types () {
  local ALL="$( <<<"${CUR_HUNK[diff]}" cut --bytes=1 \
    | sed -re 's~^ ?$~=~' | tr -d '\n' )"
  local LT= BUF=
  for LT in =keep +plus -minus ; do
    BUF="${LT:0:1}"
    BUF="${ALL//[^$BUF]}"
    CUR_HUNK["${LT:1}"]="${#BUF}"
  done
  let CUR_HUNK[n_old]="${CUR_HUNK[keep]} + ${CUR_HUNK[minus]}"
  let CUR_HUNK[n_new]="${CUR_HUNK[keep]} + ${CUR_HUNK[plus]}"
}


function verify_patch_length () {
  local SIDE="$1"; shift
  local ATAT="$1"; shift
  local WANT="${CUR_HUNK[n_$SIDE]}"
  [ "$WANT" == "$ATAT" ] && return 0
  echo "W: Hunk line declares $ATAT $SIDE lines but contains $WANT!" >&2
  (( MISMATCHES += 1 ))
  return 6
}










why_does_patch_not_apply "$@"; exit $?
