# Ubu

Ubu (Unique Build Utility) is a library for building custom build
programs. Ubu is implemented on top of Guile, which enables convenient
and compact build definitions, and easy development.

Ubu is documented in `doc/ubu.adoc`. See the documentation for how to
use Ubu.


# Install

Ubu can be installed with:

    shell> ubu

The man page (generated from `doc/ubu.adoc`) can be build (separately)
with:

    shell> ubu build-doc

Installation depends on Ubu variables: `ubu-path` and
`man-path`. `ubu-path` will be used for ubu-library installation and
`man-path` will be used for manual page installation.

Variable `ubu-path` is by default the first entry of `GUILE_LOAD_PATH`
environment variable. Value of variable `man-path` is by default
`$HOME/usr/man/man3`.

User can change `ubu-path` for example by:

    shell> ubu ubu-path=$HOME/usr/share
