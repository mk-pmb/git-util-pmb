// -*- coding: utf-8, tab-width: 2 -*-
#define _GNU_SOURCE

#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <time.h>

/*

To apply this easily, use: https://github.com/mk-pmb/ld-preload-autocompile-pmb

Unfortunately, my version of gitg seems to not be susceptible for LD_PRELOAD.
(Maybe it's statically linked.) As long as the intercept doesn't work,
all of `ldpreload_hide_branches.decide.c` is useless.

#include "ldpreload_hide_branches.decide.c"

*/

void find_orig_func(void* *ofptr, const char *ofname) {
  if (*ofptr) { return; }
  *ofptr = dlsym(RTLD_NEXT, ofname);
  if (*ofptr) { return; }
  fprintf(stderr, "Error: dlsym(RTLD_NEXT, %s): %s\n", ofname, dlerror());
  exit(60);
}


int lstat (const char *__restrict __file, struct stat *__restrict __buf) {
  static int (*impl)(const char *, const struct stat *) = NULL;
  find_orig_func((void**)&impl, "lstat");
  fprintf(stderr, "Intercepting lstat(%s)\n", __file);
  // if (decide_hide_git_file(__file)) { return impl("/dev/null", __buf); }
  return impl(__file, __buf);
}

/*

If it would work, it could be added to ghit.sh like this:

function ghit () {
  # …
  local SELFPATH="$(readlink -m -- "$BASH_SOURCE"/..)"
  # …
  ghit__opportunistically_install_branch_censorship || return $?
  # …
}

function ghit__opportunistically_install_branch_censorship () {
  local LDP='ld-preload-autocompile-pmb'
  which "$LDP" |& grep -qe '^/' || return 0
  GG_CMD=(
    "$LDP"
    "$SELFPATH"/gitg-censor-branches.c
    "${GG_CMD[@]}"
    )
}


















*/
