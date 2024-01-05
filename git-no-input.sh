#!/bin/sh
DISPLAY= </dev/null setsid git "$@"; exit $?
# ^-- DISPLAY= to prevent ssh-askpass,
#     /dev/null to prevent waiting for password on standard input,
#     setsid to prevent waiting for password on direct TTY input
