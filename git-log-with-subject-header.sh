#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-
set -o pipefail -o errexit
git log "$@" | LANG=C sed -re '1!s!^commit !\x00&!' |
  # Replace first blank line (and indentation of the next line)
  # with a header name:
  LANG=C sed -zre 's!\n\n[ \t]+!\nSubject: !' |
  # Now only non-subject lines should be indented.
  # Discard empty lines at the start and end of the message:
  LANG=C sed -zre 's!\n[ \t]*\n!\n!; s![\n \t]*$!\n!' |
  # Discard the commit separators we added earlier:
  tr -d '\0' |
  # Add a line with a single dot at the end of each commit:
  LANG=C sed -re '1!s!^commit !.\n&!; $s!$!\n.!'; exit $?
