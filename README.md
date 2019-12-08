# Overview

Ubu is a library for building custom build programs. Ubu uses Guile
for implemention, which enables convenient and compact build
definitions.

Ubu features:

* Compact build definitions.

* Command line options processing.

* User help support.

* Aliases for actions.

* Modularity supports team work.

* Serial and parallel builds.

* File and command line based control.

* Unlimited customization through Guile.



# Examples

Ubu build program (simply "Ubu") includes minimal amount of compulsory
items.

```
#!/usr/bin/guile -s
!#

(use-modules (ubu))

(set "message" "Hello Ubu")

(action hello
        (sh "echo" (get "message")))

(ubu-run-cli)
```

Ubu is a Guile program. It loads the `ubu` library/module (using
use-modules). Action `hello` is defined and it performs a Shell
command which displays "Hello Ubu".

The `set` function defines a Ubu Variable called `message` with value
"Hello Ubu". The variable is referenced in the `hello` action. The
`sh` function concatenates its arguments with space separation and
executes a shell command. This is the most common form of executions
in Ubu.

Finally, the Ubu actions are executed by calling the `ubu-run-cli`
function. `ubu-run-cli` parses the command line arguments and executes
the selected actions.

This example Ubu could be executed as:

    shell> ubu hello

i.e. program name `ubu` followed with action `hello`. Command produces
the output:

    * ubu-execute: echo Hello Ubu

Ubu displays the executed actions, but it does not display the output
of the action itself, by default. If we want to see "Hello Ubu", we
have to use higher log verbosity level.

We can do this by setting `:log-level` parameter (Ubu Variable) to 4:

    shell> ubu hello :log-level=4

Normally we don't want to see output from the actions, since typically
we just want to transform files with Ubu.

Ubu includes some built-in actions. We can, for example, list all Ubu
actions:

    shell> ubu ubu-actions

The output of this command is:

```
  ubu-actions
  ubu-variables
  ubu-cli-map
  ubu-hello
  hello
```

Actions that start with `ubu` are Ubu built-ins. The last in the list
above is the defined user action.

For a more complete example, please refer to "example/hello"
directory.


# Concepts

The most important concepts in Ubu are Variables, Actions, and
Helpers.

## Variables, Actions, and Helpers

Variables customize Actions and enable in practice the use of
Helpers. Helpers are useful for building reusable Ubu
programs. Helpers are basically a library of Guile functions which are
parametrized by Actions and also through Variables.

This concept is easiest to describe using a concrete example. Let's
assume that we want to link C-object files in order to create an
executable. We are skipping the complilation for now. The example
lines are from "example/hello/ubu".

First we define the location of source and object files.

```
(set "hello-source-dir" "src")
(set "hello-target-dir" "build")
(set "hello-exe"        "bin/hello")
```

Then we can use Ubu Action API to collect C-files and map them to
corresponsding object-files.

```
(let ((c-files (get-files (glu "/" (get "hello-source-dir") "*.c"))))
  (set "hello-source-files" c-files)
  (set "hello-target-files" (map-files
                             c-files
                             'dir (get "hello-target-dir")
                             'ext ".o")))
```

Here we are using a regular Guile variable to make the definitions
more compact (`c-files`). We can get source directory content with
`get-files` function. When we have the list of C-files, we map them to
corresponding object-files with `map-files`.

We can define the `link` Action using a Helper function,
`gcc-link-files`:

```
(action link
        (gcc-link-files
         (get "hello-target-files")
         (get "hello-exe")))
```

`action` is a Guile macro which takes the Action Name and Action Body
as arguments. The Action is defined as a normal Guile function, but it
is also registered as an Action to Ubu.

The Helper `gcc-link-files` is defines as:

```
(define (gcc-link-files o-files exe-file)
  (when (ubu-update? o-files exe-file)
    (sh "gcc" "-o" exe-file o-files)))
```

`gcc-link-files` takes object-files and the executable name as
arguments. It uses `ubu-update?` function to check, whether the
linking is actually needed or not. If executable is missing or any of
the object-files are newer than the executable, then update is
performed (call to `sh`).

Note that `gcc-link-files` is reusable for different projects, since
it is parametrizable. Note also that is does not need any Ubu Variable
based customizations. However, it could simply refer to Variables with
`get` if needed.


## Command Line Interface

Ubu provides features to build usable user interfaces for Ubu
programs. In general, CLI is used to modify Variable values and to
select Actions.

CLI is declared with the `cli-map` function, for example:

```
(cli-map

 '(opt
   (q :quiet))

 '(par
   (ll :log-level))

 '(act
   (h  help)
   (l  link))
```

The `opt` section declares dash type options (e.g. `-q`), which set
the associated Variable (`:quiet`) to `true`. Variables that start
with colon (`:`) are Ubu System Variables.

The `par` section declares assign style variable assignments
(`ll=4`). Numbers and boolean values are automatically converted to
number and boolean type Guile values. Space separated string values
become string lists, and single strings are passed as is.

The `act` section declares aliases for Actions. These are convenient
for repetitive interactive use.

Example CLI content could be:

    shell> ubu l ll=4

and the more verbose version of the same would be:

    shell> ubu link :log-level=4


## Usage help

Ubu provides a clean and practical user interface. User help can be
defined as, for example:

```
(action-help
 ""
 "  shell> ubu build"
 "")

```

`action-help` is a Guile macro which defines a Guile function `help`
and it also registers the function as an Ubu Action.


## Ubu Libraries

Ubu supports reusable components for creating customized build
tools. For example, a Helper library can be taken into use with:

    (ubu-load "ubu-lib/ubu-utils.scm")

`ubu-load` loads the file into memory. Load is performed as
`primitive-load` and hence the provided functions are not required to
be placed into a module. Alternatively `ubu-module` can be used, if
libraries are maintained as Guile modules.

Libraries can contain Variables and/or Helper functions, or any other
Guile related items.


# Usage and maintanance

Ubu requires different level of skills dependending on the role of
user.

Light Users only use the provided Ubu program. They have to know what
is commonly provided by the Ubu program and what specific Actions and
options are provided.

Normal Users know (in addition to Light Users), how to modify/add
Actions and Variables.

Maintainers master all aspects of Ubu. They should know the Ubu API
and they should also have a working knowledge of Guile.


# System variables

Current list of Ubu System Variables:

* `:quiet`: Disable all output from Ubu.

* `:parallel`: Execute commands in parallel using multiple
  threads. Applies to `sh-set` function, but does not affect `sh-par`
  nor `sh-ser`.

* `:log`: Guile port for logging output.

* `:log-level`: Verbosity level for logging: 0 = quiet, 1 = error, 2 =
  warning, 3 = command (default), 4 = output

* `:abort-on-error`: Abort with error (default: true).


# API

API functions are grouped into groups: Action API, Ubu API, and Utils
API. Functions are listed in alphabetical order.


## Action API

### action

`action` defines an Ubu Action and registers it to Ubu.

Syntax: `(action <name> <expr> ...)`

### action-help

`action-help` defines `help` Action for usage help and registers it to
Ubu.

Syntax: `(action-help <name> <usage-line> ...)`


### add

`add` adds an entry (or list of entries) to a list type Variable.

Syntax: `(add <name> <val-or-vallist>)`


### cat

`cat` concatenates string arguments without spaces.

Syntax: `(cat <str-or-strlist> ...)`


### cli

`cli` pairs options with arguments as string.

Syntax: `(cli <opt> <arglist>)`


### cli-map

`cli-map` defines the Ubu command line interface.

Syntax: `(cli-map <cli-map-def>)`


### cmd

`cmd` executes a shell command and returns shell command output as
string. Command is created by concatenating all argument strings
separated with space. Note, this is similar to `sh`, but not to be
used as an Action step.

Syntax: `(cmd <cmd-pcs> ...)`


### del

`del` delays procedure execution. This is needed for out-of-order
Variable definitions.

Syntax: `(del <proc>)`


### dir

`dir` ensures that directories exist.

Syntax: `(dir <dir> ...)`


### env

`env` returns the named environment variable (i.e. alias to `getenv`).

Syntax: `(env <env-var>)`


### eva

`eva` evaluates code given as quote expression.

Syntax: `(eva <code>)`


### for

`for` iterates over a list of items using given procedure. List item
is stored to `<var>` per iteration.

Syntax: `(for (<var> <list>) <expr> ...)`


### gap

`gap` concatenates string arguments with space.

Syntax: `(gap <str-or-strlist> ...)`


### get

`get` return value of one or more Variables. Multiple values are
returned as a list.

Syntax: `(get <var> ...)`


### get-files

`get-files` return list of files using a globbing pattern.

Syntax: `(get-files <pattern>)`


### glu

`glu` concatenates string arguments with given separator.

Syntax: `(glu <sep> <str-or-strlist> ...)`


### log

`log` outputs log messages using given logging level.

Syntax: `(log <level> <msg> ...)`


### lognl

`lognl` outputs log messages with a newline, and using given logging
level.

Syntax: `(lognl <level> <msg> ...)`


### map-files

`map-files` maps list of files to new directory and
extension. Directory is mapped if `'dir` option is given, and
extension is mapped if `'ext` option is given.

Syntax: `(map-files <file-or-filelist> ['dir <new-dir>] ['ext <new-ext>])`


### pcs

`pcs` splits string into pieces (list) using spaces.

Syntax: `(pcs <str>)`


### ref

`ref` creates a delayed reference to a Variable. This is needed for
out-of-order Variable references.

Syntax: `(ref <name>)`


### set

`set` defines a Variable value or multiple values.

Syntax: `(set <name> <value> [<name> <value> ...])`


### sh

`sh` executes a shell command with logging. Command is created by
concatenating all argument strings separated with space.

Syntax: `(sh <cmd-pcs> ...)`


### sh-par

`sh-par` executes shell commands in parallel.

Syntax: `(sh-par <cmd-str-list>)`


### sh-ser

`sh-ser` executes shell commands in series (sequentially).

Syntax: `(sh-ser <cmd-str-list>)`


### sh-set

`sh-set` execute shell commands based on ":parallel" Variable
value. Execution is parallel if `:parallel` is `true` and serial if
`false`.

Syntax: `(sh-set <cmd-str-list>)`


### times

`times` executes body the given number of times. Index value is stored
to `<var>` and can be used within the body.

Syntax: `(times (<var> <limit>) <expr> ...)`


### ubu-update?

`ubu-update?` checks if target files need to be renewed or generated
again based on the file modification values. Return value is `true` if
update is needed and `false` if update is not needed.

If target file does not exist or is older than source, `true` is
returned. Sources and targets are compared in pairs, if both have the
same number of entries. Otherwise, if any of the sources is newer than
target, `true` is returned.

Syntax: `(ubu-update? <source-or-list> <target-or-list>)`


## Ubu API

### ubu-act

`ubu-act-list` returns Ubu Actions as a list.

Syntax: `(ubu-act-list)`


### ubu-actions

`ubu-actions` displays Ubu Actions.

Syntax: `(ubu-actions)`


### ubu-cli-map

`ubu-cli-map` displays the defined `cli-map`.

Syntax: `(ubu-cli-map)`


### ubu-default

`ubu-default` sets a default Action. Default action is run if none is
given on command line.

Syntax: `(ubu-default <name> ...)`


### ubu-error

`ubu-error` outputs an error message.

Syntax: `(ubu-error <msg> ...)`


### ubu-exit

`ubu-exit` exits Ubu with given exit status code (0 for success).

Syntax: `(ubu-exit <status>)`


### ubu-fatal

`ubu-fatal` outputs a message for fatal error and exists Ubu with
failure status.

Syntax: `(ubu-fatal <msg> ...)`


### ubu-hello

`ubu-hello` prints "hello". This is usable for sanity checking.

Syntax: `(ubu-hello)`


### ubu-info

`ubu-info` displays message lines.

Syntax: `(ubu-info <msg-line> ...)`


### ubu-load

`ubu-load` loads Ubu libraries as files from directory or directory
path list.

Syntax: `(ubu-load <file-or-path> [file-if-path])`


### ubu-module

`ubu-module` takes a module in to use from given path.

Syntax: `(ubu-module <modpath> <modname>)`


### ubu-post-run

`ubu-post-run` adds a post Action. Post Actions are run after selected
Actions.

Syntax: `(ubu-post-run <act-or-actlist>)`


### ubu-pre-run

`ubu-pre-run` adds a pre Action. Pre Actions are run before selected
Actions.

Syntax: `(ubu-pre-run <act-or-actlist>)`


### ubu-reg-act

`ubu-reg-act` registers the given Action to Ubu.

Syntax: `(ubu-reg-act <sym-proc-or-str>)`


### ubu-run

`ubu-run` runs given list of Actions.

Syntax: `(ubu-run <list>)`


### ubu-run-cli

`ubu-run-cli` parses the CLI entries and runs selected Actions. It
also applies the used options and parameters.

Syntax: `(ubu-run-cli <name> ...)`


### ubu-var

`ubu-var` is a hash of Ubu Variables.

Syntax: `ubu-var`


### ubu-variables

`ubu-variables` displays Ubu Variables and their values.

Syntax: `(ubu-variables)`


### ubu-version

`ubu-version` is Ubu version as string.

Syntax: `ubu-version`


### ubu-warn

`ubu-warn` outputs a warning message.

Syntax: `(ubu-warn <msg> ...)`


## Utils API

### dbg

`dbg` displays object values as debug messages.

Syntax: `(dbg <msg> ...)`


### empty

`empty` is empty list.

Syntax: `empty`


### empty?

`empty?` returns `true` if list is empty.

Syntax: `(empty? <list>)`


### errprn

`errprn` displays object values as error messages.

Syntax: `(errprn <msg> ...)`


### errprnl

`errprnl` displays object values as error messages with newline.

Syntax: `(errprnl <msg> ...)`


### false

`false` is false value.

Syntax: `false <msg> ...`


### first

`first` returns the first item from the list.

Syntax: `(first <list>)`


### pair

`pair` returns a list of pairs from the given list.

Syntax: `(pair <list>)`


### prn

`prn` displays object values as messages.

Syntax: `(prn <msg> ...)`


### prnl

`prnl` displays object valus as message with newline.

Syntax: `(prnl <msg> ...)`


### regexp-split

`regexp-split` splits a string to a list using the given regexp.

Syntax: `(regexp-split <re> <str>)`


### second

`second` returns the second item from the list.

Syntax: `(second <list>)`


### str

`str` concatenates object value to a string.

Syntax: `(str <msg> ...)`


### third

`third` returns the third item from the list.

Syntax: `(third <list>)`


### true

`true` is true value.

Syntax: `true <msg> ...`
