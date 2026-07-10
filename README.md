# Kokoro Launcher — Spec

## Overview

Kokoro is a single launcher script for fuzzy-finding and running a
collection of `.sh` scripts and `.md` notes. It's dropped into any
folder containing such content and run from inside that folder.
Running `kokoro` with no arguments launches an interactive fuzzy
picker (via `fzf`); selecting a `.sh` file runs it, selecting a `.md`
file opens it in `vi`.

```
some-folder/
  kokoro      <- the launcher script
  ...         <- .sh scripts and .md notes to search and run
```

Kokoro discovers files relative to the current working directory it's
run from — the user is expected to `cd` into the folder before running
it.

## Dependencies

Resolved from the host's `PATH` at runtime; none are bundled with
kokoro:

- **`fzf`** — the interactive picker.
- **`rg`** (ripgrep) — content and title filtering.
- **`fd`** — file discovery.
- **`awk`** — candidate list formatting.
- **`vi`** — opens `.md` files.
- **`git`** *(optional)* — not required to run kokoro, but recommended
  for tracking changes and rollbacks of the folder's contents. Its
  absence produces a one-time advisory note, never an error.

`fzf`, `rg`, and `fd` are checked explicitly at startup; a missing tool
produces a clear error naming it. `awk` and `vi` are assumed present on
any POSIX-like system and are not explicitly checked.

## Behavior

### Invocation

Kokoro supports two invocation forms:

- **`kokoro`** (no arguments) — interactive mode, the normal entry
  point.
- **`kokoro --list-matches "<query>"`** — generator mode, used
  internally by kokoro itself and by `fzf`'s live-reload binding. Not
  intended for direct use.

### Dependency check

On interactive-mode startup, kokoro confirms `fzf`, `rg`, and `fd` all
resolve on `PATH`. All three are checked independently, and any that
are missing are named together in a single error message before
exiting non-zero. Separately, if `git` is not found, a non-fatal
advisory note is printed to stderr and execution continues normally.
This check does not run in generator mode.

### Generator mode

Given a query string (possibly empty), produces a newline-separated
list of `label<TAB>value` candidate lines on stdout, then exits.

**`.sh` candidates** are matched by filename, never by content:
- All `.sh` files are found recursively via `fd`.
- Each is converted to a `title<TAB>path` line (title = filename minus
  `.sh`) in a single `awk` pass, then sorted by title.
- If a query is given, the title list is filtered for a case-
  insensitive literal substring match via a single `rg` call; only
  lines whose title matched are kept.

**`.md` candidates** are matched by content, not filename, once a
query exists:
- With an empty query, only top-level `.md` files (no subdirectory in
  their path) are listed, sorted by path.
- With a non-empty query, all `.md` files' contents (including
  subdirectories) are searched in a single `rg` call for a case-
  insensitive literal substring match; matching files are listed,
  sorted by path.
- Each surviving `.md` file produces a `path<TAB>path` line (label and
  value are identical — the full path is shown to the user).

Output is the `.sh` candidate lines followed by the `.md` candidate
lines.

### Interactive mode

On startup, after the dependency check, kokoro calls its own generator
mode with an empty query to build the initial candidate list. If no
`.sh` or `.md` files exist anywhere in the current directory tree, an
error is printed and the script exits non-zero.

### Picker loop

A `query` variable, starting empty, is maintained across iterations of
the following loop:

1. Generator mode is called with the current `query` to (re)build the
   candidate list.
2. `fzf` is launched with that list, configured so that:
   - Only the label (first column) is shown in the UI.
   - Selecting a candidate returns only the value (second column).
   - `fzf`'s own fuzzy filtering is disabled — the list is already
     pre-filtered.
   - The search box is pre-filled with the current `query`.
   - Every keystroke re-invokes generator mode with the new query and
     live-reloads the candidate list.
   - The current query text is always printed as `fzf`'s first output
     line, followed by the selected value's line, if any.
   - Ctrl-C exits `fzf` with no output.
3. If `fzf` produced no output at all, kokoro exits 0.
4. Otherwise, `query` is updated to the first output line. If there is
   no second line (no selection was made), kokoro exits 0.
5. Otherwise, the selected value is acted on (see below), and the loop
   repeats with `query` preserved.

### File actions

- A selected path ending in `.sh` is run as `sh path/to/file`,
  inheriting the current terminal's stdin/stdout/stderr, and waited on
  to finish.
- A selected path ending in `.md` is opened with `vi`.
- Any other selected path (not expected to occur, since generator mode
  only ever emits `.sh`/`.md` candidates) produces an "unrecognized
  file type" error to stderr and a non-zero exit.

After an action completes, the picker loop resumes with the preserved
query, continuing indefinitely until the user exits via one of the
picker loop's exit conditions.

## Constraints

- **POSIX `sh` only.** No bashisms — no arrays, no `[[ ]]`, no `local`.
  Runs under `dash` and other minimal POSIX shells.
- **`.gitignore` is respected**, and symlinks are not followed — both
  are `fd`/`rg` defaults, left untouched.
- **`git` is never invoked** for any functional purpose; its presence
  is only ever checked for the advisory note above.
- **`.sh` files are always run via `sh path/to/file.sh`** — never
  sourced, never run via `bash`, never executed via `./file.sh`.
- Self-invocation (kokoro calling itself for generator mode) is always
  done via `sh "$SELF" --list-matches ...`, so it works correctly
  regardless of whether kokoro was launched as `./kokoro` or
  `sh kokoro`.
- Temporary files are written under `$TMPDIR` if it's set, falling
  back to `/tmp` otherwise — never hardcoded to `/tmp` directly. This
  matters on sandboxed environments (e.g. Android/Termux) where `/tmp`
  isn't writable but `$TMPDIR` points somewhere valid.
