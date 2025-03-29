
gitg_hide_branches
==================

While `gitg` provides very useful railroad diagrams for simple repos,
as of version 3.32.1, it lacks an essential feature for more complex repo:
An option to hide branches and tags that you're not interested in.

Running `gitg` in `strace` shows that it uses `getdents` to list directory
entries in `…/.git/refs/…` and `lstat` to read files like
`/.git//refs/remotes/origin/master`.

  * The double slash is a mystery to me: It can't be from the path given as
    CLI argument, because then the extra slash would be _before_ `.git`.
    It also can't be from how the filenames returned from `getdents` are
    appended to the directory path, because then the extra slash would be
    _after_ the path used in `getdents`.



Related gitg issues
-------------------

* [gitg #361: support filtering history for arbitrary selection of references"
  ](https://gitlab.gnome.org/GNOME/gitg/-/issues/361)
  This seems to be the opposite approach (show only selected branches)
  of what I'm trying (hide unwanted branches) but might work as a stopgap.



What I've tried so far
----------------------

* `LD_PRELOAD`:
  I tried to [embrace and extend `lstat`](ldpreload_hide_branches.c),
  but `gitg` seems to not be not be susceptible for `LD_PRELOAD`.







