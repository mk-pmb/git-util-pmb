#!/bin/sed -urf
# -*- coding: UTF-8, tab-width: 2 -*-

s~\r$~~

1{/^From /{N;s~\n\s*~\t~}}
/^Already up-to-date\./s~^~\f<green>~

/^I: (clean|add)ing /s~^~\f<d-gray>~

/^Updating [0-9a-f]+\.\.[0-9a-f]+$/{
  N
  /\nFast-forward/s~^~\f<green>~
}

/^Please make sure you have .*access/{
  /repository exists/!N
  d
}

/^Please,? commit your changes or stash them before you can merge/{
  N
  s~^[^\n]+\n~~
  /^Aborting\.?$/d
}

/^fatal: .* does not appear to be a git repository/{N;s~^~\f<warn>~}
/^ssh: connect /s~^~\f<error>~
/^fatal: /s~^~\f<error>~

/^(failure|error)s?: /s~^~\f<error>~
/^(untracked|skipped): /s~^~\f<warn>~

/( \| +[0-9]+ )(\++)(\-*)$/{
  s~( \| +[0-9]+ )(\++)([^\+]*)$~\1\f<ins>\2\f>\3~
  s~( \| +[0-9]+ )([^\-]*)(\-+)$~\1\2\f<del>\3\f>~
}

s~^([A-Za-z]+: )([^\n]+)\n\1~\1\2, ~g
s~\n~, ~g
# s~^(\x1b\[[0-9;]+m)([^\n]*\n)([^\x1b])~\1\2\1\3~
/^\x1b\[/s~$|\n~\f>&~g






/^\f/{/\f>/!s~$~\f>~} # reset color at end of line if no reset included

s~\f<warn>|$      ~\f<brown>~g
s~\f<del>|$       ~\f<b-red>~g
s~\f<ins>|$       ~\f<turq>~g
s~\f<error>|$     ~\f<b-red>~g

s~\f<black>|$     ~\x1b[30m~g
s~\f<b-red>|$     ~\x1b[91m~g
s~\f<brown>|$     ~\x1b[33m~g
s~\f<cyan>|$      ~\x1b[96m~g
s~\f<d-gray>|$    ~\x1b[90m~g
s~\f<d-red>|$     ~\x1b[31m~g
s~\f<green>|$     ~\x1b[32m~g
s~\f<l-gray>|$    ~\x1b[37m~g
s~\f<lime>|$      ~\x1b[92m~g
s~\f<turq>|$      ~\x1b[36m~g
s~\f<white>|$     ~\x1b[97m~g

s~\f>|$           ~\x1b[0m~g
s~\f~\x1b[7m‹ff›\x1b[0m~g









# scroll
