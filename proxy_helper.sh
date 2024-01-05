#!/bin/bash
if [ "$https_proxy" == "DEBUG" ]; then
  echo "proxy args: $*" >&2
  echo "proxy request:" >&2
  tr '\r\0' '\n\n' | nl >&2
else
  https_proxy="$(<<<"$https_proxy" cut -d / -f 3 )"
  echo "$0:" trying to HTTP '"CONNECT"' to "$*" through "$https_proxy:" >&2
  nc -X connect -x "$https_proxy" "$@"
fi
