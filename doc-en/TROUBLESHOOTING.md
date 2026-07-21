# Troubleshooting

## “Component cffi not found”

`sbcl --script` does not load the normal SBCL user init file. If Quicklisp is normally loaded from `.sbclrc`, CFFI may disappear in script mode.

Try:

```bash
QUICKLISP_SETUP="$HOME/quicklisp/setup.lisp" sbcl --script run.lisp
```

Or install a system CFFI package discoverable by ASDF.

## SDL3 not found

Install the SDL3 runtime/development library and ensure the shared library is visible to the dynamic loader. Headless commands such as `analyze.lisp` do not require SDL3.

## Window does not open on a server/container

Use headless analysis, or run smoke tests under a virtual X server such as Xvfb. Malkuth does not require a window for architecture reports.

## Scope finds no packages

The target packages must already be loaded in the same Lisp image. Confirm package names with `(list-all-packages)` and ensure `MALKUTH_SCOPE_PREFIXES` matches the actual package prefixes.

## Report contains too many packages

Set `MALKUTH_SCOPE_PREFIXES` and optionally disable boundary dependencies:

```bash
MALKUTH_SCOPE_PREFIXES='MEU-APP' \
MALKUTH_INCLUDE_DEPENDENCIES=false \
sbcl --script run.lisp
```

## Score seems unfair

Health and risk are heuristics. Use them as review signals, compare against a stable baseline and prefer explicit policies for hard architecture requirements.

## Partial or temporary file remains

Atomic export normally removes temporary files after successful replacement. A crash or external filesystem error can leave a hidden temporary artifact; it can be removed after confirming no export process is active.

## Accented text appears without the accent mark in the interface

The embedded 5x7 font normalizes some accented characters to readable base glyphs. This avoids external font dependencies but is not a full Unicode font renderer.

## Policy file is rejected

Check S-expression syntax, supported rule types, required fields and pattern format. The loader intentionally rejects unsafe or malformed input.

## Filter 7 is empty

No loaded policy violation currently maps to visible packages, or no policy file is active. Open panel `L` and confirm `MALKUTH_POLICY_FILE`.

## No path exists between two packages

The graph only includes `USE-PACKAGE` edges in the current snapshot. Fully qualified symbol references do not create edges. Also confirm that scope filtering has not removed required intermediate packages.

## Monitor does not detect changes in another process

Expected behavior: the monitor observes only its own Lisp image. It is not a remote process inspector.

## Trend contains few points

Confirm `MALKUTH_HISTORY_DIR`, `MALKUTH_SAVE_HISTORY`, retention settings and that history persists between runs if CI workers are ephemeral.
